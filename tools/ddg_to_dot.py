#!/usr/bin/env python3
"""Render an ICSPrism DDG JSON file to GraphViz DOT.

Usage:
    python3 tools/ddg_to_dot.py <target>_ddg.json [<target>_ddg.dot]

The renderer matches the old Rust output:
- node labels use id, opcode, and human_name/defines
- dynamic GEP nodes get a [dyn-idx] tag
- data_memory edges are dashed
- memory_overwrite edges are dotted red
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def dot_escape(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def load_ddg(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("DDG JSON must be an object with nodes and edges")
    return data


def node_display(node: dict[str, Any]) -> str:
    display = node.get("human_name") or node.get("defines") or ""
    tag = " [dyn-idx]" if node.get("has_dynamic_index") else ""
    return f"{node.get('id', '')}\\n{node.get('opcode', '')}\\n{display}{tag}"


def graph_to_dot(ddg: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append("digraph DDG {")
    lines.append("  rankdir=LR;")
    lines.append("  node [shape=box fontsize=9];")

    for node in ddg.get("nodes", []):
        if not isinstance(node, dict):
            continue
        label = dot_escape(node_display(node))
        lines.append(f"  n{node.get('id')} [label=\"{label}\"];")

    for edge in ddg.get("edges", []):
        if not isinstance(edge, dict):
            continue
        style = ""
        if edge.get("kind") == "data_memory":
            style = " style=dashed"
        elif edge.get("kind") == "memory_overwrite":
            style = " style=dotted color=red"
        label = dot_escape(str(edge.get("kind", "")))
        lines.append(
            f"  n{edge.get('from')} -> n{edge.get('to')} [label=\"{label}\"{style}];"
        )

    lines.append("}")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Render ICSPrism DDG JSON as GraphViz DOT")
    parser.add_argument("ddg", type=Path, help="<target>_ddg.json")
    parser.add_argument("dot", nargs="?", type=Path, help="Output .dot path")
    args = parser.parse_args()

    ddg = load_ddg(args.ddg)
    out_path = args.dot if args.dot is not None else args.ddg.with_suffix(".dot")
    out_path.write_text(graph_to_dot(ddg), encoding="utf-8")
    print(f"[ddg_to_dot] Wrote {out_path}")


if __name__ == "__main__":
    main()
