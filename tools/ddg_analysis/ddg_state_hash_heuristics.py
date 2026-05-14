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

Array elements:  when a comparison uses a constant array index (e.g.
  Buffer[0] > 2, Buffer[1] > 1), both elements are tracked separately
  with their own offsets, thresholds, and bucket counts.

Usage:
    python3 ddg_state_hash_heuristics.py <ddg.json> <layout.json> [--json out.json]
"""

import argparse, json, re, sys
from collections import defaultdict, deque
from pathlib import Path
import networkx as nx


# ---------------------------------------------------------------------------
# Graph helpers
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


def _get_constant_array_index(gep_ir: str) -> int | None:
    """
    Extract constant element index from a constant-index array GEP, e.g.:
      getelementptr inbounds [8 x i16], ptr %Buffer, i32 0, i32 1  →  1
    Returns None for dynamic indices or non-array GEPs.
    """
    m = re.search(
        r'getelementptr\b[^%\[]*\[\d+\s+x\s+\w+\],\s*ptr\s+\S+,\s*i\d+\s+\d+,\s*i\d+\s+(-?\d+)',
        gep_ir
    )
    return int(m.group(1)) if m else None


def _field_key(fname: str, idx: int | None) -> str:
    """Format a (name, index) pair as the dict key used throughout analysis."""
    return f"{fname}[{idx}]" if idx is not None else fname


# ---------------------------------------------------------------------------
# Field resolution — scalar and array-element aware
# ---------------------------------------------------------------------------

def resolve_to_field(start_id: int, G: nx.DiGraph) -> str | None:
    """Walk backwards through the graph to find a named struct GEP (base name only)."""
    r = resolve_to_field_indexed(start_id, G)
    return r[0] if r else None


def resolve_to_field_indexed(start_id: int, G: nx.DiGraph) -> tuple[str, int | None] | None:
    """
    Walk backwards through the graph to find a named struct GEP.
    Returns (field_name, element_index_or_None).
    element_index is set when the Load comes through a constant-index array GEP
    (e.g. Buffer[0] or Buffer[1]); None for scalar fields or dynamic-index accesses.
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
            for pred in G.predecessors(nid):
                pn = G.nodes[pred]
                fname = _is_named_field_gep(pn)
                if fname:
                    return (fname, None)  # scalar struct field
                # array-element GEP: base pointer is one level back
                if pn.get("opcode") == "GetElementPtr":
                    elem_idx = _get_constant_array_index(pn.get("ir", ""))
                    for bp in G.predecessors(pred):
                        bfname = _is_named_field_gep(G.nodes[bp])
                        if bfname:
                            return (bfname, elem_idx)  # array element (constant or dynamic idx)
        for pred in G.predecessors(nid):
            if pred not in visited:
                queue.append(pred)
    return None


def _resolve_stored_field_indexed(nid: int, G: nx.DiGraph) -> tuple[str, int | None] | None:
    """Identify the struct field (and optional element index) a Store writes to."""
    for pred in G.predecessors(nid):
        pn = G.nodes[pred]
        fname = _is_named_field_gep(pn)
        if fname:
            return (fname, None)
        if pn.get("opcode") == "GetElementPtr":
            elem_idx = _get_constant_array_index(pn.get("ir", ""))
            for bp in G.predecessors(pred):
                bfname = _is_named_field_gep(G.nodes[bp])
                if bfname:
                    return (bfname, elem_idx)
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
    """
    Returns the set of field keys (base name or "array[idx]") stored within
    the function.  A base name ("Buffer") is added whenever a dynamic-index
    Store is detected; element keys ("Buffer[0]") are added for constant-index
    Stores.  This ensures array state vars are never mis-classified as inputs.
    """
    stored: set[str] = set()
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Store" or data.get("function") != func:
            continue
        r = _resolve_stored_field_indexed(nid, G)
        if not r:
            continue
        fname, idx = r
        stored.add(fname)                  # base name always
        stored.add(_field_key(fname, idx)) # indexed key (== base when idx is None)
    return stored


def get_comparisons_by_field(G: nx.DiGraph, func: str) -> dict[str, list]:
    """
    For each field (or array element) that appears in an ICmp or Switch, collect
    all (pred, threshold) pairs.  Returns {field_key: [(pred, threshold)]}.
    Array elements get keys like "Buffer[0]" when the array index is a constant.
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
        r = resolve_to_field_indexed(root_id, G)
        if r:
            fname, idx = r
            key = _field_key(fname, idx)
            entry = (key, pred, threshold)
            if entry not in seen:
                seen.add(entry)
                result[key].append((pred, threshold))

    # Switch nodes — each case value is a threshold
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Switch" or data.get("function") != func:
            continue
        ir = data.get("ir", "")
        cases = [int(v) for v in re.findall(r"i\d+\s+(-?\d+),\s*label", ir)]
        if not cases:
            continue
        for pred_id in G.predecessors(nid):
            r = resolve_to_field_indexed(pred_id, G)
            if r:
                fname, idx = r
                key = _field_key(fname, idx)
                for v in cases:
                    entry = (key, "eq", v)
                    if entry not in seen:
                        seen.add(entry)
                        result[key].append(("eq", v))
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

    sink_sizes: dict[int, int | None] = {}
    for sid in sinks:
        ir = G.nodes[sid].get("ir", "")
        m = re.search(r"\[(\d+)\s+x\s+", ir)
        sink_sizes[sid] = int(m.group(1)) if m else None

    visited: set[int] = set()
    q = deque(sinks)
    reached_from: dict[int, set[int]] = defaultdict(set)
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
                    result[fname].add(sz if sz is not None else 0)

    return {k: sorted(v) for k, v in result.items()}


def has_reset_stores(field_key: str, G: nx.DiGraph, func: str) -> bool:
    """True if the field (or its base array) is ever stored with a literal constant."""
    # Accept both "Buffer" and "Buffer[0]" — strip the index to get the base name
    base_name = re.sub(r'\[\d+\]$', '', field_key)
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Store" or data.get("function") != func:
            continue
        r = _resolve_stored_field_indexed(nid, G)
        if not r:
            continue
        fname, _ = r
        if fname != base_name:
            continue
        ir = data.get("ir", "")
        if re.search(r"store\s+\w+\s+-?\d+,", ir):
            return True
    return False


def is_loop_variable(field: str, comparisons: list) -> bool:
    """
    Heuristic: a field is a loop counter if it has BOTH a lower-bound
    (slt/sle) AND an upper-bound (sgt/sge) comparison.
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


def _firing_value(pred: str, threshold: int) -> int | None:
    """
    Return the smallest value v where pred(v, threshold) is True.
    Only meaningful for upper-bound predicates (sgt, sge) that mark
    accumulation milestones.  Returns None for lower-bound predicates.
    """
    if pred == "sge":
        return threshold       # v >= threshold  →  fires at threshold
    if pred == "sgt":
        return threshold + 1   # v >  threshold  →  fires at threshold+1
    return None


def _bucket_config_for_icmp(comparisons: list) -> dict:
    """
    ICmp-gated accumulator.

    Bucket count is derived from the highest FIRING VALUE across all
    upper-bound comparisons:
      sge N  →  fires at N   →  N+1 buckets  {0, 1, …, N-1, ≥N}
      sgt N  →  fires at N+1 →  N+2 buckets  {0, 1, …, N,   ≥N+1}

    For small firing values (≤ 32): fine-grained so every increment is
    a distinct bucket.
    For large firing values (> 32): log2-spaced to keep bucket count sane.
    """
    range_preds = {"sgt", "sge", "slt", "sle"}
    has_range = any(p in range_preds for p, _ in comparisons)

    if has_range:
        # Drop ne/eq — they're boolean casts of range results.
        effective = [(p, t) for p, t in comparisons if p in range_preds]
    else:
        effective = comparisons

    firing_values = [
        fv for p, t in effective
        for fv in [_firing_value(p, t)]
        if fv is not None and fv >= 0
    ]

    if not firing_values:
        # Only lower-bound or ne/eq comparisons — minimal useful bucketing
        thresholds = sorted({t for _, t in effective if t >= 0})
        if not thresholds:
            return {"scheme": "binary", "thresholds": [0], "bucket_count": 2,
                    "note": "no non-negative threshold found, fallback binary"}
        return {"scheme": "binary", "thresholds": thresholds, "bucket_count": 2,
                "note": f"lower-bound only comparisons, binary split at {thresholds[0]}"}

    max_fv = max(firing_values)
    thresholds_out = sorted({t for _, t in effective if t >= 0})

    if max_fv <= 32:
        # One bucket per value 0..max_fv-1, plus one ≥max_fv bucket.
        count = max_fv + 1
        return {
            "scheme": "threshold_fine",
            "thresholds": thresholds_out,
            "bucket_count": count,
            "note": f"fine-grained 0..{max_fv-1} + ≥{max_fv} ({count} buckets)",
        }
    else:
        boundaries = []
        b = 1
        while b < max_fv:
            boundaries.append(b)
            b *= 2
        boundaries.append(max_fv)
        return {
            "scheme": "threshold_log2",
            "thresholds": boundaries,
            "bucket_count": len(boundaries) + 1,
            "note": f"log2-spaced up to {max_fv} ({len(boundaries)+1} buckets)",
        }


def _bucket_config_for_gep(array_sizes: list) -> dict:
    """
    Danger-arm variable (no or only lower-bound comparisons, feeds dynamic GEP).

    If the array bound is known and ≤ 64: raw_capped — every value from
    0 to bound is its own bucket, ≥bound+1 is the OOB bucket.

    If bound > 64 or unknown: quartile (4 equal-width buckets + OOB).
    """
    if not array_sizes or (len(array_sizes) == 1 and array_sizes[0] == 0):
        return {"scheme": "binary", "thresholds": [], "bucket_count": 2,
                "note": "no array bound found, fallback binary"}

    bound = min(s for s in array_sizes if s > 0)

    if bound <= 64:
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
    Returns {field_key: (absolute_byte_offset, byte_size, llvm_type)}.

    For array fields, emits both the base name and per-element keys:
      "Buffer"    →  (base_offset, total_size, "[8 x i16]")
      "Buffer[0]" →  (base_offset+0,  2, "i16")
      "Buffer[1]" →  (base_offset+2,  2, "i16")
      ...
    If main_func is a nested struct inside another layout entry the base
    offset of the outer struct is added.
    """
    main_layout = next((l for l in layout if l["struct_name"] == main_func), None)
    if not main_layout:
        return {}

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
        size = field["byte_size"]
        ltype = field["llvm_type"]

        # Scalar or struct-typed field
        result[name] = (abs_offset, size, ltype)

        # Array field: also emit per-element entries
        arr_m = re.match(r'\[(\d+)\s+x\s+(\w+)\]', ltype)
        if arr_m:
            arr_len = int(arr_m.group(1))
            elem_type = arr_m.group(2)
            elem_size = size // arr_len if arr_len else size
            for i in range(arr_len):
                result[f"{name}[{i}]"] = (abs_offset + i * elem_size, elem_size, elem_type)

    return result


# ---------------------------------------------------------------------------
# Main analysis
# ---------------------------------------------------------------------------

def analyse(ddg: dict, layout: list) -> dict:
    G = build_graph(ddg)
    main_func = find_main_func(G)

    stored     = get_stored_fields(G, main_func)
    comps      = get_comparisons_by_field(G, main_func)
    gep_fields = get_gep_sink_fields(G, main_func)
    offsets    = compute_absolute_offsets(main_func, layout)

    # Candidate fields: must have a known offset in the main struct
    known_fields = set(offsets.keys())

    # A field key is an input if neither its key nor its base name was stored.
    def is_input(fkey: str) -> bool:
        base = re.sub(r'\[\d+\]$', '', fkey)
        return fkey not in stored and base not in stored

    selected = []
    excluded = []

    # Union of both arms — restricted to known struct fields
    # gep_fields uses base names, so map them to known_fields that share that base
    gep_keys: set[str] = set()
    for gf in gep_fields:
        if gf in known_fields:
            gep_keys.add(gf)
        # Also include specific array element keys if the base is a GEP sink
        for k in known_fields:
            if re.sub(r'\[\d+\]$', '', k) == gf:
                gep_keys.add(k)

    candidates = (set(comps.keys()) | gep_keys) & known_fields

    for fname in sorted(candidates):
        if is_input(fname):
            excluded.append((fname, "input field"))
            continue

        if fname.startswith("__"):
            excluded.append((fname, "compiler internal"))
            continue

        field_comps = comps.get(fname, [])
        base_name   = re.sub(r'\[\d+\]$', '', fname)
        field_geps  = gep_fields.get(base_name, [])

        is_switch = all(p == "eq" for p, _ in field_comps) and len(field_comps) >= 3
        is_icmp   = bool(field_comps) and not is_switch
        is_danger = bool(field_geps)

        if is_icmp and is_loop_variable(fname, field_comps):
            excluded.append((fname, "loop variable (symmetric bounds)"))
            continue

        if not field_comps and not is_danger:
            excluded.append((fname, "no comparison and not a GEP sink"))
            continue

        # Determine bucket config
        if is_switch:
            case_values = [t for _, t in field_comps]
            bucket = _bucket_config_for_switch(case_values)
            arm = "switch"
        elif is_icmp and is_danger:
            # Both arms apply: pick the scheme with more buckets (better gradient).
            icmp_bucket = _bucket_config_for_icmp(field_comps)
            gep_bucket  = _bucket_config_for_gep(field_geps)
            if gep_bucket["bucket_count"] > icmp_bucket["bucket_count"]:
                bucket = gep_bucket
                arm    = "icmp+gep_sink(gep_scheme)"
            else:
                bucket = icmp_bucket
                arm    = "icmp+gep_sink"
        elif is_icmp:
            bucket = _bucket_config_for_icmp(field_comps)
            arm = "icmp"
        else:
            bucket = _bucket_config_for_gep(field_geps)
            arm = "gep_sink"

        abs_offset, byte_size, llvm_type = offsets.get(fname, (0, 0, "?"))
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

    # Total macro-state count (product of all bucket counts)
    total = 1
    for f in selected:
        total *= f["bucket_count"]

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
    if result["fields"]:
        print(f"{tag} Selected fields ({len(result['fields'])}):")
        for f in result["fields"]:
            hwm_tag = " [hwm]" if f["high_watermark"] else ""
            print(f"{tag}   {f['name']:20s} arm={f['selection_arm']:22s} "
                  f"scheme={f['bucket_scheme']:15s} buckets={f['bucket_count']:3d} "
                  f"offset={f['absolute_byte_offset']:3d}{hwm_tag}")
            print(f"{tag}     {f['note']}")
    else:
        print(f"{tag} No state fields selected.")
        print(f"{tag} This program has no multi-cycle accumulation state visible")
        print(f"{tag} in the DDG — the bug may be reachable in a single scan cycle.")
    if result["_excluded"]:
        print()
        print(f"{tag} Excluded fields ({len(result['_excluded'])}):")
        for fname, reason in result["_excluded"]:
            print(f"{tag}   {fname:20s} -- {reason}")


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
        out = {k: v for k, v in result.items() if not k.startswith("_")}
        Path(args.json).write_text(json.dumps(out, indent=2))
        print(f"\n[state_hash] Wrote {args.json}")


if __name__ == "__main__":
    main()
