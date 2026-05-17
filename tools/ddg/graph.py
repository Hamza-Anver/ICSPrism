from __future__ import annotations

import re
from collections import defaultdict

import networkx as nx


_SKIP_GEP_NAMES = {"this", "self", "deref"}


def build_graph(ddg: dict) -> nx.DiGraph:
    G = nx.DiGraph()
    for n in ddg["nodes"]:
        G.add_node(n["id"], **n)
    for e in ddg["edges"]:
        G.add_edge(e["from"], e["to"], kind=e.get("kind", ""), symbol=e.get("symbol", ""))
    return G


def named_field_from_gep(node: dict) -> str | None:
    """Return field name if this is a named struct GEP, else None."""
    if node.get("opcode") != "GetElementPtr":
        return None
    defines = node.get("defines", "")
    if not defines:
        return None
    name = defines.lstrip("%")
    if not name or name[0].isdigit() or name.startswith("tmpVar") or name.startswith("__"):
        return None
    if name in _SKIP_GEP_NAMES:
        return None
    return name


def get_constant_array_index(gep_ir: str) -> int | None:
    """Extract constant element index from a constant-index array GEP IR string."""
    m = re.search(
        r"getelementptr\b[^%\[]*\[\d+\s+x\s+\w+\],\s*ptr\s+\S+,\s*i\d+\s+\d+,\s*i\d+\s+(-?\d+)",
        gep_ir,
    )
    return int(m.group(1)) if m else None


def field_key(fname: str, idx: int | None) -> str:
    return f"{fname}[{idx}]" if idx is not None else fname


def find_main_func(G: nx.DiGraph) -> str:
    """Return the function name with the most nodes."""
    counts: dict[str, int] = defaultdict(int)
    for _, data in G.nodes(data=True):
        counts[data.get("function", "")] += 1
    return max(counts, key=counts.__getitem__)
