#!/usr/bin/env python3
"""
probe_ddg_adv.py — semantic DDG analyser for ICSPrism fuzz guidance

Usage:
    python3 tools/probe_ddg_adv.py <target>_ddg.json <target>_layout.json [--json out.json]

What it does (beyond probe_ddg.py):
  1. Finds prism_bug_abort_if targets via control-flow guard tracing,
     not just dynamic-GEP sinks (constant-arg aborts have no data-flow preds).
  2. Resolves every ICmp to a source-level field name by tracing SSA backwards
     through ZExt/SExt/Trunc/boolean-cast chains to named struct GEPs.
     Also handles array-element GEPs (resolves to "Buffer" from "%tmpVar57").
  3. Reconstructs the multi-cycle accumulation chain:
       Pressure > 70 -> PressureScore++ -> Buffer[0]++ -> Buffer[1]++ -> ABORT
  4. Classifies each input field role based on what KIND of store its guard
     controls: increment store -> driver/activator; reset store -> inhibitor.
  5. Emits byte weights and a machine-readable JSON for the Rust fuzzer.
"""

import json, re, sys, argparse
from collections import defaultdict, deque
from pathlib import Path
import networkx as nx


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

def load(ddg_path: str, layout_path: str):
    with open(ddg_path) as f:
        ddg = json.load(f)
    with open(layout_path) as f:
        layout = json.load(f)
    return ddg, layout


# ---------------------------------------------------------------------------
# Graph construction
# ---------------------------------------------------------------------------

def build_graph(ddg: dict) -> nx.DiGraph:
    G = nx.DiGraph()
    for n in ddg["nodes"]:
        G.add_node(n["id"], **n)
    for e in ddg["edges"]:
        G.add_edge(e["from"], e["to"], kind=e.get("kind", ""), symbol=e.get("symbol", ""))
    return G


# ---------------------------------------------------------------------------
# Field name resolution
# ---------------------------------------------------------------------------

_SKIP_GEP_NAMES = {"this", "self", "deref"}

def _named_field_from_gep(node: dict) -> str | None:
    """
    Return the source-level field name if this node is a named struct GEP,
    e.g.  %Pressure = getelementptr nuw %PumpController, ptr %0, i32 0, i32 4
    Returns None for tmpVar-named or compiler-internal GEPs.
    """
    if node.get("opcode") != "GetElementPtr":
        return None
    defines = node.get("defines", "")
    if not defines:
        return None
    name = defines.lstrip("%")
    if not name:
        return None
    if name[0].isdigit() or name.startswith("tmpVar") or name.startswith("__"):
        return None
    if name in _SKIP_GEP_NAMES:
        return None
    return name


def resolve_to_field(start_id: int, G: nx.DiGraph) -> str | None:
    """
    Walk backwards from start_id through the graph.
    When we reach a Load, examine its pointer source:
      - Direct named struct GEP  -> return field name
      - Array-element GEP (tmpVar name) -> check ITS base pointer for a named GEP
        and return that array field name (e.g. "Buffer")
    Returns None if no named field is reachable.
    """
    visited: set[int] = set()
    queue = deque([start_id])
    while queue:
        nid = queue.popleft()
        if nid in visited:
            continue
        visited.add(nid)
        node = G.nodes[nid]

        if node.get("opcode") == "Load":
            for pred_id in G.predecessors(nid):
                pn = G.nodes[pred_id]
                # Case 1: direct named struct GEP
                fname = _named_field_from_gep(pn)
                if fname:
                    return fname
                # Case 2: array-element GEP with tmpVar name
                # e.g. %tmpVar57 = getelementptr [8 x i16], ptr %Buffer, i32 0, i32 0
                if pn.get("opcode") == "GetElementPtr":
                    for bpid in G.predecessors(pred_id):
                        bfname = _named_field_from_gep(G.nodes[bpid])
                        if bfname:
                            return bfname

        for pred_id in G.predecessors(nid):
            if pred_id not in visited:
                queue.append(pred_id)
    return None


# ---------------------------------------------------------------------------
# ICmp parsing and resolution
# ---------------------------------------------------------------------------

_ICMP_RE = re.compile(
    r"icmp\s+(s?(?:gt|ge|lt|le)|ne|eq)\s+\w+\s+(%-?[\w.]+|-?\d+),\s*(%-?[\w.]+|-?\d+)"
)

def parse_icmp(ir: str):
    """Return (pred, lhs_str, rhs_str) from an ICmp IR string, or None."""
    m = _ICMP_RE.search(ir)
    if not m:
        return None
    return m.group(1), m.group(2), m.group(3)


def unwrap_icmp(icmp_id: int, G: nx.DiGraph) -> int:
    """
    RuSTy emits boolean casts:  %X = zext i1 %root to i8; icmp ne i8 %X, 0
    Walk through such patterns to return the root ICmp node id.
    """
    node = G.nodes[icmp_id]
    parsed = parse_icmp(node.get("ir", ""))
    if not parsed:
        return icmp_id
    pred, lhs, rhs = parsed

    # Pattern: icmp ne TYPE %X, 0  (or eq TYPE %X, 0)
    if pred not in ("ne", "eq") or rhs != "0":
        return icmp_id

    # Find the predecessor that defines lhs
    for pred_id in G.predecessors(icmp_id):
        pn = G.nodes[pred_id]
        if pn.get("defines", "").lstrip("%") == lhs.lstrip("%"):
            # If it's a ZExt/SExt, look for an ICmp predecessor
            if pn.get("opcode") in ("ZExt", "SExt"):
                for pp_id in G.predecessors(pred_id):
                    if G.nodes[pp_id].get("opcode") == "ICmp":
                        return pp_id
    return icmp_id


def resolve_icmp(icmp_id: int, G: nx.DiGraph) -> tuple | None:
    """
    Unwrap boolean-cast patterns then resolve the comparison operand to a
    source-level field name.  Returns (field_name, pred, threshold) or None.
    """
    root_id = unwrap_icmp(icmp_id, G)
    node = G.nodes[root_id]
    parsed = parse_icmp(node.get("ir", ""))
    if not parsed:
        return None
    pred, lhs, rhs = parsed

    field = None
    threshold = None

    if re.match(r"^-?\d+$", rhs):
        threshold = int(rhs)
        # lhs is the variable side — find its defining predecessor node
        for pred_id in G.predecessors(root_id):
            pn = G.nodes[pred_id]
            defines = pn.get("defines", "").lstrip("%")
            lhs_stripped = lhs.lstrip("%")
            if defines == lhs_stripped:
                field = resolve_to_field(pred_id, G)
                if field:
                    break
        if not field:
            # fallback: try all preds
            for pred_id in G.predecessors(root_id):
                field = resolve_to_field(pred_id, G)
                if field:
                    break
    elif re.match(r"^-?\d+$", lhs):
        threshold = int(lhs)
        for pred_id in G.predecessors(root_id):
            field = resolve_to_field(pred_id, G)
            if field:
                break

    if field is None or threshold is None:
        return None

    # Skip ne 0 / ne 1 comparisons where we couldn't find a real threshold
    # (these are just bool casts that slipped through unwrapping)
    if pred in ("ne", "eq") and threshold in (0, 1) and root_id == icmp_id:
        # Only keep if the field is the direct operand (not unwrapped)
        pass  # still useful as bool field marker

    return field, pred, threshold


def extract_all_icmps(G: nx.DiGraph, func: str) -> list:
    """
    Return [(node_id, field, pred, threshold)] for all resolved ICmps in func.
    Removes redundant 'ne 0' / 'eq 0' entries for fields that already have
    an explicit range comparison (sgt/sge/slt/sle), since those are just
    intermediate boolean-cast artefacts from compound conditions.
    """
    seen: set[tuple] = set()
    raw = []
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "ICmp" or data.get("function") != func:
            continue
        r = resolve_icmp(nid, G)
        if r and r not in seen:
            seen.add(r)
            raw.append((nid, *r))

    # Find fields that have at least one real range comparison
    has_range: set[str] = {
        f for _, f, p, _ in raw if p in ("sgt", "sge", "slt", "sle")
    }

    # Drop ne/eq 0|1 entries for those fields (artefacts of compound conditions)
    results = []
    for entry in raw:
        _, field, pred, thresh = entry
        if pred in ("ne", "eq") and thresh in (0, 1) and field in has_range:
            continue
        results.append(entry)

    return results


# ---------------------------------------------------------------------------
# Target discovery
# ---------------------------------------------------------------------------

def find_abort_targets(G: nx.DiGraph) -> list:
    """
    Find prism_bug_abort_if Call nodes.  Since args are constants there are
    no data-flow edges into the Call, so we trace control-flow:
      Br -> ICmp (unwrapped) -> field comparison
    """
    targets = []
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Call":
            continue
        callee = data.get("callee") or ""
        if "abort" not in callee.lower():
            continue

        abort_bb = data.get("basic_block", "")

        # Find the Br that conditionally jumps to abort_bb
        for br_id, br_data in G.nodes(data=True):
            if br_data.get("opcode") != "Br":
                continue
            if abort_bb not in br_data.get("ir", ""):
                continue
            for guard_id in G.predecessors(br_id):
                if G.nodes[guard_id].get("opcode") != "ICmp":
                    continue
                root_guard_id = unwrap_icmp(guard_id, G)
                resolved = resolve_icmp(root_guard_id, G)
                targets.append({
                    "type": "prism_bug_abort_if",
                    "call_id": nid,
                    "callee": callee,
                    "abort_bb": abort_bb,
                    "guard_icmp_id": root_guard_id,
                    "guard_ir": G.nodes[root_guard_id].get("ir", "").strip(),
                    "resolved": resolved,
                })
    return targets


def find_dynamic_gep_sinks(G: nx.DiGraph) -> list:
    return [nid for nid, data in G.nodes(data=True) if data.get("has_dynamic_index")]


# ---------------------------------------------------------------------------
# Store-guard analysis: what conditions guard each state modification?
# ---------------------------------------------------------------------------

def is_reset_store(store_ir: str) -> bool:
    """True if this store writes a literal constant (reset/init), not a computed value."""
    return bool(re.search(r"store\s+\w+\s+-?\d+,", store_ir))


_NOISE_GUARD_FIELDS  = {"i"}            # loop counter — not a meaningful guard
_NOISE_STORED_FIELDS = {"Status", "i"}  # output copy and loop counter

def _resolve_stored_field(nid: int, G: nx.DiGraph) -> str | None:
    """
    Find the source-level field name for a Store's pointer operand.
    Handles both direct named-struct GEPs and array-element GEPs where the
    base pointer is a named struct GEP:
      store -> GEP(%Buffer elem) -> GEP(%Buffer)  =>  "Buffer"
    """
    for pred_id in G.predecessors(nid):
        pn = G.nodes[pred_id]
        # Direct named struct GEP
        fname = _named_field_from_gep(pn)
        if fname:
            return fname
        # Array-element GEP with tmpVar name: look at its base pointer
        if pn.get("opcode") == "GetElementPtr":
            for bp_id in G.predecessors(pred_id):
                bfname = _named_field_from_gep(G.nodes[bp_id])
                if bfname:
                    return bfname
    return None


def _resolve_br_guard(br_id: int, G: nx.DiGraph) -> tuple | None:
    """
    Find the first resolvable range ICmp that guards a Br node.

    Handles both simple guards (Br ← ICmp) and compound AND guards compiled as:
      Br ← ICmp(ne,0) ← ZExt ← And ← [ZExt ← ICmp(sgt), ZExt ← ICmp(slt)]

    When a ne/eq wrapper is encountered, we look deeper to find the underlying
    range comparison (sgt/sge/slt/sle), which is the meaningful guard for
    accumulation chain analysis.  Returns the first such range guard found.
    """
    def _walk(nid: int, depth: int) -> tuple | None:
        if depth > 5:
            return None
        node = G.nodes[nid]
        op = node.get("opcode", "")

        if op == "ICmp":
            resolved = resolve_icmp(nid, G)
            if not resolved:
                # ICmp unresolvable at this level — walk into predecessors.
                for pred in G.predecessors(nid):
                    r = _walk(pred, depth + 1)
                    if r:
                        return r
                return None
            gfield, gpred, gthresh = resolved
            if gfield in _NOISE_GUARD_FIELDS:
                return None
            # If this is a boolean-cast ne/eq 0 wrapper (artefact of compound AND),
            # try to find a real range comparison deeper in the graph.
            if gpred in ("ne", "eq") and gthresh in (0, 1):
                for pred in G.predecessors(nid):
                    r = _walk(pred, depth + 1)
                    if r and r[1] not in ("ne", "eq"):
                        return r  # prefer a real range guard over the wrapper
                # No range guard found deeper; return wrapper as fallback.
                return resolved
            return resolved

        if op in ("And", "Or", "ZExt", "SExt", "Trunc"):
            for pred in G.predecessors(nid):
                r = _walk(pred, depth + 1)
                if r:
                    return r
        return None

    for cond_id in G.predecessors(br_id):
        result = _walk(cond_id, 0)
        if result:
            return result
    return None


def find_store_guards(G: nx.DiGraph, func: str,
                      abort_bbs: set[str] | None = None) -> list:
    """
    For each Store in the function, find the guarding ICmp by looking for
    a Br whose IR mentions the store's basic block.

    Returns list of dicts with keys:
      stored_field, store_ir, guard (field,pred,thresh) or None,
      is_reset, store_bb
    """
    results = []
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Store" or data.get("function") != func:
            continue

        store_ir = data.get("ir", "").strip()
        store_bb = data.get("basic_block", "")

        # Skip stores inside the abort block itself (the OOB write, not state logic)
        if abort_bbs and store_bb in abort_bbs:
            continue

        stored_field = _resolve_stored_field(nid, G)
        if not stored_field or stored_field in _NOISE_STORED_FIELDS:
            continue

        # Find the guarding Br that leads to this store's basic block
        guard = None
        for br_id, br_data in G.nodes(data=True):
            if br_data.get("opcode") != "Br" or br_data.get("function") != func:
                continue
            if store_bb not in br_data.get("ir", ""):
                continue
            guard = _resolve_br_guard(br_id, G)
            if guard:
                break

        results.append({
            "store_id":     nid,
            "stored_field": stored_field,
            "store_ir":     store_ir,
            "is_reset":     is_reset_store(store_ir),
            "guard":        guard,
            "store_bb":     store_bb,
        })

    return results


# ---------------------------------------------------------------------------
# Accumulation chain reconstruction
# ---------------------------------------------------------------------------

def build_accumulation_chain(store_guards: list, abort_targets: list) -> list:
    """
    Build an ordered chain from root input condition -> abort.

    Uses store_guard data to find:
      - field_increments: state_var -> [(guard_field, pred, threshold)]
      - field_resets:     state_var -> [(guard_field, pred, threshold)]

    Walks backwards from the abort guard through the increment dependency graph.
    """
    field_increments: dict[str, list] = defaultdict(list)
    field_resets:     dict[str, list] = defaultdict(list)

    for s in store_guards:
        if not s["guard"]:
            continue
        gf, gp, gt = s["guard"]
        # Skip self-referential guards (e.g. RESET Buffer when Buffer > 1 — false positive
        # from stores in the abort block's successor that share the same guarding Br)
        if gf == s["stored_field"]:
            continue
        entry = {"condition_field": gf, "pred": gp, "threshold": gt}
        key   = (gf, gp, gt)
        if s["is_reset"]:
            if not any((e["condition_field"], e["pred"], e["threshold"]) == key
                       for e in field_resets[s["stored_field"]]):
                field_resets[s["stored_field"]].append(entry)
        else:
            if not any((e["condition_field"], e["pred"], e["threshold"]) == key
                       for e in field_increments[s["stored_field"]]):
                field_increments[s["stored_field"]].append(entry)

    chain = []
    for t in abort_targets:
        if not t["resolved"]:
            continue
        abort_field, abort_pred, abort_thresh = t["resolved"]

        visited: set[str] = set()
        current_field = abort_field
        current_pred  = abort_pred
        current_thresh = abort_thresh

        while current_field and current_field not in visited:
            visited.add(current_field)
            guards = field_increments.get(current_field, [])
            resets = field_resets.get(current_field, [])

            chain.append({
                "state_var":        current_field,
                "trigger_pred":     current_pred,
                "trigger_threshold": current_thresh,
                "accumulation_guards": guards,
                "reset_conditions": resets,
            })

            if guards:
                g = guards[0]
                current_field  = g["condition_field"]
                current_pred   = g["pred"]
                current_thresh = g["threshold"]
            else:
                break

    return list(reversed(chain))  # root-input -> abort order


# ---------------------------------------------------------------------------
# Layout and input field processing
# ---------------------------------------------------------------------------

def get_input_fields(layout: list) -> list:
    """
    Use the last layout entry (top-level program) and return non-internal fields.
    Returns list of dicts with name, llvm_type, byte_size, byte_offset (packed).
    """
    prog = layout[-1]
    inputs = []
    packed = 0
    for f in prog["fields"]:
        name     = f.get("name", "")
        ltype    = f.get("llvm_type", "")
        size     = f.get("byte_size", 0)
        if name == "__vtable" or ltype.startswith("%"):
            continue
        inputs.append({
            "name":        name,
            "llvm_type":   ltype,
            "byte_size":   size,
            "byte_offset": packed,
        })
        packed += size
    return inputs


def classify_input(field: dict, all_icmps: list, chain: list,
                   store_guards: list) -> dict:
    """
    Assign model and roles to one input field.

    Roles are derived from what kind of stores the field's guard controls:
      - driver:    guards an INCREMENT store of a state var in the chain
      - inhibitor: guards a RESET store of a state var in the chain
      - activator: guards an increment store of a transition var (Mode, ArmedCycles)
      - fault_gate: guards a transition to a fault/bad state
    """
    name  = field["name"]
    ltype = field["llvm_type"].strip()
    size  = field["byte_size"]

    # All ICmp comparisons involving this field
    comparisons = [(pred, thresh) for _, f, pred, thresh in all_icmps if f == name]

    # Model based on type
    if ltype == "i8" and size == 1:
        model = "bool"
    elif ltype == "i16" and size == 2:
        model = "range_i16"
    elif ltype == "i32" and size == 4:
        model = "range_i32"
    else:
        model = "raw"

    # Build sets of fields for which this field guards increments / resets
    guards_increments_of: set[str] = set()
    guards_resets_of:     set[str] = set()
    for s in store_guards:
        if not s["guard"] or s["guard"][0] != name:
            continue
        if s["is_reset"]:
            guards_resets_of.add(s["stored_field"])
        else:
            guards_increments_of.add(s["stored_field"])

    # Chain state vars (fields that are part of the accumulation path)
    chain_vars = {link["state_var"] for link in chain}

    roles = []

    # Inhibitor: guards a RESET of a chain state var (must be kept LOW/inactive)
    if guards_resets_of & chain_vars:
        roles.append("inhibitor")

    # Driver: guards an INCREMENT of a chain state var
    if guards_increments_of & chain_vars:
        roles.append("driver")

    # Activator: guards an increment of a non-chain state var (Mode transitions etc.)
    if guards_increments_of - chain_vars:
        roles.append("activator")

    # Fault gate: guards a reset/transition that takes us OUT of the accumulation path
    # Heuristic: guards resets of chain vars (but that's already inhibitor)
    # Also: if it can cause Mode -> FAULT (check for Temp > 90 pattern)
    for pred, thresh in comparisons:
        if pred == "sgt" and thresh >= 85:
            if "fault_gate" not in roles:
                roles.append("fault_gate")

    if not roles:
        roles.append("neutral")

    # Critical = directly involved in reaching the bug
    in_chain_guard = any(
        g["condition_field"] == name
        for link in chain
        for g in link.get("accumulation_guards", []) + link.get("reset_conditions", [])
    )
    critical = in_chain_guard or "inhibitor" in roles or "driver" in roles

    # Interesting target values: cluster around each comparison threshold.
    # Also include a few spread-out satisfying values so the mutator has a
    # decent probability of landing in the satisfying range, not just on the
    # boundary.
    targets_set: set[int] = set()
    for pred, thresh in comparisons:
        if pred in ("sgt", "sge"):
            # Boundary values (near the threshold)
            targets_set.update([thresh - 1, thresh, thresh + 1, thresh + 2])
            # A few satisfying interior values away from the boundary
            targets_set.update([thresh + 5, thresh + 10])
        elif pred in ("slt", "sle"):
            # Boundary values
            targets_set.update([thresh - 2, thresh - 1, thresh, thresh + 1])
            # A few satisfying interior values
            if thresh > 10:
                targets_set.update([thresh - 5, thresh - 10])
        elif pred in ("ne", "eq"):
            targets_set.update([0, 1])

    # Window interior: when a field has both a lower-bound (sgt/sge N) and an
    # upper-bound (slt/sle M) forming a satisfying window (N < M), the boundary
    # values alone leave most of the window unsampled.  Add the midpoint and
    # quarter-points so the InputRangeMutator can hit the interior.
    lower_bounds = [(p, t) for p, t in comparisons if p in ("sgt", "sge")]
    upper_bounds = [(p, t) for p, t in comparisons if p in ("slt", "sle")]
    for lp, lt in lower_bounds:
        for up, ut in upper_bounds:
            lo = lt + (1 if lp == "sgt" else 0)  # first satisfying value
            hi = ut - (1 if up == "slt" else 0)  # last satisfying value
            if lo >= hi or hi - lo < 3:
                continue
            mid = (lo + hi) // 2
            targets_set.add(mid)
            if hi - lo >= 6:
                targets_set.add(lo + (hi - lo) // 4)
                targets_set.add(lo + 3 * (hi - lo) // 4)

    # For inhibitors: always include 0 (keep inactive)
    if "inhibitor" in roles:
        targets_set.add(0)

    # Filter to valid i16 range
    targets = sorted(t for t in targets_set if -32768 <= t <= 32767)

    return {
        "name":         name,
        "llvm_type":    ltype,
        "byte_size":    size,
        "byte_offset":  field["byte_offset"],
        "model":        model,
        "roles":        roles,
        "comparisons":  [{"pred": p, "threshold": t} for p, t in comparisons],
        "target_values": targets,
        "critical":     critical,
    }


# ---------------------------------------------------------------------------
# Byte weight computation
# ---------------------------------------------------------------------------

_ROLE_WEIGHT = {
    "inhibitor":  1.0,
    "driver":     0.9,
    "activator":  0.7,
    "fault_gate": 0.5,
    "neutral":    0.1,
}

def compute_weights(classified: list, frame_size: int) -> list:
    weights = [0.05] * frame_size
    for f in classified:
        w = max((_ROLE_WEIGHT.get(r, 0.1) for r in f["roles"]), default=0.1)
        start = f["byte_offset"]
        for b in range(start, min(start + f["byte_size"], frame_size)):
            weights[b] = max(weights[b], w)
    return weights


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def _sec(title: str):
    print(f"\n{'=' * 60}\n{title}\n{'=' * 60}")


def print_report(abort_targets, dynamic_sinks, icmps, chain,
                 classified, weights, store_guards):

    _sec("TARGETS")
    if abort_targets:
        for t in abort_targets:
            print(f"  [abort] {t['callee']}  bb={t['abort_bb']}")
            print(f"          guard (id={t['guard_icmp_id']}): {t['guard_ir']}")
            if t["resolved"]:
                f, p, th = t["resolved"]
                print(f"          resolved: {f} {p} {th}")
            else:
                print("          resolved: (none — field not identifiable)")
    if dynamic_sinks:
        print(f"  [dyn-gep] {len(dynamic_sinks)} dynamic array-index sinks")
    if not abort_targets and not dynamic_sinks:
        print("  WARNING: no targets found")

    _sec("ICmp FIELD COMPARISONS (deduplicated)")
    for nid, field, pred, thresh in sorted(icmps, key=lambda x: x[1]):
        print(f"  id={nid:3d}  {field:20s}  {pred:4s}  {thresh}")

    _sec("STORE-GUARD RELATIONSHIPS")
    for s in store_guards:
        kind = "RESET " if s["is_reset"] else "accum "
        gstr = (f"{s['guard'][0]} {s['guard'][1]} {s['guard'][2]}"
                if s["guard"] else "no guard found")
        print(f"  {kind} {s['stored_field']:20s} | guarded by: {gstr}")

    _sec("ACCUMULATION CHAIN  (root-input -> abort)")
    if not chain:
        print("  (none — abort guard could not be resolved to a field)")
    for i, link in enumerate(chain):
        sv    = link["state_var"]
        p     = link["trigger_pred"]
        th    = link["trigger_threshold"]
        label = "-> ABORT" if i == len(chain) - 1 else ""
        print(f"  [{i}] {sv:20s}  {p} {th}  {label}")
        for g in link["accumulation_guards"]:
            print(f"       accumulates when: {g['condition_field']} {g['pred']} {g['threshold']}")
        for r in link["reset_conditions"]:
            print(f"       RESET when:       {r['condition_field']} {r['pred']} {r['threshold']}"
                  f"  <- must avoid")

    _sec("INPUT FIELD CLASSIFICATION")
    for f in classified:
        roles_str = ", ".join(f["roles"])
        crit = " *** CRITICAL ***" if f["critical"] else ""
        print(f"  {f['name']:15s}  {f['model']:12s}  [{roles_str}]{crit}")
        for c in f["comparisons"]:
            print(f"  {'':15s}  comparison: {f['name']} {c['pred']} {c['threshold']}")
        if f["target_values"]:
            print(f"  {'':15s}  target values: {f['target_values']}")

    _sec("BYTE WEIGHTS  (one frame)")
    for i, w in enumerate(weights):
        fname = next(
            (f["name"] for f in classified
             if f["byte_offset"] <= i < f["byte_offset"] + f["byte_size"]),
            "?"
        )
        bar = "#" * int(w * 30)
        print(f"  byte {i:2d}  [{fname:15s}]  {w:.3f}  {bar}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Semantic DDG analyser for ICSPrism")
    ap.add_argument("ddg",    help="<target>_ddg.json")
    ap.add_argument("layout", help="<target>_layout.json")
    ap.add_argument("--json", metavar="OUT", help="Write machine-readable JSON")
    args = ap.parse_args()

    ddg, layout = load(args.ddg, args.layout)
    G = build_graph(ddg)

    # Pick dominant function (most nodes) as analysis target
    func_counts: dict[str, int] = defaultdict(int)
    for _, data in G.nodes(data=True):
        func_counts[data.get("function", "")] += 1
    main_func = max(func_counts, key=func_counts.__getitem__)
    print(f"[probe_ddg_adv] Analysing function: {main_func}")

    abort_targets  = find_abort_targets(G)
    dynamic_sinks  = find_dynamic_gep_sinks(G)
    icmps          = extract_all_icmps(G, main_func)

    # Fields that have real range comparisons — used to filter ne-0 guard leakage
    range_fields: set[str] = {f for _, f, p, _ in icmps if p in ("sgt","sge","slt","sle")}

    abort_bbs = {t["abort_bb"] for t in abort_targets}
    store_guards   = find_store_guards(G, main_func, abort_bbs=abort_bbs)

    # Remove ne-0 / eq-0 guards for fields that have proper range comparisons
    # (these are artefacts of compound boolean conditions like Temp>50 AND Temp<60)
    for s in store_guards:
        if s["guard"]:
            gf, gp, gt = s["guard"]
            if gp in ("ne", "eq") and gt in (0, 1) and gf in range_fields:
                s["guard"] = None
    chain          = build_accumulation_chain(store_guards, abort_targets)

    raw_inputs     = get_input_fields(layout)
    frame_size     = sum(f["byte_size"] for f in raw_inputs)
    classified     = [classify_input(f, icmps, chain, store_guards) for f in raw_inputs]
    weights        = compute_weights(classified, frame_size)

    print_report(abort_targets, dynamic_sinks, icmps, chain,
                 classified, weights, store_guards)

    if args.json:
        out = {
            "main_function": main_func,
            "frame_size":    frame_size,
            "abort_targets": [
                {
                    "callee":    t["callee"],
                    "guard_ir":  t["guard_ir"],
                    "resolved":  (
                        {"field": t["resolved"][0], "pred": t["resolved"][1],
                         "threshold": t["resolved"][2]}
                        if t["resolved"] else None
                    ),
                }
                for t in abort_targets
            ],
            "accumulation_chain": chain,
            "input_fields":  classified,
            "byte_weights":  weights,
        }
        Path(args.json).write_text(json.dumps(out, indent=2))
        print(f"\n[probe_ddg_adv] Wrote {args.json}")


if __name__ == "__main__":
    main()
