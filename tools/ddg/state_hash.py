from __future__ import annotations

import json
import re
from collections import defaultdict, deque
from pathlib import Path

import networkx as nx

from .graph import build_graph, named_field_from_gep, get_constant_array_index, field_key, find_main_func
from .fields import resolve_to_field_indexed, parse_icmp, unwrap_icmp, compute_absolute_offsets
from .io import load_ddg, load_layout


# ---------------------------------------------------------------------------
# Store-field resolution (local — returns indexed tuple for array tracking)
# ---------------------------------------------------------------------------

def _resolve_stored_field_indexed(nid: int, G: nx.DiGraph) -> tuple[str, int | None] | None:
    for pred in G.predecessors(nid):
        pn = G.nodes[pred]
        fname = named_field_from_gep(pn)
        if fname:
            return (fname, None)
        if pn.get("opcode") == "GetElementPtr":
            elem_idx = get_constant_array_index(pn.get("ir", ""))
            for bp in G.predecessors(pred):
                bfname = named_field_from_gep(G.nodes[bp])
                if bfname:
                    return (bfname, elem_idx)
    return None


# ---------------------------------------------------------------------------
# Field identification
# ---------------------------------------------------------------------------

def _get_stored_fields(G: nx.DiGraph, func: str) -> set[str]:
    stored: set[str] = set()
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Store" or data.get("function") != func:
            continue
        r = _resolve_stored_field_indexed(nid, G)
        if not r:
            continue
        fname, idx = r
        stored.add(fname)
        stored.add(field_key(fname, idx))
    return stored


def _get_comparisons_by_field(G: nx.DiGraph, func: str) -> dict[str, list]:
    result: dict[str, list] = defaultdict(list)
    seen: set[tuple] = set()

    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "ICmp" or data.get("function") != func:
            continue
        root_id = unwrap_icmp(nid, G)
        parsed = parse_icmp(G.nodes[root_id].get("ir", ""))
        if not parsed:
            continue
        pred, lhs, rhs = parsed
        if not re.match(r"^-?\d+$", rhs):
            continue
        threshold = int(rhs)
        r = resolve_to_field_indexed(root_id, G)
        if r:
            fname, idx = r
            key   = field_key(fname, idx)
            entry = (key, pred, threshold)
            if entry not in seen:
                seen.add(entry)
                result[key].append((pred, threshold))

    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Switch" or data.get("function") != func:
            continue
        ir    = data.get("ir", "")
        cases = [int(v) for v in re.findall(r"i\d+\s+(-?\d+),\s*label", ir)]
        if not cases:
            continue
        for pred_id in G.predecessors(nid):
            r = resolve_to_field_indexed(pred_id, G)
            if r:
                fname, idx = r
                key = field_key(fname, idx)
                for v in cases:
                    entry = (key, "eq", v)
                    if entry not in seen:
                        seen.add(entry)
                        result[key].append(("eq", v))
                break

    return dict(result)


def _get_gep_sink_fields(G: nx.DiGraph, func: str) -> dict[str, list]:
    sinks = [
        nid for nid, d in G.nodes(data=True)
        if d.get("has_dynamic_index") and d.get("function") == func
    ]
    if not sinks:
        return {}

    sink_sizes: dict[int, int | None] = {}
    for sid in sinks:
        ir = G.nodes[sid].get("ir", "")
        m  = re.search(r"\[(\d+)\s+x\s+", ir)
        sink_sizes[sid] = int(m.group(1)) if m else None

    visited: set[int] = set()
    q: deque = deque(sinks)
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
        if G.nodes[nid].get("opcode") != "Load":
            continue
        for pred in G.predecessors(nid):
            pn = G.nodes[pred]
            fname = named_field_from_gep(pn)
            if not fname and pn.get("opcode") == "GetElementPtr":
                for bp in G.predecessors(pred):
                    fname = named_field_from_gep(G.nodes[bp])
                    if fname:
                        break
            if fname:
                for sid in reached_from[nid]:
                    sz = sink_sizes.get(sid)
                    result[fname].add(sz if sz is not None else 0)

    return {k: sorted(v) for k, v in result.items()}


def _has_reset_stores(field_key_str: str, G: nx.DiGraph, func: str) -> bool:
    base_name = re.sub(r"\[\d+\]$", "", field_key_str)
    for nid, data in G.nodes(data=True):
        if data.get("opcode") != "Store" or data.get("function") != func:
            continue
        r = _resolve_stored_field_indexed(nid, G)
        if not r:
            continue
        fname, _ = r
        if fname != base_name:
            continue
        if re.search(r"store\s+\w+\s+-?\d+,", data.get("ir", "")):
            return True
    return False


def _is_loop_variable(comparisons: list) -> bool:
    preds = {p for p, _ in comparisons}
    return bool(preds & {"sgt", "sge"}) and bool(preds & {"slt", "sle"})


# ---------------------------------------------------------------------------
# Bucket scheme determination
# ---------------------------------------------------------------------------

def _bucket_for_switch(case_values: list) -> dict:
    vals = sorted(set(case_values))
    return {
        "scheme":       "identity",
        "thresholds":   vals,
        "bucket_count": len(vals),
        "note":         f"Switch dispatch: {len(vals)} cases",
    }


def _firing_value(pred: str, threshold: int) -> int | None:
    if pred == "sge":
        return threshold
    if pred == "sgt":
        return threshold + 1
    return None


def _bucket_for_icmp(comparisons: list) -> dict:
    range_preds = {"sgt", "sge", "slt", "sle"}
    has_range   = any(p in range_preds for p, _ in comparisons)
    effective   = [(p, t) for p, t in comparisons if p in range_preds] if has_range else comparisons

    firing_values = [
        fv for p, t in effective
        for fv in [_firing_value(p, t)]
        if fv is not None and fv >= 0
    ]

    if not firing_values:
        thresholds = sorted({t for _, t in effective if t >= 0})
        if not thresholds:
            return {"scheme": "binary", "thresholds": [0], "bucket_count": 2,
                    "note": "no non-negative threshold found, fallback binary"}
        return {"scheme": "binary", "thresholds": thresholds, "bucket_count": 2,
                "note": f"lower-bound only comparisons, binary split at {thresholds[0]}"}

    max_fv = max(firing_values)
    thresholds_out = sorted({t for _, t in effective if t >= 0})

    if max_fv <= 32:
        count = max_fv + 1
        return {
            "scheme":       "threshold_fine",
            "thresholds":   thresholds_out,
            "bucket_count": count,
            "note":         f"fine-grained 0..{max_fv - 1} + ≥{max_fv} ({count} buckets)",
        }
    boundaries = []
    b = 1
    while b < max_fv:
        boundaries.append(b)
        b *= 2
    boundaries.append(max_fv)
    return {
        "scheme":       "threshold_log2",
        "thresholds":   boundaries,
        "bucket_count": len(boundaries) + 1,
        "note":         f"log2-spaced up to {max_fv} ({len(boundaries) + 1} buckets)",
    }


def _bucket_for_gep(array_sizes: list) -> dict:
    if not array_sizes or (len(array_sizes) == 1 and array_sizes[0] == 0):
        return {"scheme": "binary", "thresholds": [], "bucket_count": 2,
                "note": "no array bound found, fallback binary"}
    bound = min(s for s in array_sizes if s > 0)
    if bound <= 64:
        return {
            "scheme":       "raw_capped",
            "thresholds":   [bound],
            "bucket_count": bound + 1,
            "note":         f"raw values 0..{bound - 1} + OOB (≥{bound}) = {bound + 1} buckets",
        }
    q = bound // 4
    boundaries = [q, 2 * q, 3 * q, bound]
    return {
        "scheme":       "quartile",
        "thresholds":   boundaries,
        "bucket_count": len(boundaries) + 1,
        "note":         f"quartile over [0,{bound}]: {len(boundaries) + 1} buckets",
    }


# ---------------------------------------------------------------------------
# Main analysis
# ---------------------------------------------------------------------------

def analyse(ddg: dict, layout: list) -> dict:
    G         = build_graph(ddg)
    main_func = find_main_func(G)

    stored     = _get_stored_fields(G, main_func)
    comps      = _get_comparisons_by_field(G, main_func)
    gep_fields = _get_gep_sink_fields(G, main_func)
    offsets    = compute_absolute_offsets(main_func, layout)

    known_fields = set(offsets.keys())

    def is_input(fkey: str) -> bool:
        base = re.sub(r"\[\d+\]$", "", fkey)
        return fkey not in stored and base not in stored

    gep_keys: set[str] = set()
    for gf in gep_fields:
        if gf in known_fields:
            gep_keys.add(gf)
        for k in known_fields:
            if re.sub(r"\[\d+\]$", "", k) == gf:
                gep_keys.add(k)

    candidates = (set(comps.keys()) | gep_keys) & known_fields

    selected = []
    excluded = []

    for fname in sorted(candidates):
        if is_input(fname):
            excluded.append((fname, "input field"))
            continue
        if fname.startswith("__"):
            excluded.append((fname, "compiler internal"))
            continue

        field_comps = comps.get(fname, [])
        base_name   = re.sub(r"\[\d+\]$", "", fname)
        field_geps  = gep_fields.get(base_name, [])

        is_switch = all(p == "eq" for p, _ in field_comps) and len(field_comps) >= 3
        is_icmp   = bool(field_comps) and not is_switch
        is_danger = bool(field_geps)

        if is_icmp and _is_loop_variable(field_comps):
            excluded.append((fname, "loop variable (symmetric bounds)"))
            continue
        if not field_comps and not is_danger:
            excluded.append((fname, "no comparison and not a GEP sink"))
            continue

        if is_switch:
            bucket = _bucket_for_switch([t for _, t in field_comps])
            arm    = "switch"
        elif is_icmp and is_danger:
            icmp_b = _bucket_for_icmp(field_comps)
            gep_b  = _bucket_for_gep(field_geps)
            if gep_b["bucket_count"] > icmp_b["bucket_count"]:
                bucket = gep_b
                arm    = "icmp+gep_sink(gep_scheme)"
            else:
                bucket = icmp_b
                arm    = "icmp+gep_sink"
        elif is_icmp:
            bucket = _bucket_for_icmp(field_comps)
            arm    = "icmp"
        else:
            bucket = _bucket_for_gep(field_geps)
            arm    = "gep_sink"

        abs_offset, byte_size, llvm_type = offsets.get(fname, (0, 0, "?"))
        hwm = (not is_switch) and (_has_reset_stores(fname, G, main_func) or is_danger)

        selected.append({
            "name":                fname,
            "absolute_byte_offset": abs_offset,
            "byte_size":           byte_size,
            "llvm_type":           llvm_type,
            "selection_arm":       arm,
            "comparisons":         [{"pred": p, "threshold": t} for p, t in field_comps],
            "gep_array_sizes":     field_geps,
            "bucket_scheme":       bucket["scheme"],
            "thresholds":          bucket["thresholds"],
            "bucket_count":        bucket["bucket_count"],
            "high_watermark":      hwm,
            "note":                bucket["note"],
        })

    total = 1
    for f in selected:
        total *= f["bucket_count"]

    shmem = 256
    while shmem < total * 2:
        shmem *= 2
    shmem = min(shmem, 65536)

    return {
        "schema_version":         1,
        "program":                main_func,
        "total_macro_states":     total,
        "recommended_shmem_size": shmem,
        "fields":                 selected,
        "_excluded":              excluded,
    }


def _print_summary(result: dict) -> None:
    tag  = "[state_hash]"
    print(f"{tag} Program            : {result['program']}")
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
        print(f"{tag} Bug may be reachable in a single scan cycle.")
    if result["_excluded"]:
        print()
        print(f"{tag} Excluded fields ({len(result['_excluded'])}):")
        for fname, reason in result["_excluded"]:
            print(f"{tag}   {fname:20s} -- {reason}")


def add_args(sub) -> None:
    sub.add_argument("ddg",    help="<target>_ddg.json")
    sub.add_argument("layout", help="<target>_layout.json")
    sub.add_argument("--json", metavar="OUT", help="Write config JSON to file")


def run(args) -> None:
    ddg    = load_ddg(args.ddg)
    layout = load_layout(args.layout)

    result = analyse(ddg, layout)
    _print_summary(result)

    if args.json:
        out = {k: v for k, v in result.items() if not k.startswith("_")}
        Path(args.json).write_text(json.dumps(out, indent=2))
        print(f"\n[state_hash] Wrote {args.json}")
