from __future__ import annotations

import json
import re
from collections import defaultdict, deque
from pathlib import Path

import networkx as nx

from .graph import build_graph, named_field_from_gep, find_main_func
from .fields import resolve_to_field, parse_icmp, unwrap_icmp, resolve_icmp
from .io import load_ddg, load_layout


# ---------------------------------------------------------------------------
# Store-field resolution (local)
# ---------------------------------------------------------------------------

def _resolve_stored_field(nid: int, G: nx.DiGraph) -> str | None:
    for pred_id in G.predecessors(nid):
        pn = G.nodes[pred_id]
        fname = named_field_from_gep(pn)
        if fname:
            return fname
        if pn.get("opcode") == "GetElementPtr":
            for bp_id in G.predecessors(pred_id):
                bfname = named_field_from_gep(G.nodes[bp_id])
                if bfname:
                    return bfname
    return None


# ---------------------------------------------------------------------------
# ICmp extraction
# ---------------------------------------------------------------------------

def _extract_all_icmps(G: nx.DiGraph, func: str) -> list:
    """
    Return [(node_id, field, pred, threshold)] for all resolved ICmps in func.
    Removes ne/eq 0 artefacts for fields that already have range comparisons.
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

    has_range: set[str] = {f for _, f, p, _ in raw if p in ("sgt", "sge", "slt", "sle")}
    return [
        entry for entry in raw
        if not (entry[2] in ("ne", "eq") and entry[3] in (0, 1) and entry[1] in has_range)
    ]


# ---------------------------------------------------------------------------
# Target discovery
# ---------------------------------------------------------------------------

def _find_abort_targets(G: nx.DiGraph) -> list:
    targets = []
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Call":
            continue
        callee = data.get("callee") or ""
        if "abort" not in callee.lower():
            continue
        abort_bb = data.get("basic_block", "")
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
                    "type":          "prism_bug_abort_if",
                    "call_id":       nid,
                    "callee":        callee,
                    "abort_bb":      abort_bb,
                    "guard_icmp_id": root_guard_id,
                    "guard_ir":      G.nodes[root_guard_id].get("ir", "").strip(),
                    "resolved":      resolved,
                })
    return targets


def _find_dynamic_gep_sinks(G: nx.DiGraph) -> list:
    return [nid for nid, data in G.nodes(data=True) if data.get("has_dynamic_index")]


# ---------------------------------------------------------------------------
# Store-guard analysis
# ---------------------------------------------------------------------------

_NOISE_GUARD_FIELDS  = {"i"}
_NOISE_STORED_FIELDS = {"Status", "i"}


def _resolve_br_guard(br_id: int, G: nx.DiGraph) -> tuple | None:
    def _walk(nid: int, depth: int) -> tuple | None:
        if depth > 5:
            return None
        node = G.nodes[nid]
        op   = node.get("opcode", "")
        if op == "ICmp":
            resolved = resolve_icmp(nid, G)
            if not resolved:
                for pred in G.predecessors(nid):
                    r = _walk(pred, depth + 1)
                    if r:
                        return r
                return None
            gfield, gpred, gthresh = resolved
            if gfield in _NOISE_GUARD_FIELDS:
                return None
            if gpred in ("ne", "eq") and gthresh in (0, 1):
                for pred in G.predecessors(nid):
                    r = _walk(pred, depth + 1)
                    if r and r[1] not in ("ne", "eq"):
                        return r
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


def _find_store_guards(G: nx.DiGraph, func: str, abort_bbs: set[str] | None = None) -> list:
    results = []
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Store" or data.get("function") != func:
            continue
        store_ir = data.get("ir", "").strip()
        store_bb = data.get("basic_block", "")
        if abort_bbs and store_bb in abort_bbs:
            continue
        stored_field = _resolve_stored_field(nid, G)
        if not stored_field or stored_field in _NOISE_STORED_FIELDS:
            continue
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
            "is_reset":     bool(re.search(r"store\s+\w+\s+-?\d+,", store_ir)),
            "guard":        guard,
            "store_bb":     store_bb,
        })
    return results


# ---------------------------------------------------------------------------
# Accumulation chain reconstruction
# ---------------------------------------------------------------------------

def _build_accumulation_chain(store_guards: list, abort_targets: list) -> list:
    field_increments: dict[str, list] = defaultdict(list)
    field_resets:     dict[str, list] = defaultdict(list)

    for s in store_guards:
        if not s["guard"]:
            continue
        gf, gp, gt = s["guard"]
        if gf == s["stored_field"]:
            continue
        entry = {"condition_field": gf, "pred": gp, "threshold": gt}
        key   = (gf, gp, gt)
        target_dict = field_resets if s["is_reset"] else field_increments
        if not any((e["condition_field"], e["pred"], e["threshold"]) == key
                   for e in target_dict[s["stored_field"]]):
            target_dict[s["stored_field"]].append(entry)

    chain = []
    for t in abort_targets:
        if not t["resolved"]:
            continue
        abort_field, abort_pred, abort_thresh = t["resolved"]
        visited: set[str] = set()
        current_field  = abort_field
        current_pred   = abort_pred
        current_thresh = abort_thresh

        while current_field and current_field not in visited:
            visited.add(current_field)
            guards = field_increments.get(current_field, [])
            resets = field_resets.get(current_field, [])
            chain.append({
                "state_var":           current_field,
                "trigger_pred":        current_pred,
                "trigger_threshold":   current_thresh,
                "accumulation_guards": guards,
                "reset_conditions":    resets,
            })
            if guards:
                g = guards[0]
                current_field  = g["condition_field"]
                current_pred   = g["pred"]
                current_thresh = g["threshold"]
            else:
                break

    return list(reversed(chain))


# ---------------------------------------------------------------------------
# Input field classification
# ---------------------------------------------------------------------------

def _get_input_fields(layout: list) -> list:
    prog   = layout[-1]
    inputs = []
    packed = 0
    for f in prog["fields"]:
        name  = f.get("name", "")
        ltype = f.get("llvm_type", "")
        size  = f.get("byte_size", 0)
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


def _classify_input(field: dict, all_icmps: list, chain: list, store_guards: list) -> dict:
    name  = field["name"]
    ltype = field["llvm_type"].strip()
    size  = field["byte_size"]

    comparisons = [(pred, thresh) for _, f, pred, thresh in all_icmps if f == name]

    if ltype == "i8"  and size == 1: model = "bool"
    elif ltype == "i16" and size == 2: model = "range_i16"
    elif ltype == "i32" and size == 4: model = "range_i32"
    else: model = "raw"

    guards_increments_of: set[str] = set()
    guards_resets_of:     set[str] = set()
    for s in store_guards:
        if not s["guard"] or s["guard"][0] != name:
            continue
        if s["is_reset"]:
            guards_resets_of.add(s["stored_field"])
        else:
            guards_increments_of.add(s["stored_field"])

    chain_vars = {link["state_var"] for link in chain}
    roles = []
    if guards_resets_of & chain_vars:
        roles.append("inhibitor")
    if guards_increments_of & chain_vars:
        roles.append("driver")
    if guards_increments_of - chain_vars:
        roles.append("activator")
    for pred, thresh in comparisons:
        if pred == "sgt" and thresh >= 85 and "fault_gate" not in roles:
            roles.append("fault_gate")
    if not roles:
        roles.append("neutral")

    in_chain_guard = any(
        g["condition_field"] == name
        for link in chain
        for g in link.get("accumulation_guards", []) + link.get("reset_conditions", [])
    )
    critical = in_chain_guard or "inhibitor" in roles or "driver" in roles

    targets_set: set[int] = set()
    for pred, thresh in comparisons:
        if pred in ("sgt", "sge"):
            targets_set.update([thresh - 1, thresh, thresh + 1, thresh + 2, thresh + 5, thresh + 10])
        elif pred in ("slt", "sle"):
            targets_set.update([thresh - 2, thresh - 1, thresh, thresh + 1])
            if thresh > 10:
                targets_set.update([thresh - 5, thresh - 10])
        elif pred in ("ne", "eq"):
            targets_set.update([0, 1])

    lower_bounds = [(p, t) for p, t in comparisons if p in ("sgt", "sge")]
    upper_bounds = [(p, t) for p, t in comparisons if p in ("slt", "sle")]
    for lp, lt in lower_bounds:
        for up, ut in upper_bounds:
            lo = lt + (1 if lp == "sgt" else 0)
            hi = ut - (1 if up == "slt" else 0)
            if lo >= hi or hi - lo < 3:
                continue
            mid = (lo + hi) // 2
            targets_set.add(mid)
            if hi - lo >= 6:
                targets_set.add(lo + (hi - lo) // 4)
                targets_set.add(lo + 3 * (hi - lo) // 4)

    if "inhibitor" in roles:
        targets_set.add(0)

    targets = sorted(t for t in targets_set if -32768 <= t <= 32767)

    return {
        "name":          name,
        "llvm_type":     ltype,
        "byte_size":     size,
        "byte_offset":   field["byte_offset"],
        "model":         model,
        "roles":         roles,
        "comparisons":   [{"pred": p, "threshold": t} for p, t in comparisons],
        "target_values": targets,
        "critical":      critical,
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


def _compute_weights(classified: list, frame_size: int) -> list:
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

def _sec(title: str) -> None:
    print(f"\n{'=' * 60}\n{title}\n{'=' * 60}")


def _print_report(abort_targets, dynamic_sinks, icmps, chain,
                  classified, weights, store_guards) -> None:
    _sec("TARGETS")
    for t in abort_targets:
        print(f"  [abort] {t['callee']}  bb={t['abort_bb']}")
        print(f"          guard (id={t['guard_icmp_id']}): {t['guard_ir']}")
        if t["resolved"]:
            f, p, th = t["resolved"]
            print(f"          resolved: {f} {p} {th}")
        else:
            print("          resolved: (none)")
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
        label = "-> ABORT" if i == len(chain) - 1 else ""
        print(f"  [{i}] {link['state_var']:20s}  {link['trigger_pred']} {link['trigger_threshold']}  {label}")
        for g in link["accumulation_guards"]:
            print(f"       accumulates when: {g['condition_field']} {g['pred']} {g['threshold']}")
        for r in link["reset_conditions"]:
            print(f"       RESET when:       {r['condition_field']} {r['pred']} {r['threshold']}  <- must avoid")

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
# Entry point
# ---------------------------------------------------------------------------

def add_args(sub) -> None:
    sub.add_argument("ddg",    help="<target>_ddg.json")
    sub.add_argument("layout", help="<target>_layout.json")
    sub.add_argument("--json", metavar="OUT", help="Write machine-readable JSON")


def run(args) -> None:
    ddg    = load_ddg(args.ddg)
    layout = load_layout(args.layout)
    G      = build_graph(ddg)

    main_func = find_main_func(G)
    print(f"[probe-adv] Analysing function: {main_func}")

    abort_targets = _find_abort_targets(G)
    dynamic_sinks = _find_dynamic_gep_sinks(G)
    icmps         = _extract_all_icmps(G, main_func)

    range_fields: set[str] = {f for _, f, p, _ in icmps if p in ("sgt", "sge", "slt", "sle")}
    abort_bbs     = {t["abort_bb"] for t in abort_targets}
    store_guards  = _find_store_guards(G, main_func, abort_bbs=abort_bbs)

    for s in store_guards:
        if s["guard"]:
            gf, gp, gt = s["guard"]
            if gp in ("ne", "eq") and gt in (0, 1) and gf in range_fields:
                s["guard"] = None

    chain      = _build_accumulation_chain(store_guards, abort_targets)
    raw_inputs = _get_input_fields(layout)
    frame_size = sum(f["byte_size"] for f in raw_inputs)
    classified = [_classify_input(f, icmps, chain, store_guards) for f in raw_inputs]
    weights    = _compute_weights(classified, frame_size)

    _print_report(abort_targets, dynamic_sinks, icmps, chain, classified, weights, store_guards)

    if args.json:
        out = {
            "main_function": main_func,
            "frame_size":    frame_size,
            "abort_targets": [
                {
                    "callee":   t["callee"],
                    "guard_ir": t["guard_ir"],
                    "resolved": (
                        {"field": t["resolved"][0], "pred": t["resolved"][1],
                         "threshold": t["resolved"][2]}
                        if t["resolved"] else None
                    ),
                }
                for t in abort_targets
            ],
            "accumulation_chain": chain,
            "input_fields":       classified,
            "byte_weights":       weights,
        }
        Path(args.json).write_text(json.dumps(out, indent=2))
        print(f"\n[probe-adv] Wrote {args.json}")
