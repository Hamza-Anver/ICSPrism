from __future__ import annotations

import json
import sys
from collections import defaultdict, deque
from pathlib import Path

from .io import load_ddg, load_layout


def _probe_schema(ddg: dict, layout: list) -> tuple | tuple[None, None]:
    print("=" * 60)
    print("SCHEMA PROBE")
    print("=" * 60)
    print(f"\nDDG top-level keys: {list(ddg.keys())}")
    nodes = ddg.get("nodes", [])
    if not nodes:
        print("ERROR: No nodes found.")
        return None, None
    print(f"DDG node count: {len(nodes)}")
    print(f"Node fields: {list(nodes[0].keys())}")
    print(f"\nSample node:\n{json.dumps(nodes[0], indent=2)}")
    edges = ddg.get("edges", [])
    print(f"\nDDG edge count: {len(edges)}")
    if edges:
        print(f"Edge fields: {list(edges[0].keys())}")
        print(f"Sample edge:\n{json.dumps(edges[0], indent=2)}")
    else:
        print("WARNING: No edges found — BFS will find nothing")
    print(f"\nLayout is a list of {len(layout)} struct(s)")
    if layout:
        print(f"First struct keys: {list(layout[0].keys())}")
        fields = layout[0].get("fields", [])
        print(f"Field count: {len(fields)}")
        if fields:
            print(f"Field keys: {list(fields[0].keys())}")
            print(f"Sample field:\n{json.dumps(fields[0], indent=2)}")
    return nodes, edges


def _find_sinks(nodes: list) -> tuple[list, bool]:
    print("\n" + "=" * 60)
    print("SINK DETECTION  (has_dynamic_index=True)")
    print("=" * 60)
    sinks = []
    for node in nodes:
        if node.get("has_dynamic_index"):
            sinks.append(node["id"])
            print(f"  sink node {node['id']:4d}: {node.get('defines', '<no defines>')}  |  {node.get('ir', '').strip()}")
    if not sinks:
        print("  WARNING: No dynamic GEP sinks found.")
        print("    - The target has no dynamic array indexing")
        print("    - has_dynamic_index is not being set in ddg.rs")
        fallback = [n["id"] for n in nodes if n.get("opcode") == "GetElementPtr"]
        print(f"\n  Fallback: using all {len(fallback)} GEP nodes as sinks")
        return fallback, True
    print(f"\n  Total sinks: {len(sinks)}")
    return sinks, False


def _find_input_nodes(nodes: list, layout: list) -> list:
    print("\n" + "=" * 60)
    print("INPUT FIELD MAPPING")
    print("=" * 60)
    defines_to_id = {
        node["defines"].lstrip("%"): node["id"]
        for node in nodes if node.get("defines")
    }
    input_nodes = []
    skipped = []
    for struct in layout:
        for field in struct.get("fields", []):
            fname = field["name"]
            struct_name = struct.get("struct_name", "?")
            if fname.startswith("__"):
                skipped.append(f"{struct_name}.{fname}  [internal]")
                continue
            node_id = defines_to_id.get(fname)
            if node_id is None:
                skipped.append(f"{struct_name}.{fname}  [no DDG node]")
                continue
            input_nodes.append({
                "node_id":     node_id,
                "field_name":  fname,
                "struct_name": struct_name,
                "byte_offset": field["byte_offset"],
                "byte_size":   field["byte_size"],
            })
            print(f"  matched: node {node_id:4d}  {struct_name}.{fname}"
                  f"  bytes [{field['byte_offset']}..{field['byte_offset'] + field['byte_size'] - 1}]")
    if skipped:
        print(f"\n  Skipped {len(skipped)} fields:")
        for s in skipped:
            print(f"    {s}")
    if not input_nodes:
        print("\n  ERROR: No input nodes found.")
    return input_nodes


def _build_reverse_graph(edges: list) -> dict:
    print("\n" + "=" * 60)
    print("EDGE ANALYSIS")
    print("=" * 60)
    kind_counts: dict[str, int] = defaultdict(int)
    reverse: dict = defaultdict(list)
    for edge in edges:
        src = edge.get("from") if "from" in edge else edge.get("source")
        dst = edge.get("to")   if "to"   in edge else edge.get("target")
        kind = edge.get("kind", "unknown")
        if src is None or dst is None:
            print(f"  WARNING: edge missing from/to: {edge}")
            continue
        kind_counts[kind] += 1
        reverse[dst].append((src, kind))
    for kind, count in sorted(kind_counts.items()):
        print(f"  edge kind '{kind}': {count}")
    return reverse


def _bfs_from_sinks(sink_ids: list, reverse_graph: dict) -> dict:
    distances: dict = {}
    queue: deque = deque()
    for sink in sink_ids:
        if sink not in distances:
            distances[sink] = 0
            queue.append(sink)
    while queue:
        node = queue.popleft()
        for pred, _ in reverse_graph[node]:
            if pred not in distances:
                distances[pred] = distances[node] + 1
                queue.append(pred)
    return distances


def _compute_byte_scores(input_nodes: list, distances: dict,
                         total_bytes: int) -> tuple[list, list, list]:
    reachable   = [n for n in input_nodes if n["node_id"] in distances]
    unreachable = [n for n in input_nodes if n["node_id"] not in distances]
    scores = [0.0] * total_bytes
    for node in reachable:
        score = 1.0 / (1.0 + distances[node["node_id"]])
        start = node["byte_offset"]
        for b in range(start, min(start + node["byte_size"], total_bytes)):
            scores[b] = max(scores[b], score)
    return scores, reachable, unreachable


def _print_score_table(scores: list, input_nodes: list) -> None:
    print("\n" + "=" * 60)
    print("BYTE SCORE TABLE  (fuzzer weight Vec<f32>)")
    print("=" * 60)
    byte_label = [""] * len(scores)
    byte_dist  = [""] * len(scores)
    for node in input_nodes:
        d = node.get("_dist", "∞")
        for b in range(node["byte_offset"], node["byte_offset"] + node["byte_size"]):
            if b < len(byte_label):
                byte_label[b] = node["field_name"]
                byte_dist[b]  = str(d)
    for i, score in enumerate(scores):
        bar   = "#" * int(score * 30)
        label = byte_label[i] or "?"
        dist  = f"d={byte_dist[i]}" if byte_dist[i] else "n/a"
        print(f"  byte {i:3d} [{label:20s}]  {score:.3f}  {dist:8s}  {bar}")


def _diagnose(sinks: list, is_fallback: bool, input_nodes: list,
              distances: dict, scores: list) -> None:
    print("\n" + "=" * 60)
    print("DIAGNOSIS")
    print("=" * 60)
    reachable   = [n for n in input_nodes if n["node_id"] in distances]
    unreachable = [n for n in input_nodes if n["node_id"] not in distances]
    if is_fallback:
        print("  [WARN] Using fallback sinks (all GEPs) — set has_dynamic_index in ddg.rs")
    else:
        print(f"  [OK]   {len(sinks)} real dynamic GEP sinks found")
    if not input_nodes:
        print("  [FAIL] No input nodes — defines/field name matching is broken")
    else:
        print(f"  [OK]   {len(input_nodes)} input fields mapped to DDG nodes")
    if not reachable:
        print("  [FAIL] 0 input nodes reach any sink — BFS found nothing")
    else:
        print(f"  [OK]   {len(reachable)}/{len(input_nodes)} input fields reach a sink")
        for n in reachable:
            print(f"           {n['field_name']}  distance={distances[n['node_id']]}")
    if unreachable:
        print(f"  [INFO] {len(unreachable)} fields don't reach any sink (score 0.0):")
        for n in unreachable:
            print(f"           {n['field_name']}")
    nonzero = sum(1 for s in scores if s > 0)
    at_floor = sum(1 for s in scores if 0 < s <= 0.1)
    print(f"\n  Score summary: {nonzero}/{len(scores)} bytes have nonzero proximity score")
    if at_floor:
        print(f"  [INFO] {at_floor} bytes at floor (0.1) — equidistant from sinks")
    if nonzero == 0:
        print("  [FAIL] All bytes score 0 — DDG guidance would be useless")
    elif nonzero == len(scores):
        print("  [WARN] All bytes score nonzero — graph may be too densely connected")
    else:
        distinct = len(set(round(s, 3) for s in scores if s > 0))
        if distinct == 1:
            print("  [OK]   All reachable bytes equidistant from sinks")
        else:
            print(f"  [OK]   {distinct} distinct score levels — good gradient")


def add_args(sub) -> None:
    sub.add_argument("ddg",    help="<target>_ddg.json")
    sub.add_argument("layout", help="<target>_layout.json")


def run(args) -> None:
    ddg    = load_ddg(args.ddg)
    layout = load_layout(args.layout)

    nodes, edges = _probe_schema(ddg, layout)
    if nodes is None:
        sys.exit(1)

    sinks, is_fallback = _find_sinks(nodes)
    input_nodes        = _find_input_nodes(nodes, layout)
    reverse_graph      = _build_reverse_graph(edges)
    distances          = _bfs_from_sinks(sinks, reverse_graph)

    all_fields  = [f for s in layout for f in s.get("fields", [])]
    total_bytes = max(
        (f["byte_offset"] + f["byte_size"] for f in all_fields), default=0
    )
    scores, reachable, _ = _compute_byte_scores(input_nodes, distances, total_bytes)

    for n in input_nodes:
        n["_dist"] = distances.get(n["node_id"], "∞")

    _print_score_table(scores, input_nodes)
    _diagnose(sinks, is_fallback, input_nodes, distances, scores)

    print("\n# JSON output:")
    print(json.dumps({
        "total_bytes":           total_bytes,
        "sink_count":            len(sinks),
        "input_field_count":     len(input_nodes),
        "reachable_field_count": len(reachable),
        "scores":                scores,
    }))
