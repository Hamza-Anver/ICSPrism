from __future__ import annotations

import re
import sys
from collections import deque
from pathlib import Path

from .io import load_json, load_layout, load_weights
from .fields import find_field_offset, resolve_icmp


def _derive_range(comparisons: list[dict]) -> tuple[int | None, int | None]:
    """Extract tightest (lo, hi) from a field's comparison list.

    When a field has both upper-bound (slt/sle) and lower-bound (sgt/sge)
    comparisons, any lower-bound whose value >= the minimum upper-bound is a
    fault-gate or OOB condition rather than a driver window — drop it so the
    range reflects the beneficial accumulation window, not the fault trigger.
    """
    lo_candidates: list[int] = []
    hi_candidates: list[int] = []
    for cmp in comparisons:
        pred = cmp.get("pred", "")
        thr  = cmp.get("threshold", 0)
        if pred in ("sge", "uge"):
            lo_candidates.append(thr)
        elif pred in ("sgt", "ugt"):
            lo_candidates.append(thr + 1)
        elif pred in ("sle", "ule"):
            hi_candidates.append(thr)
        elif pred in ("slt", "ult"):
            hi_candidates.append(thr - 1)
    if lo_candidates and hi_candidates:
        min_hi = min(hi_candidates)
        lo_candidates = [l for l in lo_candidates if l < min_hi]
    lo = max(lo_candidates) if lo_candidates else None
    hi = min(hi_candidates) if hi_candidates else None
    return lo, hi


def _zone_constraint_for_field(zone_idx: int, n_zones: int,
                                global_lo: int, global_hi: int) -> dict:
    """
    Derive [lo, hi] for a given zone index.
    Zone 0 → widest range; higher zones → progressively narrower (up to 40% shrink).
    """
    tightening = zone_idx / max(n_zones - 1, 1)
    range_width = global_hi - global_lo
    if range_width <= 0:
        return {"lo": global_lo, "hi": global_hi}
    margin = int(range_width * tightening * 0.40 / 2)
    lo = global_lo + margin
    hi = global_hi - margin
    if lo >= hi:
        lo, hi = global_lo, global_hi
    return {"lo": lo, "hi": hi}


def _find_sub_accumulators_from_ddg(
    ddg: dict,
    discriminant_name: str,
    input_field_names: set[str],
    layout_structs: list,
    top_struct_name: str,
) -> list[dict]:
    """
    Find state variables that gate the discriminant's increment via CFG analysis.

    The DDG is a pure data-flow graph (no control-flow edges), so a backward
    data-flow BFS from increment stores misses conditions like
    "FlowAccum > 6 AND PressAccum > 5 AND TempAccum > 6" which are in
    control-flow Br guards, not data operands of the Store.

    Algorithm:
      1. Find GEP nodes that define the discriminant (e.g. %FillHead).
      2. Find their non-reset Store successors — these are the increment stores.
         Literal-constant stores (e.g. `store i16 0`) are resets and excluded.
      3. Collect each increment store's `basic_block` label.
      4. Walk upward through the CFG: for each basic block, find all Br nodes
         (in the same function) whose IR strings target that block.  Recurse
         into each Br's own basic block (depth-limited to 8 levels).
      5. For each guard Br, find its ICmp predecessor(s) and resolve them to
         (field, pred, threshold) using the DDG graph.
      6. Keep only range predicates (sgt/sge/slt/sle) on non-input, non-
         discriminant state variables — these are the fields whose values in a
         snapshot indicate how ready the state is to advance the discriminant.
    """
    from collections import Counter
    from .graph import build_graph

    G = build_graph(ddg)
    nodes_list = ddg.get("nodes", [])

    # Dominant function (most nodes) — the one we care about
    target_func: str = Counter(n.get("function", "") for n in nodes_list).most_common(1)[0][0]

    # Step 1+2: find GEP nodes for discriminant, then non-reset Store successors
    disc_gep_ids = {
        n["id"] for n in nodes_list
        if n.get("opcode") == "GetElementPtr"
        and n.get("defines", "").lstrip("%") == discriminant_name
        and n.get("function") == target_func
    }
    if not disc_gep_ids:
        return []

    increment_bbs: set[str] = set()
    for gep_id in disc_gep_ids:
        for succ in G.successors(gep_id):
            node = G.nodes[succ]
            if node.get("opcode") != "Store":
                continue
            if re.search(r"store\s+\w+\s+-?\d+,", node.get("ir", "")):
                continue  # literal constant → reset, not increment
            bb = node.get("basic_block", "")
            if bb:
                increment_bbs.add(bb)

    if not increment_bbs:
        return []

    # Step 3+4: build CFG index and walk upward from increment BBs
    # Br IR strings look like: "br i1 %cond, label %true_bb, label %false_bb"
    # Node basic_block fields have no leading %, so we strip it from labels.
    brs_targeting: dict[str, set[int]] = {}
    br_in_bb: dict[int, str] = {}
    for n in nodes_list:
        if n.get("opcode") != "Br" or n.get("function") != target_func:
            continue
        nid = n["id"]
        for label in re.findall(r"label\s+%?([\w.]+)", n.get("ir", "")):
            brs_targeting.setdefault(label, set()).add(nid)
        br_in_bb[nid] = n.get("basic_block", "")

    visited_bbs: set[str] = set()
    guard_brs: set[int] = set()
    queue: deque[tuple[str, int]] = deque((bb, 0) for bb in increment_bbs)
    while queue:
        bb, depth = queue.popleft()
        if bb in visited_bbs or depth > 8:
            continue
        visited_bbs.add(bb)
        for br_nid in brs_targeting.get(bb, set()):
            guard_brs.add(br_nid)
            parent_bb = br_in_bb.get(br_nid, "")
            if parent_bb and parent_bb not in visited_bbs:
                queue.append((parent_bb, depth + 1))

    # Step 5+6: resolve each guard Br → ICmp → (field, pred, threshold)
    _RANGE_PREDS = {"sgt", "sge", "slt", "sle"}
    seen: set[str] = set()
    result: list[dict] = []

    for br_nid in guard_brs:
        for pred_id in G.predecessors(br_nid):
            if G.nodes[pred_id].get("opcode") != "ICmp":
                continue
            resolved = resolve_icmp(pred_id, G)
            if not resolved:
                continue
            field, pred_str, _threshold = resolved
            if pred_str not in _RANGE_PREDS:
                continue  # skip eq/ne/modular — not range-based health indicators
            if field == discriminant_name or field in input_field_names or field in seen:
                continue
            seen.add(field)
            r = find_field_offset(layout_structs, field, top_struct_name)
            if r is not None:
                off, sz = r
                result.append({"name": field, "byte_offset": off, "byte_size": sz})

    return result


def add_args(sub) -> None:
    sub.add_argument("weights_json", help="<name>_weights.json")
    sub.add_argument("layout_json",  help="<name>_layout.json")
    sub.add_argument("--output", "-o", help="Output path (default: <name>_zone_constraints.json)")
    sub.add_argument("--zones",  "-n", type=int, default=8,
                     help="Number of zones (default: 8)")
    sub.add_argument("--ddg", "-d", metavar="JSON",
                     help="<name>_ddg.json — enables DDG-based sub-accumulator extraction "
                          "(backward BFS from discriminant increment stores)")
    sub.add_argument("--state-hash", "-s", metavar="JSON",
                     help="<name>_harness_heuristics.json — fallback when --ddg is absent "
                          "or yields no results; uses high-watermark state fields")


def run(args) -> None:
    weights_path = Path(args.weights_json)
    layout_path  = Path(args.layout_json)

    weights        = load_weights(weights_path)
    layout_structs = load_layout(layout_path)

    abort_targets = weights.get("abort_targets", [])
    if not abort_targets:
        print("[zones] WARNING: no abort_targets in weights JSON.", file=sys.stderr)
        sys.exit(1)

    resolved = abort_targets[0].get("resolved", {})
    discriminant_name = resolved.get("field")
    max_fillhead_raw  = resolved.get("threshold")
    if not discriminant_name or max_fillhead_raw is None:
        print("[zones] ERROR: abort_targets[0].resolved missing 'field' or 'threshold'.",
              file=sys.stderr)
        sys.exit(1)
    max_fillhead = int(max_fillhead_raw)

    top_struct_name = layout_structs[-1]["struct_name"] if layout_structs else ""
    loc = find_field_offset(layout_structs, discriminant_name, top_struct_name)
    if loc is None:
        print(f"[zones] ERROR: field '{discriminant_name}' not found in '{top_struct_name}'.",
              file=sys.stderr)
        sys.exit(1)
    discriminant_offset, discriminant_size = loc
    print(f"[zones] Discriminant: {discriminant_name} "
          f"(offset={discriminant_offset}, size={discriminant_size}, max={max_fillhead})")

    # -----------------------------------------------------------------------
    # Sub-accumulator fields
    #
    # Priority: --ddg (graph analysis) → --state-hash (hwm fields) → chain fallback
    #
    # --ddg   : backward BFS from discriminant increment stores finds ALL enclosing
    #           ICmp conditions, including compound AND guards the chain misses.
    # --state-hash: high-watermark fields from the state hash config — good fallback
    #           when DDG analysis yields nothing (e.g. pure input-driven targets).
    # chain   : reads accumulation_chain.accumulation_guards — may be incomplete for
    #           compound AND conditions but requires no extra files.
    # -----------------------------------------------------------------------
    input_field_names = {f.get("name", "") for f in weights.get("input_fields", [])}
    sub_accum_fields: list[dict] = []

    # 1. DDG-based (most accurate)
    if getattr(args, "ddg", None):
        ddg = load_json(args.ddg)
        sub_accum_fields = _find_sub_accumulators_from_ddg(
            ddg, discriminant_name, input_field_names, layout_structs, top_struct_name
        )
        if sub_accum_fields:
            print(f"[zones] Sub-accumulators (from DDG): {[f['name'] for f in sub_accum_fields]}")

    # 2. State-hash fallback (reliable when DDG yields nothing)
    if not sub_accum_fields and getattr(args, "state_hash", None):
        import json as _json
        sh = _json.loads(Path(args.state_hash).read_text())
        for f in sh.get("fields", []):
            if f.get("high_watermark") and f.get("name") != discriminant_name:
                sub_accum_fields.append({
                    "name":        f["name"],
                    "byte_offset": f["absolute_byte_offset"],
                    "byte_size":   f["byte_size"],
                })
        if sub_accum_fields:
            print(f"[zones] Sub-accumulators (state-hash fallback): "
                  f"{[f['name'] for f in sub_accum_fields]}")

    # 3. Chain-based fallback (no extra files needed)
    if not sub_accum_fields:
        chain = weights.get("accumulation_chain", [])
        disc_entry = next(
            (lk for lk in chain if lk.get("state_var") == discriminant_name), None
        )
        seen: set[str] = set()
        if disc_entry:
            for guard in disc_entry.get("accumulation_guards", []):
                fname = guard.get("condition_field", "")
                if not fname or fname in seen or fname in input_field_names:
                    continue
                seen.add(fname)
                r = find_field_offset(layout_structs, fname, top_struct_name)
                if r is not None:
                    off, sz = r
                    sub_accum_fields.append({"name": fname, "byte_offset": off, "byte_size": sz})
        if sub_accum_fields:
            print(f"[zones] Sub-accumulators (chain fallback): "
                  f"{[f['name'] for f in sub_accum_fields]}")
        else:
            print("[zones] Sub-accumulators: none found "
                  "(Rust will use state-hash hwm fields at runtime)")

    # -----------------------------------------------------------------------
    # Zone field constraints
    # -----------------------------------------------------------------------
    field_ranges: dict[str, tuple[int, int]] = {}
    for ifield in weights.get("input_fields", []):
        name  = ifield.get("name", "")
        roles = ifield.get("roles", [])
        comps = ifield.get("comparisons", [])
        if "inhibitor" in roles:
            continue
        lo, hi = _derive_range(comps)
        lo = lo if lo is not None else 0
        hi = hi if hi is not None else 100
        if lo >= hi:
            hi = lo + 1
        field_ranges[name] = (lo, hi)

    n_zones   = max(1, args.zones)
    max_discriminant = max_fillhead  # alias for clarity in zone calculations
    zone_size = max(1, (max_discriminant + 1 + n_zones - 1) // n_zones)

    zones = []
    for z in range(n_zones):
        lo = z * zone_size
        hi = min((z + 1) * zone_size, max_fillhead + 1)
        field_constraints = {
            fname: _zone_constraint_for_field(z, n_zones, glo, ghi)
            for fname, (glo, ghi) in field_ranges.items()
        }
        zones.append({
            "id":                z,
            "lo":                lo,
            "hi":                hi,
            "field_constraints": field_constraints,
        })
        print(f"[zones]   zone {z}: discriminant [{lo}, {hi})  "
              f"constraints={list(field_constraints.keys())}")

    # -----------------------------------------------------------------------
    # Output
    # -----------------------------------------------------------------------
    if args.output:
        output_path = Path(args.output)
    else:
        stem = weights_path.stem
        if stem.endswith("_weights"):
            stem = stem[:-len("_weights")]
        output_path = weights_path.parent / f"{stem}_zone_constraints.json"

    import json
    doc = {
        "program":                  top_struct_name,
        "discriminant_field":       discriminant_name,
        "discriminant_byte_offset": discriminant_offset,
        "discriminant_byte_size":   discriminant_size,
        "max_discriminant":         max_fillhead,
        "sub_accumulator_fields":   sub_accum_fields,
        "zones":                    zones,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
    print(f"[zones] Written: {output_path}")
