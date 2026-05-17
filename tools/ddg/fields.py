from __future__ import annotations

import re
from collections import deque

import networkx as nx

from .graph import named_field_from_gep, get_constant_array_index, field_key


# ---------------------------------------------------------------------------
# Field resolution
# ---------------------------------------------------------------------------

def resolve_to_field_indexed(start_id: int, G: nx.DiGraph) -> tuple[str, int | None] | None:
    """
    Walk backwards from start_id to find a named struct GEP.
    Returns (field_name, element_index_or_None), or None if not found.
    element_index is set for constant-index array GEPs, None for scalar fields.
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
                fname = named_field_from_gep(pn)
                if fname:
                    return (fname, None)
                if pn.get("opcode") == "GetElementPtr":
                    elem_idx = get_constant_array_index(pn.get("ir", ""))
                    for bp in G.predecessors(pred):
                        bfname = named_field_from_gep(G.nodes[bp])
                        if bfname:
                            return (bfname, elem_idx)
        for pred in G.predecessors(nid):
            if pred not in visited:
                queue.append(pred)
    return None


def resolve_to_field(start_id: int, G: nx.DiGraph) -> str | None:
    r = resolve_to_field_indexed(start_id, G)
    return r[0] if r else None


# ---------------------------------------------------------------------------
# ICmp parsing
# ---------------------------------------------------------------------------

_ICMP_RE = re.compile(
    r"icmp\s+(s?(?:gt|ge|lt|le)|ne|eq)\s+\w+\s+(%-?[\w.]+|-?\d+),\s*(%-?[\w.]+|-?\d+)"
)


def parse_icmp(ir: str) -> tuple[str, str, str] | None:
    """Return (pred, lhs_str, rhs_str) from an ICmp IR string, or None."""
    m = _ICMP_RE.search(ir)
    if not m:
        return None
    return m.group(1), m.group(2), m.group(3)


def unwrap_icmp(icmp_id: int, G: nx.DiGraph) -> int:
    """Follow ZExt/boolean-cast chains to the root comparison node."""
    node = G.nodes[icmp_id]
    parsed = parse_icmp(node.get("ir", ""))
    if not parsed:
        return icmp_id
    pred, lhs, rhs = parsed
    if pred not in ("ne", "eq") or rhs != "0":
        return icmp_id
    for pred_id in G.predecessors(icmp_id):
        pn = G.nodes[pred_id]
        if pn.get("defines", "").lstrip("%") == lhs.lstrip("%"):
            if pn.get("opcode") in ("ZExt", "SExt"):
                for pp_id in G.predecessors(pred_id):
                    if G.nodes[pp_id].get("opcode") == "ICmp":
                        return pp_id
    return icmp_id


def resolve_icmp(icmp_id: int, G: nx.DiGraph) -> tuple[str, str, int] | None:
    """
    Unwrap boolean-cast patterns then resolve the ICmp operand to a field name.
    Returns (field_name, pred, threshold) or None.
    """
    root_id = unwrap_icmp(icmp_id, G)
    node = G.nodes[root_id]
    parsed = parse_icmp(node.get("ir", ""))
    if not parsed:
        return None
    pred, lhs, rhs = parsed

    field: str | None = None
    threshold: int | None = None

    if re.match(r"^-?\d+$", rhs):
        threshold = int(rhs)
        for pred_id in G.predecessors(root_id):
            pn = G.nodes[pred_id]
            if pn.get("defines", "").lstrip("%") == lhs.lstrip("%"):
                field = resolve_to_field(pred_id, G)
                if field:
                    break
        if not field:
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
    return field, pred, threshold


# ---------------------------------------------------------------------------
# Layout utilities
# ---------------------------------------------------------------------------

def parse_struct_ref(llvm_type: str) -> str | None:
    """Return struct name if llvm_type is a named struct reference like '%Foo_t'."""
    t = llvm_type.strip()
    if not t.startswith("%"):
        return None
    end = next((i for i, c in enumerate(t) if c in (" ", "=") and i > 0), len(t))
    inner = t[1:end].strip()
    return inner if inner else None


def _flatten_layout_into(structs_by_name: dict, struct_name: str,
                         base_offset: int, leaves: list, visited: set) -> None:
    if struct_name in visited:
        return
    visited.add(struct_name)
    defn = structs_by_name.get(struct_name)
    if not defn:
        return
    for f in defn.get("fields", []):
        name = f.get("name")
        if not name or name == "__vtable":
            continue
        abs_offset = base_offset + int(f.get("byte_offset", 0))
        byte_size = int(f.get("byte_size", 0))
        nested = parse_struct_ref(f.get("llvm_type", ""))
        if nested and nested in structs_by_name:
            _flatten_layout_into(structs_by_name, nested, abs_offset, leaves, visited)
        else:
            leaves.append({
                "name": name,
                "absolute_byte_offset": abs_offset,
                "byte_size": byte_size,
                "llvm_type": f.get("llvm_type", ""),
            })


def find_field_offset(layout_structs: list, field_name: str,
                      top_struct_name: str) -> tuple[int, int] | None:
    """Return (absolute_byte_offset, byte_size) for field_name in top_struct_name."""
    by_name = {s["struct_name"]: s for s in layout_structs}
    leaves: list[dict] = []
    _flatten_layout_into(by_name, top_struct_name, 0, leaves, set())
    for leaf in leaves:
        if leaf["name"] == field_name:
            return leaf["absolute_byte_offset"], leaf["byte_size"]
    return None


def compute_absolute_offsets(main_func: str, layout: list) -> dict[str, tuple[int, int, str]]:
    """
    Returns {field_key: (absolute_byte_offset, byte_size, llvm_type)}.
    Also emits per-element entries for array fields (e.g. "Buffer[0]", "Buffer[1]").
    """
    main_layout = next((l for l in layout if l["struct_name"] == main_func), None)
    if not main_layout:
        return {}

    base_offset = 0
    for struct in layout:
        if struct["struct_name"] == main_func:
            continue
        for f in struct.get("fields", []):
            lt = f.get("llvm_type", "")
            if main_func in lt and lt.startswith("%"):
                base_offset = f["byte_offset"]
                break

    result: dict[str, tuple[int, int, str]] = {}
    for f in main_layout.get("fields", []):
        name = f.get("name")
        if not name or name == "__vtable":
            continue
        abs_offset = base_offset + f["byte_offset"]
        size = f["byte_size"]
        ltype = f["llvm_type"]
        result[name] = (abs_offset, size, ltype)
        arr_m = re.match(r"\[(\d+)\s+x\s+(\w+)\]", ltype)
        if arr_m:
            arr_len = int(arr_m.group(1))
            elem_type = arr_m.group(2)
            elem_size = size // arr_len if arr_len else size
            for i in range(arr_len):
                result[field_key(name, i)] = (abs_offset + i * elem_size, elem_size, elem_type)

    return result
