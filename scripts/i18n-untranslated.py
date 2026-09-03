#!/usr/bin/env python3
"""Report interface text that is still shown in English regardless of locale.

The wrapping pass only rewrote text that sat directly between a tag and its
closing tag. Text next to an inline element — a sentence with a `<code>` in the
middle of it, a `<label>` whose text is followed by an `<input>` — was left
behind, and those are exactly the places a half-translated screen shows itself.

This finds anything that looks like visible prose and is not inside a `t(...)`
call, so the gap can be closed deliberately rather than discovered by a reader.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Text between a `>` and a `<`, on one line, with at least two letters in a row
# and no braces (a brace means it is an expression, already handled or not text).
TEXT = re.compile(r">([^<>{}\n]*[A-Za-z]{2}[^<>{}\n]*)<")

# Attributes that reach the screen.
ATTRIBUTE = re.compile(r'\b(placeholder|title|aria-label|alt|label|hint|subtitle)="([^"]*[A-Za-z]{2}[^"]*)"')

# Ternaries and assignments that produce a visible sentence.
BARE = re.compile(r'[?:=]\s*"([A-Z][^"]{3,}?)"')

# A line that is nothing but prose. This is how text next to an inline element
# looks after formatting — `<label>` on one line, the words on the next, the
# `<input>` on the third — and it is the shape the wrapping pass could not see.
ALONE = re.compile(r"^\s*[A-Z][A-Za-z0-9 ,.'’“”—\-()]{3,}$")

SKIP_LINE = re.compile(
    r"import |from \"|\.request\(|className|=== |!== |localStorage|https?://|"
    r"^\s*//|^\s*\*|key=|data-|role=|type=\"|name=\"|htmlFor|viewBox|xmlns|d=\"|"
    # Generics and comparisons look like tags to a regex: `Promise<Foo>`,
    # `Record<string, X>`, `count > 0 && …`. None of them reach a screen.
    r"Promise<|Record<|Array<|useState<|: string|=> |\breturn\b|\bconst\b|\bfunction\b|"
    # `a.length > 0 && …` in a condition.
    r"\.length > |> 0 |\bBeta\b"
)


def main() -> int:
    root = Path(__file__).resolve().parent.parent / "web" / "src"
    found = 0
    for path in sorted(root.rglob("*.tsx")):
        if path.name == "icons.tsx":
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
            if SKIP_LINE.search(line):
                continue
            for match in TEXT.finditer(line):
                text = match.group(1).strip()
                if text and not text.startswith("t("):
                    print(f"{path.name}:{number}: text  {text[:80]}")
                    found += 1
            for match in ATTRIBUTE.finditer(line):
                print(f"{path.name}:{number}: attr  {match.group(1)}={match.group(2)[:60]}")
                found += 1
            if ALONE.match(line) and not line.strip().endswith((",", "{", "(", ";", ":")):
                print(f"{path.name}:{number}: alone {line.strip()[:70]}")
                found += 1
            for match in BARE.finditer(line):
                if "t(" in line[: match.start()][-3:]:
                    continue
                print(f"{path.name}:{number}: value {match.group(1)[:70]}")
                found += 1
    print(f"\n{found} left untranslated")
    return 1 if found else 0


if __name__ == "__main__":
    raise SystemExit(main())
