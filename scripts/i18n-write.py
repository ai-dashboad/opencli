#!/usr/bin/env python3
"""Write a locale file, taking its keys from the source rather than by hand.

A translation file is four hundred and eighty-seven lines whose left-hand side
must match the English exactly — including the curly quotes in one string and
the `{count}` placeholders in six others. Retyping them is a way to produce a
file that looks complete and silently fails on the four keys that were mistyped.

So the keys are copied from `zh.ts`, which is the set the check already
compares against, and a translator supplies only the right-hand side. Anything
offered that matches no key is reported rather than written: that is a typo,
and a typo in a key is exactly what this exists to catch.

Usage:

    python3 scripts/i18n-write.py <code> <name> <translations.json>

where the JSON is a flat object of English sentence to its replacement.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALES = ROOT / "web" / "src" / "locales"
SOURCE = LOCALES / "zh.ts"

# The left-hand side of each line, exactly as written, escapes and all.
ENTRY = re.compile(r'^  "((?:[^"\\]|\\.)*)":', re.M)


def escape(value: str) -> str:
    """A TypeScript double-quoted string body."""
    return value.replace("\\", "\\\\").replace('"', '\\"')


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    code, name, source = sys.argv[1], sys.argv[2], Path(sys.argv[3])

    keys = ENTRY.findall(SOURCE.read_text(encoding="utf-8"))
    translations: dict[str, str] = json.loads(source.read_text(encoding="utf-8"))

    unknown = sorted(set(translations) - set(keys))
    for stray in unknown:
        print(f"  no such key: {stray[:70]}")

    lines = [
        "/**",
        f" * {name}.",
        " *",
        " * Keyed by the English sentence, like every other translation here. A key",
        " * missing from this file shows its English, so an incomplete translation",
        " * reads as a mix rather than as a screen of blanks.",
        " *",
        " * Correcting one sentence does not mean editing this file: a JSON file in",
        " * `$OPENCLI_HOME/locales` named for this language overrides what is here,",
        " * entry by entry. See `docs/languages.md`.",
        " */",
        "",
        "export const strings: Record<string, string> = {",
    ]
    written = 0
    for key in keys:
        # The unescaped form is what the JSON is keyed by; the file wants the
        # escaped one back.
        plain = key.replace('\\"', '"').replace("\\\\", "\\")
        value = translations.get(plain)
        if value is None:
            continue
        lines.append(f'  "{key}": "{escape(value)}",')
        written += 1
    lines.append("};")
    lines.append("")

    (LOCALES / f"{code}.ts").write_text("\n".join(lines), encoding="utf-8")
    missing = len(keys) - written
    print(f"{code}: {written} of {len(keys)} written" + (f", {missing} left as English" if missing else ""))
    return 1 if unknown else 0


if __name__ == "__main__":
    raise SystemExit(main())
