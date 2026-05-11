#!/usr/bin/env python3
"""
DDG proximity probe — validates that the DDG + layout JSONs contain
enough information to compute per-byte sink-proximity scores.

Usage:
    python3 probe_ddg.py <target>_ddg.json <target>_layout.json

What it checks:
  1. Schema shape   — are the keys we expect actually present?
  2. Sink detection — which nodes have has_dynamic_index=true?
  3. Input mapping  — which layout fields map to DDG nodes?
  4. Edge schema    — what does an edge look like?
  5. BFS reachability — do input nodes actually reach sinks?
  6. Byte scores    — final per-byte weight table (the fuzzer output)
"""

import json
import sys
from collections import defaultdict, deque


# ---------------------------------------------------------------------------
# 1. Load
# ---------------------------------------------------------------------------

def load(ddg_path, layout_path):
    with open(ddg_path) as f:
        ddg = json.load(f)
    with open(layout_path) as f:
        layout = json.load(f)
    return ddg, layout


# ---------------------------------------------------------------------------
# 2. Schema probe — print what we actually see before assuming anything
# ---------------------------------------------------------------------------

def probe_schema(ddg, layout):
    print("=" * 60)
    print("SCHEMA PROBE")
    print("=" * 60)

    # DDG top-level keys
    print(f"\nDDG top-level keys: {list(ddg.keys())}")

    # Node field names (from first node)
    nodes = ddg.get("nodes", ddg if isinstance(ddg, list) else [])
    if not nodes:
        print("ERROR: No nodes found. Is the DDG a list or {'nodes': [...]}?")
        return None, None

    print(f"DDG node count: {len(nodes)}")
    print(f"Node fields: {list(nodes[0].keys())}")
    print(f"\nSample node:\n{json.dumps(nodes[0], indent=2)}")

    # Edge field names
    edges = ddg.get("edges", [])
    print(f"\nDDG edge count: {len(edges)}")
    if edges:
        print(f"Edge fields: {list(edges[0].keys())}")
        print(f"Sample edge:\n{json.dumps(edges[0], indent=2)}")
    else:
        print("WARNING: No edges found — BFS will find nothing")

    # Layout shape — it's a list of structs, each with fields
    if isinstance(layout, list):
        print(f"\nLayout is a list of {len(layout)} struct(s)")
        if layout:
            print(f"First struct keys: {list(layout[0].keys())}")
            fields = layout[0].get("fields", [])
            print(f"Field count: {len(fields)}")
            if fields:
                print(f"Field keys: {list(fields[0].keys())}")
                print(f"Sample field:\n{json.dumps(fields[0], indent=2)}")
    else:
        print(f"\nLayout top-level keys: {list(layout.keys())}")

    return nodes, edges


# ---------------------------------------------------------------------------
# 3. Sink detection
# ---------------------------------------------------------------------------

def find_sinks(nodes):
    """
    Nodes with has_dynamic_index=True are dynamic GEP sinks —
    array accesses where the index is not a compile-time constant.
    These are the vulnerability targets (OOB read/write candidates).
    """
    print("\n" + "=" * 60)
    print("SINK DETECTION  (has_dynamic_index=True)")
    print("=" * 60)

    sinks = []
    for node in nodes:
        if node.get("has_dynamic_index"):
            sinks.append(node["id"])
            print(f"  sink node {node['id']:4d}: {node.get('defines','<no defines>')}  |  {node.get('ir','').strip()}")

    if not sinks:
        print("  WARNING: No dynamic GEP sinks found.")
        print("  Possible reasons:")
        print("    - The target has no dynamic array indexing")
        print("    - has_dynamic_index is not being set in ddg.rs")
        print("    - Try a benchmark like month_to_string or an array OOB target")

        # Fallback: treat ALL GEPs as sinks so we can still test the pipeline
        fallback = [n["id"] for n in nodes if n.get("opcode") == "GetElementPtr"]
        print(f"\n  Fallback: using all {len(fallback)} GEP nodes as sinks for pipeline test")
        return fallback, True

    print(f"\n  Total sinks: {len(sinks)}")
    return sinks, False


# ---------------------------------------------------------------------------
# 4. Input field mapping
# ---------------------------------------------------------------------------

def find_input_nodes(nodes, layout):
    """
    Map layout fields to DDG nodes.

    The DDG node's `defines` field is the SSA name e.g. "%Increment".
    The layout field's `name` is the source name e.g. "Increment".
    They match after stripping the leading %.

    The layout has no is_input flag — we exclude known internal fields:
      __vtable  (vtable pointer, not a user input)
    and any field whose name starts with __ (compiler-generated).

    Everything else is treated as a potential input field.
    """
    print("\n" + "=" * 60)
    print("INPUT FIELD MAPPING")
    print("=" * 60)

    # Build lookup: source_name -> DDG node id
    defines_to_id = {}
    for node in nodes:
        defines = node.get("defines")
        if defines:
            # Strip leading % to get source name
            source_name = defines.lstrip("%")
            defines_to_id[source_name] = node["id"]

    # Collect all fields from all structs in the layout
    all_fields = []
    layout_list = layout if isinstance(layout, list) else [layout]
    for struct in layout_list:
        for field in struct.get("fields", []):
            all_fields.append((struct.get("struct_name", "?"), field))

    # Filter and match
    input_nodes = []   # list of (node_id, field_name, byte_offset, byte_size)
    skipped = []

    INTERNAL_PREFIXES = ("__",)

    for struct_name, field in all_fields:
        fname = field["name"]

        # Skip compiler-internal fields
        if any(fname.startswith(p) for p in INTERNAL_PREFIXES):
            skipped.append(f"{struct_name}.{fname}  [internal]")
            continue

        node_id = defines_to_id.get(fname)
        if node_id is None:
            # Try with the struct GEP name pattern e.g. "%Increment" in Counter
            skipped.append(f"{struct_name}.{fname}  [no DDG node found — defines_to_id miss]")
            continue

        input_nodes.append({
            "node_id": node_id,
            "field_name": fname,
            "struct_name": struct_name,
            "byte_offset": field["byte_offset"],
            "byte_size": field["byte_size"],
        })
        print(f"  matched: node {node_id:4d}  {struct_name}.{fname}"
              f"  bytes [{field['byte_offset']}..{field['byte_offset']+field['byte_size']-1}]")

    if skipped:
        print(f"\n  Skipped {len(skipped)} fields:")
        for s in skipped:
            print(f"    {s}")

    if not input_nodes:
        print("\n  ERROR: No input nodes found.")
        print("  The defines name in DDG nodes must match layout field names after stripping %.")
        print("  Check that ddg.rs stores the field name (not the SSA temp name) in `defines`.")

    return input_nodes


# ---------------------------------------------------------------------------
# 5. BFS — backwards from sinks through def-use edges
# ---------------------------------------------------------------------------

def build_reverse_graph(edges):
    """
    Reverse adjacency list: for each node, who are its predecessors?

    We expect edges like {"from": X, "to": Y, "kind": "..."}.
    A def-use edge means X defines a value that Y uses.
    Walking backwards from a sink finds what flows into it.

    Edge kinds to include in BFS — adjust if your schema differs:
      def_use, store_load, memory  -> yes (data flow)
      store_store, overwrite       -> maybe (conservative: include)
      call                         -> yes (tracks callee influence)
    """
    print("\n" + "=" * 60)
    print("EDGE ANALYSIS")
    print("=" * 60)

    kind_counts = defaultdict(int)
    reverse = defaultdict(list)

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


def bfs_from_sinks(sink_ids, reverse_graph):
    """
    BFS backwards from sinks.
    Returns dict: node_id -> minimum hop count to nearest sink.
    Nodes not reachable from any sink are absent from the dict.
    """
    distances = {}
    queue = deque()

    for sink in sink_ids:
        if sink not in distances:
            distances[sink] = 0
            queue.append(sink)

    while queue:
        node = queue.popleft()
        for (pred, kind) in reverse_graph[node]:
            if pred not in distances:
                distances[pred] = distances[node] + 1
                queue.append(pred)

    return distances


# ---------------------------------------------------------------------------
# 6. Byte score table
# ---------------------------------------------------------------------------

def compute_byte_scores(input_nodes, distances, total_input_bytes):
    """
    Produce a Vec<f32>-equivalent: one score per input byte.
    Score = 1.0 - normalized_distance.
    Bytes not connected to any sink get score 0.0 (still mutated,
    just deprioritised — the fuzzer should never fully ignore a byte).

    Key insight: distances keys are integers (node IDs from JSON).
    input_nodes[i]["node_id"] must also be int. If JSON parsed node
    IDs as strings somewhere this lookup silently fails.
    """
    reachable = [n for n in input_nodes if n["node_id"] in distances]
    unreachable = [n for n in input_nodes if n["node_id"] not in distances]

    scores = [0.0] * total_input_bytes

    if not reachable:
        return scores, reachable, unreachable

    # Scoring strategy: inverse-distance weighting — 1 / (1 + d)
    #
    # WHY NOT linear normalization (1 - d/max_d):
    #   In a straight-line chain  input→load→sext→mul→add→SINK (5 hops),
    #   every input is at distance 5 = max_d, so linear gives 0.0 for all.
    #   That's exactly what happened with array_lookup: index and selector
    #   both at distance 5, max_dist=5, score=0.0.
    #
    # Inverse-distance never hits zero for reachable nodes:
    #   distance 0 (is a sink)  → 1.0
    #   distance 1              → 0.5
    #   distance 5              → 0.167
    #   distance 10             → 0.091
    #   unreachable             → 0.0   (explicitly set, not computed)
    #
    # Fields that don't reach any sink stay at 0.0 so the mutator still
    # deprioritises them — but not to the point of ignoring reachable ones.

    for node in reachable:
        d = distances[node["node_id"]]
        score = 1.0 / (1.0 + d)
        start = node["byte_offset"]
        end = start + node["byte_size"]
        for b in range(start, min(end, total_input_bytes)):
            scores[b] = max(scores[b], score)

    return scores, reachable, unreachable


def print_score_table(scores, input_nodes):
    print("\n" + "=" * 60)
    print("BYTE SCORE TABLE  (this becomes the fuzzer weight Vec<f32>)")
    print("=" * 60)

    # Build label and distance-per-byte lookups
    byte_label = [""] * len(scores)
    byte_dist  = [""] * len(scores)
    for node in input_nodes:
        d = node.get("_dist", "∞")
        for b in range(node["byte_offset"],
                       node["byte_offset"] + node["byte_size"]):
            if b < len(byte_label):
                byte_label[b] = node["field_name"]
                byte_dist[b]  = str(d)

    for i, score in enumerate(scores):
        bar   = "#" * int(score * 30)
        label = byte_label[i] if byte_label[i] else "?"
        dist  = f"d={byte_dist[i]}" if byte_dist[i] else "n/a"
        print(f"  byte {i:3d} [{label:20s}]  {score:.3f}  {dist:8s}  {bar}")



# ---------------------------------------------------------------------------
# 7. Diagnosis summary
# ---------------------------------------------------------------------------

def diagnose(sinks, is_fallback, input_nodes, distances, scores):
    print("\n" + "=" * 60)
    print("DIAGNOSIS")
    print("=" * 60)

    reachable = [n for n in input_nodes if n["node_id"] in distances]
    unreachable = [n for n in input_nodes if n["node_id"] not in distances]

    if is_fallback:
        print("  [WARN] Using fallback sinks (all GEPs) — set has_dynamic_index in ddg.rs")
    else:
        print(f"  [OK]   {len(sinks)} real dynamic GEP sinks found")

    if not input_nodes:
        print("  [FAIL] No input nodes — defines/field name matching is broken")
        print("         Fix: check that DDG nodes for struct fields use the field")
        print("         name (e.g. '%Increment') not a temp SSA name")
    else:
        print(f"  [OK]   {len(input_nodes)} input fields mapped to DDG nodes")

    if not reachable:
        print("  [FAIL] 0 input nodes reach any sink — BFS found nothing")
        print("         Fix options:")
        print("           a) Check edge direction: 'from' should be definer, 'to' should be user")
        print("           b) Check that store->load edges are included (memory flow)")
        print("           c) Try a target with known dynamic array indexing")
    else:
        print(f"  [OK]   {len(reachable)}/{len(input_nodes)} input fields reach a sink")
        for n in reachable:
            print(f"           {n['field_name']}  distance={distances[n['node_id']]}")

    if unreachable:
        print(f"  [INFO] {len(unreachable)} fields don't reach any sink (will score 0.0):")
        for n in unreachable:
            print(f"           {n['field_name']}")

    nonzero = sum(1 for s in scores if s > 0)
    at_floor = sum(1 for s in scores if 0 < s <= 0.1)
    print(f"\n  Score summary: {nonzero}/{len(scores)} bytes have nonzero proximity score")
    if at_floor:
        print(f"  [INFO] {at_floor} bytes are at the minimum floor (0.1) — inputs equidistant from sinks")
        print(f"         This is correct: they all reach a sink but the graph has no depth gradient.")
        print(f"         The fuzzer will still prefer these bytes over unreachable ones (score=0.0).")

    if nonzero == 0:
        print("  [FAIL] All bytes score 0 — DDG guidance would be useless")
        print("         Check: are sinks found? Do input nodes connect to sinks via BFS?")
    elif nonzero == len(scores):
        print("  [WARN] All bytes score nonzero — graph may be too densely connected")
        print("         Every byte influences every sink. DDG guidance will be weak.")
    else:
        distinct = len(set(round(s, 3) for s in scores if s > 0))
        if distinct == 1:
            print("  [OK]   All reachable bytes have the same score (equidistant from sinks).")
            print("         DDG still adds value: reachable bytes (score>0) vs unreachable (score=0).")
            print("         Richer gradients appear when the target has multi-hop data flow paths.")
        else:
            print(f"  [OK]   {distinct} distinct score levels — good gradient for biased mutation")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <target>_ddg.json <target>_layout.json")
        sys.exit(1)

    ddg, layout = load(sys.argv[1], sys.argv[2])

    nodes, edges = probe_schema(ddg, layout)
    if nodes is None:
        sys.exit(1)

    sinks, is_fallback = find_sinks(nodes)
    input_nodes = find_input_nodes(nodes, layout)
    reverse_graph = build_reverse_graph(edges)
    distances = bfs_from_sinks(sinks, reverse_graph)
    
    # Total input bytes = max byte_offset + byte_size across all input fields
    layout_list = layout if isinstance(layout, list) else [layout]
    all_fields = [f for s in layout_list for f in s.get("fields", [])]
    total_bytes = max(
        (f["byte_offset"] + f["byte_size"] for f in all_fields),
        default=0
    )

    scores, reachable, unreachable = compute_byte_scores(
        input_nodes, distances, total_bytes
    )

    # Annotate input_nodes with their distances for the score table
    for n in input_nodes:
        n["_dist"] = distances.get(n["node_id"], "∞")

    print_score_table(scores, input_nodes)
    diagnose(sinks, is_fallback, input_nodes, distances, scores)

    # Machine-readable output for piping into tests
    print("\n# JSON output for automated consumption:")
    print(json.dumps({
        "total_bytes": total_bytes,
        "sink_count": len(sinks),
        "input_field_count": len(input_nodes),
        "reachable_field_count": len(reachable),
        "scores": scores,
    }))