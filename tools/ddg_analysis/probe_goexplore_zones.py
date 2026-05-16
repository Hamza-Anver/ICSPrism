#!/usr/bin/env python3
"""
probe_goexplore_zones.py — auto-generate zone_constraints.json for prism-go-explore.

Usage:
    python3 tools/ddg_analysis/probe_goexplore_zones.py \
        <name>_weights.json <name>_layout.json \
        [--output <name>_zone_constraints.json] \
        [--zones N]

What it does:
  1. Reads the abort target from weights JSON to identify the discriminant field
     (e.g. "FillHead") and its threshold (e.g. 63 = max_fillhead).
  2. Flattens the layout JSON to find the discriminant field's absolute byte offset.
  3. Divides [0, max_fillhead] into N equal zones.
  4. For each input field in the weights JSON, derives a per-zone [lo, hi] constraint
     from its comparison thresholds, tightening progressively at higher zones.
  5. Emits a zone_constraints.json compatible with the generic prism-go-explore schema.

The emitted file can be used as-is or refined by hand. Running this tool once
replaces the only previously manual step in the go-explore pipeline.
"""

import argparse
import json
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Layout flattening: walk nested struct definitions to find absolute byte offsets
# ---------------------------------------------------------------------------

def _flatten_layout(structs_by_name: dict, struct_name: str,
                    base_offset: int, leaves: list, visited: set) -> None:
    """
    Recursively walk `struct_name`, accumulating (name, absolute_offset, byte_size)
    tuples into `leaves`.  Mirrors flatten_state_from_layout in prism-runtime/src/lib.rs.
    """
    if struct_name in visited:
        return
    visited.add(struct_name)
    defn = structs_by_name.get(struct_name)
    if not defn:
        return
    for field in defn.get("fields", []):
        name = field.get("name")
        if not name or name == "__vtable":
            continue
        abs_offset = base_offset + int(field.get("byte_offset", 0))
        byte_size = int(field.get("byte_size", 0))
        llvm_type = field.get("llvm_type", "")
        # If this field references another struct, recurse.
        nested = _parse_struct_ref(llvm_type)
        if nested and nested in structs_by_name:
            _flatten_layout(structs_by_name, nested, abs_offset, leaves, visited)
        else:
            leaves.append({
                "name": name,
                "absolute_byte_offset": abs_offset,
                "byte_size": byte_size,
                "llvm_type": llvm_type,
            })


def _parse_struct_ref(llvm_type: str) -> str | None:
    """Return the struct name if llvm_type is a named struct reference like '%PipelineCtrl_t'."""
    t = llvm_type.strip()
    if not t.startswith("%"):
        return None
    end = next((i for i, c in enumerate(t) if c in (" ", "=") and i > 0), len(t))
    inner = t[1:end].strip()
    return inner if inner else None


def find_field_offset(layout_structs: list, field_name: str,
                      top_struct_name: str) -> tuple[int, int] | None:
    """
    Return (absolute_byte_offset, byte_size) for `field_name` within
    `top_struct_name`, following nested struct references.
    Returns None if not found.
    """
    by_name = {s["struct_name"]: s for s in layout_structs}
    leaves: list[dict] = []
    _flatten_layout(by_name, top_struct_name, 0, leaves, set())
    for leaf in leaves:
        if leaf["name"] == field_name:
            return leaf["absolute_byte_offset"], leaf["byte_size"]
    return None


# ---------------------------------------------------------------------------
# Constraint derivation
# ---------------------------------------------------------------------------

def _derive_range(comparisons: list[dict]) -> tuple[int | None, int | None]:
    """
    From a field's comparison list extract the tightest (lo, hi) implied by
    sge/sgt (lower bounds) and sle/slt (upper bounds).
    Returns (None, None) if no comparisons exist.
    """
    lo_candidates: list[int] = []
    hi_candidates: list[int] = []
    for cmp in comparisons:
        pred = cmp.get("pred", "")
        thr = cmp.get("threshold", 0)
        if pred in ("sge", "uge"):
            lo_candidates.append(thr)
        elif pred in ("sgt", "ugt"):
            lo_candidates.append(thr + 1)
        elif pred in ("sle", "ule"):
            hi_candidates.append(thr)
        elif pred in ("slt", "ult"):
            hi_candidates.append(thr - 1)
    lo = max(lo_candidates) if lo_candidates else None
    hi = min(hi_candidates) if hi_candidates else None
    return lo, hi


def _zone_constraint_for_field(comparisons: list[dict],
                                zone_idx: int, n_zones: int,
                                global_lo: int, global_hi: int) -> dict:
    """
    Derive a [lo, hi] for a given zone index.
    Zone 0  → widest valid range.
    Higher zones → progressively narrower range, biased toward the middle of
    the comparison thresholds (simulates increased selectivity as discriminant
    advances).
    """
    tightening = zone_idx / max(n_zones - 1, 1)  # 0.0 at zone 0 → 1.0 at last zone
    range_width = global_hi - global_lo
    if range_width <= 0:
        return {"lo": global_lo, "hi": global_hi}

    # Shrink the window by up to 40% at the last zone, centred on the midpoint.
    shrink = tightening * 0.40
    margin = int(range_width * shrink / 2)
    lo = global_lo + margin
    hi = global_hi - margin
    # Ensure valid range.
    if lo >= hi:
        lo = global_lo
        hi = global_hi
    return {"lo": lo, "hi": hi}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Auto-generate zone_constraints.json for prism-go-explore."
    )
    parser.add_argument("weights_json", help="Path to <name>_weights.json")
    parser.add_argument("layout_json",  help="Path to <name>_layout.json")
    parser.add_argument(
        "--output", "-o",
        help="Output path (default: <name>_zone_constraints.json next to weights_json)",
    )
    parser.add_argument(
        "--zones", "-n", type=int, default=8,
        help="Number of zones to divide the discriminant range into (default: 8)",
    )
    args = parser.parse_args()

    weights_path = Path(args.weights_json)
    layout_path  = Path(args.layout_json)

    with weights_path.open() as f:
        weights = json.load(f)
    with layout_path.open() as f:
        layout_structs = json.load(f)

    # -----------------------------------------------------------------------
    # 1. Identify the discriminant field and max_fillhead.
    # -----------------------------------------------------------------------
    abort_targets = weights.get("abort_targets", [])
    if not abort_targets:
        print(
            "[probe_goexplore_zones] WARNING: no abort_targets in weights JSON.\n"
            "  Cannot auto-detect discriminant.  Provide a zone_constraints.json manually.",
            file=sys.stderr,
        )
        sys.exit(1)

    resolved = abort_targets[0].get("resolved", {})
    discriminant_name = resolved.get("field")
    max_fillhead_raw  = resolved.get("threshold")
    if not discriminant_name or max_fillhead_raw is None:
        print(
            "[probe_goexplore_zones] ERROR: abort_targets[0].resolved is missing "
            "'field' or 'threshold'.  Check that probe_ddg_adv.py ran successfully.",
            file=sys.stderr,
        )
        sys.exit(1)
    max_fillhead = int(max_fillhead_raw)

    # -----------------------------------------------------------------------
    # 2. Find discriminant byte offset in the layout.
    # -----------------------------------------------------------------------
    # The top-level struct is the last (or only) entry in the layout array.
    top_struct_name = layout_structs[-1]["struct_name"] if layout_structs else ""
    result = find_field_offset(layout_structs, discriminant_name, top_struct_name)
    if result is None:
        print(
            f"[probe_goexplore_zones] ERROR: field '{discriminant_name}' not found "
            f"in struct '{top_struct_name}' (layout: {layout_path}).\n"
            "  The field may be a derived value not stored in the struct.",
            file=sys.stderr,
        )
        sys.exit(1)
    discriminant_offset, discriminant_size = result

    print(
        f"[probe_goexplore_zones] Discriminant : {discriminant_name} "
        f"(offset={discriminant_offset}, size={discriminant_size}, max={max_fillhead})"
    )

    # -----------------------------------------------------------------------
    # 3. Derive per-field ranges from the weights JSON.
    # -----------------------------------------------------------------------
    input_fields = weights.get("input_fields", [])
    # Collect global [lo, hi] for each non-inhibitor field.
    field_ranges: dict[str, tuple[int, int]] = {}
    for ifield in input_fields:
        name  = ifield.get("name", "")
        roles = ifield.get("roles", [])
        comps = ifield.get("comparisons", [])
        if "inhibitor" in roles:
            continue  # inhibitors are zeroed by frame generation, no constraint needed
        lo, hi = _derive_range(comps)
        # Fallback: if no comparisons, use i16 full range but reasonably clipped.
        if lo is None:
            lo = 0
        if hi is None:
            hi = 100  # conservative default for unsigned-looking fields
        if lo >= hi:
            hi = lo + 1
        field_ranges[name] = (lo, hi)

    # -----------------------------------------------------------------------
    # 4. Build N zones evenly dividing [0, max_fillhead].
    # -----------------------------------------------------------------------
    n_zones = max(1, args.zones)
    zone_size = max(1, (max_fillhead + 1 + n_zones - 1) // n_zones)

    zones = []
    for z in range(n_zones):
        fh_lo = z * zone_size
        fh_hi = min((z + 1) * zone_size, max_fillhead + 1)
        field_constraints: dict[str, dict] = {}
        for fname, (glo, ghi) in field_ranges.items():
            field_constraints[fname] = _zone_constraint_for_field(
                [], z, n_zones, glo, ghi
            )
        zones.append({
            "id": z,
            "fillhead_lo": fh_lo,
            "fillhead_hi": fh_hi,
            "field_constraints": field_constraints,
        })
        print(
            f"[probe_goexplore_zones]   zone {z}: FillHead [{fh_lo}, {fh_hi}) "
            f"  constraints={list(field_constraints.keys())}"
        )

    # -----------------------------------------------------------------------
    # 5. Emit zone_constraints.json.
    # -----------------------------------------------------------------------
    output_path: Path
    if args.output:
        output_path = Path(args.output)
    else:
        stem = weights_path.stem  # e.g. "pipeline_controller_weights"
        # Strip trailing "_weights" if present.
        if stem.endswith("_weights"):
            stem = stem[: -len("_weights")]
        output_path = weights_path.parent / f"{stem}_zone_constraints.json"

    doc = {
        "program": top_struct_name,
        "discriminant_field": discriminant_name,
        "fillhead_byte_offset": discriminant_offset,
        "fillhead_byte_size": discriminant_size,
        "max_fillhead": max_fillhead,
        "zones": zones,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")

    print(f"[probe_goexplore_zones] Written: {output_path}")


if __name__ == "__main__":
    main()
