#!/usr/bin/env python3
"""
ddg_state_hash_heuristics.py

Single responsibility: given a DDG JSON and layout JSON, produce a
state_hash_config.json describing which struct fields to observe at
runtime, how to bucket their values, and the resulting macro-state count.

Two selection arms:
  comparison-arm  -- fields that appear in ICmp/Switch comparisons.
                     These gate control flow; their value determines
                     which branch runs next cycle.
  danger-arm      -- fields that feed into dynamic GEP sinks (unchecked
                     array accesses).  These cause the vulnerability even
                     if they are never compared.

Usage:
    python3 ddg_state_hash_heuristics.py <ddg.json> <layout.json> [--json out.json]
"""

import argparse, json, re, sys
from collections import defaultdict, deque
from pathlib import Path
import networkx as nx


# ---------------------------------------------------------------------------
# Graph helpers (minimal reimplementation, no import from sibling scripts)
# ---------------------------------------------------------------------------

def build_graph(ddg: dict) -> nx.DiGraph:
    G = nx.DiGraph()
    for n in ddg["nodes"]:
        G.add_node(n["id"], **n)
    for e in ddg["edges"]:
        G.add_edge(e["from"], e["to"])
    return G


def _is_named_field_gep(node: dict) -> str | None:
    """Return field name if this is a named struct GEP, else None."""
    if node.get("opcode") != "GetElementPtr":
        return None
    defines = node.get("defines", "")
    if not defines:
        return None
    name = defines.lstrip("%")
    if not name or name[0].isdigit() or name.startswith("tmpVar") or name.startswith("__"):
        return None
    if name in ("this", "self", "deref"):
        return None
    return name


def resolve_to_field(start_id: int, G: nx.DiGraph) -> str | None:
    """Walk backwards through the graph to find a named struct GEP."""
    visited: set[int] = set()
    queue = deque([start_id])
    while queue:
        nid = queue.popleft()
        if nid in visited:
            continue
        visited.add(nid)
        node = G.nodes[nid]
        if node.get("opcode") == "Load":
            for pred in G.predecessors(nid):
                pn = G.nodes[pred]
                fname = _is_named_field_gep(pn)
                if fname:
                    return fname
                # array-element GEP: base pointer is one more level back
                if pn.get("opcode") == "GetElementPtr":
                    for bp in G.predecessors(pred):
                        bfname = _is_named_field_gep(G.nodes[bp])
                        if bfname:
                            return bfname
        for pred in G.predecessors(nid):
            if pred not in visited:
                queue.append(pred)
    return None


def _resolve_stored_field(nid: int, G: nx.DiGraph) -> str | None:
    """Identify the struct field a Store instruction writes to."""
    for pred in G.predecessors(nid):
        pn = G.nodes[pred]
        fname = _is_named_field_gep(pn)
        if fname:
            return fname
        if pn.get("opcode") == "GetElementPtr":
            for bp in G.predecessors(pred):
                bfname = _is_named_field_gep(G.nodes[bp])
                if bfname:
                    return bfname
    return None


# ---------------------------------------------------------------------------
# ICmp parsing
# ---------------------------------------------------------------------------

_ICMP_RE = re.compile(
    r"icmp\s+(s?(?:gt|ge|lt|le)|ne|eq)\s+\w+\s+(%-?[\w.]+|-?\d+),\s*(%-?[\w.]+|-?\d+)"
)

def _parse_icmp(ir: str):
    m = _ICMP_RE.search(ir)
    if not m:
        return None
    return m.group(1), m.group(2), m.group(3)


def _unwrap_icmp(icmp_id: int, G: nx.DiGraph) -> int:
    """Follow ZExt/boolean-cast chains to the root comparison node."""
    node = G.nodes[icmp_id]
    parsed = _parse_icmp(node.get("ir", ""))
    if not parsed:
        return icmp_id
    pred, lhs, rhs = parsed
    if pred not in ("ne", "eq") or rhs != "0":
        return icmp_id
    for pred_id in G.predecessors(icmp_id):
        pn = G.nodes[pred_id]
        if pn.get("defines", "").lstrip("%") == lhs.lstrip("%"):
            if pn.get("opcode") in ("ZExt", "SExt"):
                for pp in G.predecessors(pred_id):
                    if G.nodes[pp].get("opcode") == "ICmp":
                        return pp
    return icmp_id


# ---------------------------------------------------------------------------
# Field identification
# ---------------------------------------------------------------------------

def find_main_func(G: nx.DiGraph) -> str:
    counts: dict[str, int] = defaultdict(int)
    for _, data in G.nodes(data=True):
        counts[data.get("function", "")] += 1
    return max(counts, key=counts.__getitem__)


def get_stored_fields(G: nx.DiGraph, func: str) -> set[str]:
    """Fields that are stored to within the function — these are state vars."""
    stored = set()
    for nid, data in G.nodes(data=True):
        if data.get("opcode") == "Store" and data.get("function") == func:
            fname = _resolve_stored_field(nid, G)
            if fname:
                stored.add(fname)
    return stored


def get_comparisons_by_field(G: nx.DiGraph, func: str) -> dict[str, list]:
    """
    For each field that appears in an ICmp or Switch, collect all
    (pred, threshold) pairs.  Returns only fields with at least one
    resolved comparison.
    """
    result: dict[str, list] = defaultdict(list)
    seen: set[tuple] = set()

    # ICmp nodes
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "ICmp" or data.get("function") != func:
            continue
        root_id = _unwrap_icmp(nid, G)
        parsed = _parse_icmp(G.nodes[root_id].get("ir", ""))
        if not parsed:
            continue
        pred, lhs, rhs = parsed
        if not re.match(r"^-?\d+$", rhs):
            continue
        threshold = int(rhs)
        field = resolve_to_field(root_id, G)
        if field:
            key = (field, pred, threshold)
            if key not in seen:
                seen.add(key)
                result[field].append((pred, threshold))

    # Switch nodes — each case value is a threshold
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Switch" or data.get("function") != func:
            continue
        ir = data.get("ir", "")
        cases = [int(v) for v in re.findall(r"i\d+\s+(-?\d+),\s*label", ir)]
        if not cases:
            continue
        # Find the field the switch dispatches on
        for pred_id in G.predecessors(nid):
            field = resolve_to_field(pred_id, G)
            if field:
                for v in cases:
                    key = (field, "eq", v)
                    if key not in seen:
                        seen.add(key)
                        result[field].append(("eq", v))
                break

    return dict(result)


def get_gep_sink_fields(G: nx.DiGraph, func: str) -> dict[str, list]:
    """
    Fields reachable backwards from dynamic GEP sinks within func.
    Returns {field_name: [array_sizes_from_gep_ir]}.
    """
    sinks = [
        nid for nid, d in G.nodes(data=True)
        if d.get("has_dynamic_index") and d.get("function") == func
    ]
    if not sinks:
        return {}

    # Collect array sizes from each sink's GEP IR
    sink_sizes: dict[int, int | None] = {}
    for sid in sinks:
        ir = G.nodes[sid].get("ir", "")
        m = re.search(r"\[(\d+)\s+x\s+", ir)
        sink_sizes[sid] = int(m.group(1)) if m else None

    # BFS backwards from all sinks
    visited: set[int] = set()
    q = deque(sinks)
    reached_from: dict[int, set[int]] = defaultdict(set)  # node -> which sinks reached it
    for sid in sinks:
        reached_from[sid].add(sid)

    while q:
        nid = q.popleft()
        if nid in visited:
            continue
        visited.add(nid)
        for pred in G.predecessors(nid):
            if pred not in visited:
                reached_from[pred] |= reached_from[nid]
                q.append(pred)

    # Collect named fields reached and which array sizes are relevant
    result: dict[str, set] = defaultdict(set)
    for nid in visited:
        node = G.nodes[nid]
        if node.get("opcode") != "Load":
            continue
        for pred in G.predecessors(nid):
            pn = G.nodes[pred]
            fname = _is_named_field_gep(pn)
            if not fname:
                if pn.get("opcode") == "GetElementPtr":
                    for bp in G.predecessors(pred):
                        fname = _is_named_field_gep(G.nodes[bp])
                        if fname:
                            break
            if fname:
                for sid in reached_from[nid]:
                    sz = sink_sizes.get(sid)
                    if sz is not None:
                        result[fname].add(sz)
                    else:
                        result[fname].add(0)

    return {k: sorted(v) for k, v in result.items()}


def has_reset_stores(field: str, G: nx.DiGraph, func: str) -> bool:
    """True if the field is ever stored with a literal constant (reset pattern)."""
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Store" or data.get("function") != func:
            continue
        if _resolve_stored_field(nid, G) != field:
            continue
        ir = data.get("ir", "")
        if re.search(r"store\s+\w+\s+-?\d+,", ir):
            return True
    return False


def is_loop_variable(field: str, comparisons: list) -> bool:
    """
    Heuristic: a field is a loop counter if it has BOTH a lower-bound
    (slt/sle) AND an upper-bound (sgt/sge) comparison.  Loop counters
    are uninteresting for state hashing because they reset every invocation.
    """
    preds = {p for p, _ in comparisons}
    has_upper = bool(preds & {"sgt", "sge"})
    has_lower = bool(preds & {"slt", "sle"})
    return has_upper and has_lower


# ---------------------------------------------------------------------------
# Bucket scheme determination
# ---------------------------------------------------------------------------

def _bucket_config_for_switch(case_values: list) -> dict:
    """Switch discriminant: exact case values as identity buckets."""
    vals = sorted(set(case_values))
    return {
        "scheme": "identity",
        "thresholds": vals,
        "bucket_count": len(vals),
        "note": f"Switch dispatch: {len(vals)} cases",
    }


def _bucket_config_for_icmp(comparisons: list) -> dict:
    """
    ICmp-gated accumulator.

    For small thresholds (≤ 32): fine-grained below the threshold so
    every increment is a new bucket.  Layout: {0, 1, …, T-1, ≥T}.

    For large thresholds (> 32): log2-spaced to keep bucket count sane.

    Boolean-cast artefacts (ne/eq against 0 or 1) are dropped when real
    range comparisons (sgt/sge/slt/sle) are present — they add no bucketing
    information beyond what the range comparison already captures.
    """
    range_preds = {"sgt", "sge", "slt", "sle"}
    has_range = any(p in range_preds for p, _ in comparisons)

    if has_range:
        # Drop ne/eq comparisons — they're boolean casts of range results.
        effective = [(p, t) for p, t in comparisons if p in range_preds]
    else:
        effective = comparisons

    # Use the highest non-negative threshold.
    thresholds = sorted({t for _, t in effective if t >= 0})
    if not thresholds:
        return {"scheme": "binary", "thresholds": [0], "bucket_count": 2,
                "note": "no non-negative threshold found, fallback binary"}

    max_thresh = max(thresholds)

    if max_thresh <= 32:
        # One bucket per value 0..max_thresh-1, plus one ≥max_thresh bucket.
        count = max_thresh + 1
        return {
            "scheme": "threshold_fine",
            "thresholds": thresholds,
            "bucket_count": count,
            "note": f"fine-grained 0..{max_thresh-1} + ≥{max_thresh} ({count} buckets)",
        }
    else:
        # Log2-spaced boundaries.
        boundaries = []
        b = 1
        while b < max_thresh:
            boundaries.append(b)
            b *= 2
        boundaries.append(max_thresh)
        return {
            "scheme": "threshold_log2",
            "thresholds": boundaries,
            "bucket_count": len(boundaries) + 1,
            "note": f"log2-spaced up to {max_thresh} ({len(boundaries)+1} buckets)",
        }


def _bucket_config_for_gep(array_sizes: list) -> dict:
    """
    Danger-arm variable (no comparison, feeds into dynamic GEP).

    If the array bound is known and ≤ 64: raw_capped — every value from
    0 to bound is its own bucket, ≥bound+1 is the OOB bucket.  This
    gives maximum gradient toward the vulnerability because each
    increment is distinct progress.

    If bound > 64 or unknown: quartile (4 equal-width buckets + OOB).
    """
    if not array_sizes or (len(array_sizes) == 1 and array_sizes[0] == 0):
        return {"scheme": "binary", "thresholds": [], "bucket_count": 2,
                "note": "no array bound found, fallback binary"}

    bound = min(s for s in array_sizes if s > 0)

    if bound <= 64:
        # Values 0..bound individually, ≥bound+1 merged into OOB bucket.
        return {
            "scheme": "raw_capped",
            "thresholds": [bound],
            "bucket_count": bound + 1,
            "note": f"raw values 0..{bound-1} + OOB (≥{bound}) = {bound+1} buckets",
        }
    else:
        q = bound // 4
        boundaries = [q, 2*q, 3*q, bound]
        return {
            "scheme": "quartile",
            "thresholds": boundaries,
            "bucket_count": len(boundaries) + 1,
            "note": f"quartile over [0,{bound}]: {len(boundaries)+1} buckets",
        }


# ---------------------------------------------------------------------------
# Absolute byte offset within the state buffer
# ---------------------------------------------------------------------------

def compute_absolute_offsets(main_func: str, layout: list) -> dict[str, tuple[int, int, str]]:
    """
    Returns {field_name: (absolute_byte_offset, byte_size, llvm_type)} where
    absolute_byte_offset is relative to the buffer returned by prism_get_state().

    If main_func is a nested struct inside the last layout entry (e.g. PumpController
    inside PLC_PRG), the base offset of the nested struct is added.
    """
    # Find the layout entry for the main function
    main_layout = next((l for l in layout if l["struct_name"] == main_func), None)
    if not main_layout:
        return {}

    # Find the base offset: does another layout entry contain a field whose
    # llvm_type references the main function struct?
    base_offset = 0
    for struct in layout:
        if struct["struct_name"] == main_func:
            continue
        for field in struct.get("fields", []):
            lt = field.get("llvm_type", "")
            if main_func in lt and lt.startswith("%"):
                base_offset = field["byte_offset"]
                break

    result = {}
    for field in main_layout.get("fields", []):
        name = field.get("name")
        if not name or name == "__vtable":
            continue
        abs_offset = base_offset + field["byte_offset"]
        result[name] = (abs_offset, field["byte_size"], field["llvm_type"])

    return result


# ---------------------------------------------------------------------------
# Main analysis
# ---------------------------------------------------------------------------

def analyse(ddg: dict, layout: list) -> dict:
    G = build_graph(ddg)
    main_func = find_main_func(G)

    stored   = get_stored_fields(G, main_func)
    comps    = get_comparisons_by_field(G, main_func)
    gep_fields = get_gep_sink_fields(G, main_func)
    offsets  = compute_absolute_offsets(main_func, layout)

    # Candidate fields: must be in the main function's struct
    known_fields = set(offsets.keys())

    # Determine which fields are inputs (never stored within the function).
    # A field stored within the function is a state variable.
    input_fields = known_fields - stored

    selected = []
    excluded = []

    # Union of both arms — then filter
    candidates = (set(comps.keys()) | set(gep_fields.keys())) & known_fields

    for fname in sorted(candidates):
        # Skip inputs (set externally by the harness, not state)
        if fname in input_fields:
            excluded.append((fname, "input field"))
            continue

        # Skip __vtable / compiler internals
        if fname.startswith("__"):
            excluded.append((fname, "compiler internal"))
            continue

        field_comps = comps.get(fname, [])
        field_geps  = gep_fields.get(fname, [])

        # Determine selection arm(s)
        is_switch = all(p == "eq" for p, _ in field_comps) and len(field_comps) >= 3
        is_icmp   = bool(field_comps) and not is_switch
        is_danger = bool(field_geps)

        # Loop variable heuristic: has both upper and lower bound comparisons
        if is_icmp and is_loop_variable(fname, field_comps):
            excluded.append((fname, "loop variable (symmetric bounds)"))
            continue

        # Pure output: Status is a copy of Mode, has no comparisons, not a GEP sink
        if not field_comps and not field_geps:
            excluded.append((fname, "no comparison and not a GEP sink"))
            continue

        # Determine bucket config
        if is_switch:
            case_values = [t for _, t in field_comps]
            bucket = _bucket_config_for_switch(case_values)
            arm = "switch"
        elif is_icmp:
            bucket = _bucket_config_for_icmp(field_comps)
            arm = "icmp"
            if is_danger:
                arm = "icmp+gep_sink"
        else:
            bucket = _bucket_config_for_gep(field_geps)
            arm = "gep_sink"

        abs_offset, byte_size, llvm_type = offsets.get(fname, (0, 0, "?"))
        # Switch discriminants describe current mode — track final value, not max.
        # Accumulators with reset stores need high_watermark to capture peak progress.
        hwm = (not is_switch) and (has_reset_stores(fname, G, main_func) or is_danger)

        selected.append({
            "name": fname,
            "absolute_byte_offset": abs_offset,
            "byte_size": byte_size,
            "llvm_type": llvm_type,
            "selection_arm": arm,
            "comparisons": [{"pred": p, "threshold": t} for p, t in field_comps],
            "gep_array_sizes": field_geps,
            "bucket_scheme": bucket["scheme"],
            "thresholds": bucket["thresholds"],
            "bucket_count": bucket["bucket_count"],
            "high_watermark": hwm,
            "note": bucket["note"],
        })
        excluded  # keep going

    # Total macro-state count (product of all bucket counts)
    total = 1
    for f in selected:
        total *= f["bucket_count"]

    # Recommend a shmem size: next power of 2 above total * 2
    shmem = 256
    while shmem < total * 2:
        shmem *= 2
    shmem = min(shmem, 65536)

    return {
        "schema_version": 1,
        "program": main_func,
        "total_macro_states": total,
        "recommended_shmem_size": shmem,
        "fields": selected,
        "_excluded": excluded,
    }


# ---------------------------------------------------------------------------
# Debug output
# ---------------------------------------------------------------------------

def print_summary(result: dict):
    tag = "[state_hash]"
    prog = result["program"]
    print(f"{tag} Program            : {prog}")
    print(f"{tag} Total macro-states : {result['total_macro_states']}")
    print(f"{tag} Shmem size hint    : {result['recommended_shmem_size']} bytes")
    print()
    print(f"{tag} Selected fields ({len(result['fields'])}):")
    for f in result["fields"]:
        hwm_tag = " [hwm]" if f["high_watermark"] else ""
        print(f"{tag}   {f['name']:18s} arm={f['selection_arm']:14s} "
              f"scheme={f['bucket_scheme']:15s} buckets={f['bucket_count']:3d} "
              f"offset={f['absolute_byte_offset']:3d}{hwm_tag}")
        print(f"{tag}     {f['note']}")
    if result["_excluded"]:
        print()
        print(f"{tag} Excluded fields ({len(result['_excluded'])}):")
        for fname, reason in result["_excluded"]:
            print(f"{tag}   {fname:18s} -- {reason}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Generate state hash config from DDG + layout")
    ap.add_argument("ddg",    help="<target>_ddg.json")
    ap.add_argument("layout", help="<target>_layout.json")
    ap.add_argument("--json", metavar="OUT", help="Write config JSON to file")
    args = ap.parse_args()

    with open(args.ddg)    as f: ddg    = json.load(f)
    with open(args.layout) as f: layout = json.load(f)

    result = analyse(ddg, layout)
    print_summary(result)

    if args.json:
        # Strip the internal _excluded key before writing
        out = {k: v for k, v in result.items() if not k.startswith("_")}
        Path(args.json).write_text(json.dumps(out, indent=2))
        print(f"\n[state_hash] Wrote {args.json}")


if __name__ == "__main__":
    main()
