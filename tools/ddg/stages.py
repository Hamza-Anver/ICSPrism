"""
ddg stages — extract Hierarchical Discriminant Sequence (HDS) progress stages
from a compiled ST program's analysis artifacts, for use with prism-go-explore-progress.

A progress stage captures an intermediate accumulating variable (e.g. PrimeScore, FluxScore)
whose high-watermark provides Go-Explore checkpoint signal before the primary discriminant
(e.g. FillHead) starts moving.  This closes the "cold-start gap" in multi-phase programs
where a long prerequisite path must be navigated before the bug-triggering phase begins.

Usage:
  python -m ddg stages <heuristics_json> <layout_json> \\
      [--ddg <ddg_json>] [--weights <weights_json>] [--output <out_json>]

  # Or provide stages manually (skip auto-detection):
  python -m ddg stages <heuristics_json> <layout_json> \\
      --stages-json <manually_authored_stages.json> [--output <out_json>]
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from .fields import find_field_offset
from .io import load_json, load_layout


# ---------------------------------------------------------------------------
# Auto-detection from state-hash heuristics + DDG
# ---------------------------------------------------------------------------

def _find_phase_field(heuristics: dict) -> dict | None:
    """
    Return the state-machine field from the heuristics (identity-bucket, non-hwm).
    For pipeline_controller this is 'Phase'; for pump_controller it's 'Mode'.
    """
    candidates = [
        f for f in heuristics.get("fields", [])
        if f.get("bucket_scheme") == "identity" and not f.get("high_watermark", True)
    ]
    if not candidates:
        return None
    # If multiple, prefer the one with the most thresholds (richest state machine).
    return max(candidates, key=lambda f: len(f.get("thresholds", [])))


def _find_phase_transitions_from_ddg(ddg: dict, phase_field_name: str) -> list[dict]:
    """
    Walk the DDG to find Phase-Store nodes and their ICmp guards.

    Pattern:
        GEP(Phase) → Store(constant_value)   ← phase transition store
        Br → ICmp(progress_field, pred, threshold)  ← guard before the store

    Returns list of:
        {"to_phase": int, "guard_field": str, "guard_pred": str, "guard_threshold": int}
    """
    try:
        from .graph import build_graph
        from .fields import resolve_icmp
    except ImportError:
        return []

    G = build_graph(ddg)
    nodes_list = ddg.get("nodes", [])

    # GEP nodes that define the Phase field.
    phase_gep_ids = {
        n["id"] for n in nodes_list
        if n.get("opcode") == "GetElementPtr"
        and n.get("defines", "").lstrip("%") == phase_field_name
    }

    results = []
    seen: set[tuple] = set()

    for gep_id in phase_gep_ids:
        for store_id in G.successors(gep_id):
            node = G.nodes[store_id]
            if node.get("opcode") != "Store":
                continue
            # Store must write a constant (new phase value).
            m = re.search(r"store\s+\w+\s+(-?\d+),", node.get("ir", ""))
            if not m:
                continue
            to_phase = int(m.group(1))
            store_bb = node.get("basic_block", "")
            if not store_bb:
                continue

            # Find Br nodes whose target label is this BB.
            for br_id, br_data in G.nodes(data=True):
                if br_data.get("opcode") != "Br":
                    continue
                if store_bb not in br_data.get("ir", ""):
                    continue
                # Find ICmp predecessors of the Br.
                for icmp_id in G.predecessors(br_id):
                    if G.nodes[icmp_id].get("opcode") != "ICmp":
                        continue
                    resolved = resolve_icmp(icmp_id, G)
                    if not resolved:
                        continue
                    field, pred, threshold = resolved
                    # Exclude self-comparisons on Phase and obvious loop variables.
                    if field == phase_field_name:
                        continue
                    key = (to_phase, field, pred, threshold)
                    if key in seen:
                        continue
                    seen.add(key)
                    results.append({
                        "to_phase":        to_phase,
                        "guard_field":     field,
                        "guard_pred":      pred,
                        "guard_threshold": threshold,
                    })

    return results


def _hwm_field_by_name(heuristics: dict, name: str) -> dict | None:
    for f in heuristics.get("fields", []):
        if f.get("name") == name and f.get("high_watermark"):
            return f
    return None


def _derive_exit_threshold(pred: str, threshold: int) -> int:
    """Convert (sge/sgt, threshold) to the minimum value that satisfies the condition."""
    if pred == "sge":
        return threshold
    if pred == "sgt":
        return threshold + 1
    return threshold


def _field_input_ranges(weights: dict, layout_structs: list, top_struct: str) -> dict[str, dict]:
    """
    Derive flat [lo, hi] burst constraints from all input-field ICmp comparisons.
    Used as a reasonable default for stage burst_field_constraints.
    """
    ranges: dict[str, dict] = {}
    for inf in weights.get("input_fields", []):
        name  = inf.get("name", "")
        comps = inf.get("comparisons", [])
        lo, hi = None, None
        for c in comps:
            p, t = c.get("pred", ""), c.get("threshold", 0)
            if p in ("sge", "uge"):
                lo = max(lo, t) if lo is not None else t
            elif p in ("sgt", "ugt"):
                lo = max(lo, t + 1) if lo is not None else t + 1
            elif p in ("sle", "ule"):
                hi = min(hi, t) if hi is not None else t
            elif p in ("slt", "ult"):
                hi = min(hi, t - 1) if hi is not None else t - 1
        if lo is not None and hi is not None and lo < hi:
            ranges[name] = {"lo": lo, "hi": hi}
    return ranges


def _auto_extract(
    heuristics: dict,
    layout_structs: list,
    top_struct: str,
    ddg: dict | None,
    weights: dict | None,
) -> list[dict]:
    """
    Try to auto-extract progress stages.  Returns an empty list when extraction
    fails — caller should fall back to --stages-json.
    """
    phase_field = _find_phase_field(heuristics)
    if phase_field is None:
        print("[stages] No state-machine field found in heuristics (identity-bucket, non-hwm).",
              file=sys.stderr)
        print("[stages] Use --stages-json to provide stages manually.", file=sys.stderr)
        return []

    phase_name = phase_field["name"]
    phase_thresholds = sorted(phase_field.get("thresholds", []))
    if len(phase_thresholds) < 2:
        print(f"[stages] Phase field '{phase_name}' has < 2 states; no intermediate stages.",
              file=sys.stderr)
        return []

    final_phase = phase_thresholds[-1]
    print(f"[stages] Phase field: '{phase_name}' — values={phase_thresholds}, final={final_phase}")

    # Find phase transition guards from DDG.
    transitions: list[dict] = []
    if ddg is not None:
        transitions = _find_phase_transitions_from_ddg(ddg, phase_name)
        if transitions:
            print(f"[stages] Found {len(transitions)} phase transition guard(s) from DDG.")
        else:
            print("[stages] DDG analysis found no phase transition guards.", file=sys.stderr)

    # For each non-final phase, build a stage if we can identify its progress variable.
    global_ranges = _field_input_ranges(weights or {}, layout_structs, top_struct)
    input_names = {f.get("name", "") for f in (weights or {}).get("input_fields", [])}

    stages: list[dict] = []
    used_guards: set[str] = set()

    # Also collect the primary discriminant name so we never use it as a stage disc.
    # The primary disc is the field that gates the abort in the final phase.
    primary_disc_name: str = ""
    if weights:
        ab = weights.get("abort_targets", [])
        if ab and ab[0].get("resolved"):
            primary_disc_name = ab[0]["resolved"].get("field", "")

    # Skip the lowest phase value (typically IDLE = 0): it is trivially exited by
    # a command input, not an accumulating state, so a checkpoint there is useless.
    phases_to_process = phase_thresholds[1:-1]   # drop first (IDLE) and last (target)

    for phase_val in phases_to_process:
        to_next = phase_val + 1               # assume linear phase sequence

        # Find the guard that fires when transitioning to to_next.
        guard_for_this_phase = [
            t for t in transitions
            if t["to_phase"] == to_next
            and t["guard_field"] not in input_names
            and t["guard_field"] not in used_guards
            and t["guard_field"] != primary_disc_name   # never use primary disc as stage disc
            and t["guard_pred"] in ("sge", "sgt")
        ]

        if not guard_for_this_phase:
            print(f"[stages] Phase {phase_val}: no accumulation guard found — skipping.",
                  file=sys.stderr)
            continue

        # Use the guard with the smallest positive threshold as the exit condition.
        g = min(guard_for_this_phase, key=lambda t: t["guard_threshold"])
        disc_name   = g["guard_field"]
        exit_value  = _derive_exit_threshold(g["guard_pred"], g["guard_threshold"])
        max_value   = exit_value - 1   # highest value reachable without completing the phase

        if max_value < 0:
            print(f"[stages] Phase {phase_val}: derived max_value < 0 — skipping.", file=sys.stderr)
            continue

        loc = find_field_offset(layout_structs, disc_name, top_struct)
        if loc is None:
            print(f"[stages] Field '{disc_name}' not found in layout — skipping.", file=sys.stderr)
            continue
        disc_offset, disc_size = loc

        phase_gate_offset = phase_field["absolute_byte_offset"]
        phase_gate_size   = phase_field["byte_size"]

        # Verify the discriminant is a high-watermark field in heuristics.
        hwm = _hwm_field_by_name(heuristics, disc_name)
        if hwm is None:
            print(f"[stages] '{disc_name}' is not a high-watermark field — using it anyway.",
                  file=sys.stderr)

        used_guards.add(disc_name)
        stages.append({
            "stage":                  phase_val,      # 0-based index matching phase value
            "name":                   f"phase{phase_val}_{disc_name.lower()}",
            "discriminant_field":     disc_name,
            "discriminant_offset":    disc_offset,
            "discriminant_size":      disc_size,
            "max_value":              max_value,
            "gate_field":             phase_name,
            "gate_offset":            phase_gate_offset,
            "gate_size":              phase_gate_size,
            "gate_eq_value":          phase_val,
            "burst_field_constraints": global_ranges,
        })
        print(f"[stages] Stage {phase_val}: gate={phase_name}=={phase_val}, "
              f"disc={disc_name} (offset={disc_offset}, size={disc_size}), "
              f"max_value={max_value}")

    return stages


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def add_args(sub) -> None:
    sub.add_argument("heuristics_json", help="<name>_harness_heuristics.json")
    sub.add_argument("layout_json",     help="<name>_layout.json")
    sub.add_argument("--ddg",           metavar="JSON",
                     help="<name>_ddg.json — enables DDG-based phase transition analysis")
    sub.add_argument("--weights",       metavar="JSON",
                     help="<name>_weights.json — provides global input field ranges")
    sub.add_argument("--stages-json",   metavar="JSON",
                     help="Manually authored stages JSON — skips auto-detection entirely")
    sub.add_argument("--output", "-o",  metavar="JSON",
                     help="Output path (default: <heuristics_name>_stages.json)")


def run(args) -> None:
    heuristics_path = Path(args.heuristics_json)
    layout_path     = Path(args.layout_json)

    heuristics     = load_json(heuristics_path)
    layout_structs = load_layout(layout_path)
    top_struct     = layout_structs[-1]["struct_name"] if layout_structs else ""

    # -----------------------------------------------------------------------
    # Stage source: manual override or auto-detection.
    # -----------------------------------------------------------------------
    if getattr(args, "stages_json", None):
        print(f"[stages] Loading stages from {args.stages_json}")
        stages = load_json(args.stages_json)
        if isinstance(stages, dict):
            stages = stages.get("progress_stages", [])
    else:
        ddg     = load_json(args.ddg)     if getattr(args, "ddg", None)     else None
        weights = load_json(args.weights) if getattr(args, "weights", None) else None
        stages  = _auto_extract(heuristics, layout_structs, top_struct, ddg, weights)

    if not stages:
        print("[stages] No progress stages produced.  Output will have an empty stages array.")
        print("[stages] For multi-phase programs, provide --stages-json or --ddg + --weights.")

    # -----------------------------------------------------------------------
    # Output
    # -----------------------------------------------------------------------
    if args.output:
        output_path = Path(args.output)
    else:
        stem = heuristics_path.stem
        if stem.endswith("_harness_heuristics"):
            stem = stem[:-len("_harness_heuristics")]
        output_path = heuristics_path.parent / f"{stem}_stages.json"

    doc = {"progress_stages": stages}
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(doc, indent=2) + "\n")
    print(f"[stages] Written {len(stages)} stage(s) to {output_path}")
