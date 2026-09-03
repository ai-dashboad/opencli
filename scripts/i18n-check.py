#!/usr/bin/env python3
"""Compare the strings the interface uses against each translation.

Keying translations by the English sentence makes a missing entry harmless —
the English is shown — and makes an *edited* English sentence silently orphan
its translation. This is the thing that notices.

Exits non-zero when a translation is incomplete, so CI can say so before the
interface quietly reverts to English in the middle of a panel.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# A word boundary before `t(`, or this also matches `get("…")` and every other
# identifier that happens to end in t.
CALL = re.compile(r'(?<![A-Za-z0-9_$.])t\(\s*"((?:[^"\\]|\\.)*)"')

# `plural(count, "one", "many")` reaches the screen exactly as `t()` does, and
# looking only for `t(` meant its two sentences were never counted as used —
# so `{count} tool` and `{count} chat` sat untranslated behind a report that
# said every string was done. A check that cannot see a whole call shape is
# worse than no check, because it is believed.
PLURAL = re.compile(
    r'(?<![A-Za-z0-9_$.])plural\(\s*[^,]+,\s*'
    r'"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"'
)

ENTRY = re.compile(r'^  "((?:[^"\\]|\\.)*)":', re.M)

# A `t("…")` written *about* the code is not a string the interface uses. One
# in a docstring explaining how this very check works was duly reported as an
# untranslated ellipsis, which is the sort of thing that teaches people to
# ignore the report.
#
# Whole lines only, and by how the line begins. Matching `/* … */` across lines
# instead looked obviously right and was not: `accept="image/*"` opens a
# comment as far as that pattern is concerned, and the closing `*/` it found
# was four thousand characters later, taking a working part of the composer
# with it and reporting eight real strings as orphaned.
COMMENT_LINE = re.compile(r"^\s*(?://|/\*|\*)")


def without_comments(source: str) -> str:
    """Drop comment lines, so only what reaches a screen is counted."""
    return "\n".join(
        "" if COMMENT_LINE.match(line) else line for line in source.split("\n")
    )


def main() -> int:
    root = Path(__file__).resolve().parent.parent / "web" / "src"

    used: set[str] = set()
    for path in root.rglob("*.ts*"):
        if "locales" in str(path) or path.name == "i18n.ts":
            continue
        source = without_comments(path.read_text(encoding="utf-8"))
        used |= {match.group(1) for match in CALL.finditer(source)}
        for match in PLURAL.finditer(source):
            used |= {match.group(1), match.group(2)}

    failed = False
    for locale in sorted((root / "locales").glob("*.ts")):
        have = set(ENTRY.findall(locale.read_text(encoding="utf-8")))
        missing = sorted(used - have)
        orphaned = sorted(have - used)
        print(f"{locale.stem}: {len(have)} of {len(used)} translated")
        for text in missing:
            print(f"  missing:  {text}")
            failed = True
        for text in orphaned:
            # Not a failure: an orphan is dead weight, not a hole on screen.
            print(f"  orphaned: {text}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
