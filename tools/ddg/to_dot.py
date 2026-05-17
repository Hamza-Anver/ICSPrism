from __future__ import annotations

from pathlib import Path

from .io import load_ddg


def _dot_escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def _node_label(node: dict) -> str:
    display = node.get("human_name") or node.get("defines") or ""
    tag = " [dyn-idx]" if node.get("has_dynamic_index") else ""
    return f"{node.get('id', '')}\\n{node.get('opcode', '')}\\n{display}{tag}"


def graph_to_dot(ddg: dict) -> str:
    lines = ["digraph DDG {", "  rankdir=LR;", "  node [shape=box fontsize=9];"]
    for node in ddg.get("nodes", []):
        if not isinstance(node, dict):
            continue
        label = _dot_escape(_node_label(node))
        lines.append(f"  n{node.get('id')} [label=\"{label}\"];")
    for edge in ddg.get("edges", []):
        if not isinstance(edge, dict):
            continue
        style = ""
        if edge.get("kind") == "data_memory":
            style = " style=dashed"
        elif edge.get("kind") == "memory_overwrite":
            style = " style=dotted color=red"
        label = _dot_escape(str(edge.get("kind", "")))
        lines.append(f"  n{edge.get('from')} -> n{edge.get('to')} [label=\"{label}\"{style}];")
    lines.append("}")
    return "\n".join(lines) + "\n"


def add_args(sub) -> None:
    sub.add_argument("ddg", type=Path, help="<target>_ddg.json")
    sub.add_argument("dot", nargs="?", type=Path, help="Output .dot path")


def run(args) -> None:
    ddg = load_ddg(args.ddg)
    out = args.dot if args.dot is not None else args.ddg.with_suffix(".dot")
    out.write_text(graph_to_dot(ddg), encoding="utf-8")
    print(f"[to-dot] Wrote {out}")
