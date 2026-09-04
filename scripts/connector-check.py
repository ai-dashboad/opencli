#!/usr/bin/env python3
"""Every connector a kind of work names must be one you can actually add.

The first screen tells somebody "needs gmail" and sends them to the Connectors
panel, where there is no gmail to add. That is a dead end of exactly the kind
this project keeps producing: an offer that reads as capability and ends in a
shrug.

The two lists live in different languages — the work in `web/src/scenarios.ts`,
the catalogue in `opencli-rs/web-gateway/src/connector.rs` — so nothing in
either compiler can notice they disagree. This can.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCENARIOS = ROOT / "web" / "src" / "scenarios.ts"
CATALOG = ROOT / "opencli-rs" / "web-gateway" / "src" / "connector.rs"

# `needs: ["slack", "notion"]`
NEEDS = re.compile(r"needs:\s*\[([^\]]*)\]")
NAME = re.compile(r'"([^"]+)"')

# `"id": "slack",` inside the catalogue function.
CATALOG_ID = re.compile(r'"id":\s*"([a-z0-9-]+)"')


def main() -> int:
    scenarios = SCENARIOS.read_text(encoding="utf-8")
    needed: set[str] = set()
    for match in NEEDS.finditer(scenarios):
        needed |= set(NAME.findall(match.group(1)))

    catalog = CATALOG.read_text(encoding="utf-8")
    # Only what `catalog()` offers; `connector/add` takes anything by hand, and
    # a name that can only be typed in is not something a screen may promise.
    start = catalog.find("fn catalog()")
    offered = set(CATALOG_ID.findall(catalog[start:])) if start != -1 else set()

    missing = sorted(needed - offered)
    print(f"{len(needed)} named by the work, {len(offered)} in the catalogue")
    for name in missing:
        print(f"  no way to add:  {name}")
    if missing:
        print("\nEither add it to the catalogue, or name one that is there.")
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
