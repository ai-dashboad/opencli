#!/usr/bin/env python3
"""Wrap the interface's visible text in `t(...)`, once.

A one-off used to introduce translation across the web UI. It is kept because
the next person to add a panel will want to know how the existing calls got
there, and because running it again over a file that has been edited by hand is
a reasonable way to catch text that was added without `t()`.

It handles the three shapes that carry visible text:

- JSX text between tags
- `placeholder`, `title`, `aria-label` and `alt` attributes
- `label:` and `hint:` fields in the option tables at the top of a file

Everything else — class names, keys, protocol strings, comments — is left
alone, which is why this is deliberately narrow rather than clever. Whatever it
misses is picked up by reading the diff.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Text that is not prose: punctuation, symbols, numbers, single letters.
SKIP = re.compile(r"^[\s\d\W_]*$")

ATTRIBUTES = ("placeholder", "title", "aria-label", "alt")


def is_prose(text: str) -> bool:
    stripped = text.strip()
    if len(stripped) < 2 or SKIP.match(stripped):
        return False
    # Interpolations are handled by hand: the wrapper takes a literal.
    return "${" not in stripped and "{" not in stripped


def wrap_jsx_text(source: str) -> str:
    """`>Some text</tag>` becomes `>{t("Some text")}</tag>`.

    The closing `</` is required. Without it the pattern also matches the tail
    of a generic — `useState<Status | "idle">("idle")` ends in `>` and is
    followed by text — and rewrites type annotations into calls, which is a
    long way from a translated interface.
    """

    def replace(match: re.Match[str]) -> str:
        before, text, after = match.group(1), match.group(2), match.group(3)
        if not is_prose(text) or "=>" in text or ";" in text:
            return match.group(0)
        leading = text[: len(text) - len(text.lstrip())]
        trailing = text[len(text.rstrip()) :]
        body = " ".join(text.split()).replace('"', '\\"')
        return f'{before}{leading}{{t("{body}")}}{trailing}{after}'

    return re.sub(r"(>)([^<>{}]+)(</)", replace, source)


def wrap_attributes(source: str) -> str:
    for attribute in ATTRIBUTES:
        pattern = re.compile(rf'({attribute}=)"([^"]+)"')

        def replace(match: re.Match[str]) -> str:
            name, text = match.group(1), match.group(2)
            if not is_prose(text):
                return match.group(0)
            return f'{name}{{t("{text}")}}'

        source = pattern.sub(replace, source)
    return source


def wrap_option_tables(source: str) -> str:
    """`label: "Dark"` becomes `label: t("Dark")`, and the same for `hint`."""
    for field in ("label", "hint", "description"):
        pattern = re.compile(rf'(\b{field}: )"([^"]+)"')

        def replace(match: re.Match[str]) -> str:
            name, text = match.group(1), match.group(2)
            if not is_prose(text):
                return match.group(0)
            return f'{name}t("{text}")'

        source = pattern.sub(replace, source)
    return source


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    for name in sys.argv[1:]:
        path = Path(name)
        source = path.read_text(encoding="utf-8")
        wrapped = wrap_option_tables(wrap_attributes(wrap_jsx_text(source)))
        if wrapped == source:
            print(f"{path}: nothing to wrap")
            continue
        path.write_text(wrapped, encoding="utf-8")
        print(f"{path}: wrapped {wrapped.count('t(\"') - source.count('t(\"')} strings")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
