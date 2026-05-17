from __future__ import annotations

import sys
from pathlib import Path

from .io import load_layout, load_weights
from .fields import find_field_offset


def _derive_range(comparisons: list[dict]) -> tuple[int | None, int | None]:
    """Extract tightest (lo, hi) from a field's comparison list."""
    lo_candidates: list[int] = []
    hi_candidates: list[int] = []
    for cmp in comparisons:
        pred = cmp.get("pred", "")
        thr  = cmp.get("threshold", 0)
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


def _zone_constraint_for_field(zone_idx: int, n_zones: int,
                                global_lo: int, global_hi: int) -> dict:
    """
    Derive [lo, hi] for a given zone index.
    Zone 0 → widest range; higher zones → progressively narrower (up to 40% shrink).
    """
    tightening = zone_idx / max(n_zones - 1, 1)
    range_width = global_hi - global_lo
    if range_width <= 0:
        return {"lo": global_lo, "hi": global_hi}
    margin = int(range_width * tightening * 0.40 / 2)
    lo = global_lo + margin
    hi = global_hi - margin
    if lo >= hi:
        lo, hi = global_lo, global_hi
    return {"lo": lo, "hi": hi}


def add_args(sub) -> None:
    sub.add_argument("weights_json", help="<name>_weights.json")
    sub.add_argument("layout_json",  help="<name>_layout.json")
    sub.add_argument("--output", "-o", help="Output path (default: <name>_zone_constraints.json)")
    sub.add_argument("--zones",  "-n", type=int, default=8,
                     help="Number of zones (default: 8)")


def run(args) -> None:
    weights_path = Path(args.weights_json)
    layout_path  = Path(args.layout_json)

    weights        = load_weights(weights_path)
    layout_structs = load_layout(layout_path)

    abort_targets = weights.get("abort_targets", [])
    if not abort_targets:
        print("[zones] WARNING: no abort_targets in weights JSON.", file=sys.stderr)
        sys.exit(1)

    resolved = abort_targets[0].get("resolved", {})
    discriminant_name = resolved.get("field")
    max_fillhead_raw  = resolved.get("threshold")
    if not discriminant_name or max_fillhead_raw is None:
        print("[zones] ERROR: abort_targets[0].resolved missing 'field' or 'threshold'.",
              file=sys.stderr)
        sys.exit(1)
    max_fillhead = int(max_fillhead_raw)

    top_struct_name = layout_structs[-1]["struct_name"] if layout_structs else ""
    result = find_field_offset(layout_structs, discriminant_name, top_struct_name)
    if result is None:
        print(f"[zones] ERROR: field '{discriminant_name}' not found in '{top_struct_name}'.",
              file=sys.stderr)
        sys.exit(1)
    discriminant_offset, discriminant_size = result
    print(f"[zones] Discriminant: {discriminant_name} "
          f"(offset={discriminant_offset}, size={discriminant_size}, max={max_fillhead})")

    input_fields = weights.get("input_fields", [])
    field_ranges: dict[str, tuple[int, int]] = {}
    for ifield in input_fields:
        name  = ifield.get("name", "")
        roles = ifield.get("roles", [])
        comps = ifield.get("comparisons", [])
        if "inhibitor" in roles:
            continue
        lo, hi = _derive_range(comps)
        lo = lo if lo is not None else 0
        hi = hi if hi is not None else 100
        if lo >= hi:
            hi = lo + 1
        field_ranges[name] = (lo, hi)

    n_zones   = max(1, args.zones)
    zone_size = max(1, (max_fillhead + 1 + n_zones - 1) // n_zones)

    zones = []
    for z in range(n_zones):
        fh_lo = z * zone_size
        fh_hi = min((z + 1) * zone_size, max_fillhead + 1)
        field_constraints = {
            fname: _zone_constraint_for_field(z, n_zones, glo, ghi)
            for fname, (glo, ghi) in field_ranges.items()
        }
        zones.append({
            "id":                z,
            "fillhead_lo":       fh_lo,
            "fillhead_hi":       fh_hi,
            "field_constraints": field_constraints,
        })
        print(f"[zones]   zone {z}: FillHead [{fh_lo}, {fh_hi})  "
              f"constraints={list(field_constraints.keys())}")

    if args.output:
        output_path = Path(args.output)
    else:
        stem = weights_path.stem
        if stem.endswith("_weights"):
            stem = stem[:-len("_weights")]
        output_path = weights_path.parent / f"{stem}_zone_constraints.json"

    doc = {
        "program":               top_struct_name,
        "discriminant_field":    discriminant_name,
        "fillhead_byte_offset":  discriminant_offset,
        "fillhead_byte_size":    discriminant_size,
        "max_fillhead":          max_fillhead,
        "zones":                 zones,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    import json
    with output_path.open("w") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
    print(f"[zones] Written: {output_path}")
