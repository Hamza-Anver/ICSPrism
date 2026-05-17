from __future__ import annotations

import argparse

from . import to_dot, probe, probe_adv, state_hash, zones


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="python -m ddg",
        description="ICSPrism DDG analysis tools",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    to_dot.add_args(sub.add_parser("to-dot",     help="Render DDG as GraphViz DOT"))
    probe.add_args(sub.add_parser("probe",        help="Validate DDG proximity scores"))
    probe_adv.add_args(sub.add_parser("probe-adv", help="Semantic DDG analysis + byte weights"))
    state_hash.add_args(sub.add_parser("state-hash", help="Generate state hash config"))
    zones.add_args(sub.add_parser("zones",        help="Generate zone constraints"))

    args = parser.parse_args()
    dispatch = {
        "to-dot":     to_dot.run,
        "probe":      probe.run,
        "probe-adv":  probe_adv.run,
        "state-hash": state_hash.run,
        "zones":      zones.run,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
