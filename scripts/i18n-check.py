#!/usr/bin/env python3
"""Compare the strings the interface uses against each translation.

Keying translations by the English sentence makes a missing entry harmless —
the English is shown — and makes an *edited* English sentence silently orphan
its translation. This is the thing that notices.

Exits non-zero when a translation is incomplete, so CI can say so before the
interface quietly reverts to English in the middle of a panel.
"""

from __future__ import annotations

import json
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

# Translations are JSON files in `web/src/locales`, the same shape as one
# somebody drops in `$OPENCLI_HOME/locales`. One format for both is the point:
# a shipped translation can be copied out, corrected and put back.
def entries(path: Path) -> list[str]:
    body = json.loads(path.read_text(encoding="utf-8"))
    return list(body.get("strings", body))


# Which translations must be complete for this to pass.
#
# Nine ship. Requiring every one of them to be finished before an English
# sentence may be added would mean no sentence is ever added — a translation
# nobody has caught up on yet shows English for those lines, which is the
# design, not a fault. So one is held to completeness and the rest are
# reported.
MAINTAINED = {"zh"}

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


# Text on screen that never went through `t()`.
#
# The check above compares what `t()` was given against each dictionary, which
# means a sentence nobody wrapped is invisible to it: it is not untranslated,
# it is not orphaned, it is simply not seen. That is how a report saying every
# string was translated coexisted with a Chinese interface full of English —
# a hundred and ninety-five of them, in panels people use daily.
#
# Two shapes reach a screen without a call: text between JSX tags, and a
# literal given to a prop that renders. Both are matched conservatively, on
# text that reads like a sentence rather than an identifier, so what is
# reported is worth acting on.
# `(?<!=)` keeps the arrow of `=> Promise<void>` from reading as a closing tag
# followed by text. A return type and a text node are the same three
# characters otherwise.
JSX_TEXT = re.compile(r"(?<!=)>\s*([A-Z][A-Za-z][^<>{}\n]{2,90}?)\s*<")
RENDERED_PROP = re.compile(
    r'(?:placeholder|title|aria-label|label|alt)=\{?"([A-Z][^"\n]{2,90})"'
)
# A literal sentence in a ternary or a variable that ends up on screen.
SENTENCE = re.compile(r'(?<![\w.])"([A-Z][a-z]+(?: [A-Za-z0-9\'’…\-\.\(\)]+){1,14})"')

# Words that look like sentences but are not addressed to anybody: product
# names, protocol values, and the shell.
NOT_PROSE = {"OpenCLI", "Hugging Face"}

# `Promise<void>` and friends: a type argument sits between `<` and `>` exactly
# as JSX text does, and no regex over one line can tell them apart. Recognised
# by the generic that follows rather than by name, so a new one is caught too.
TYPE_ARGUMENT = re.compile(r"[A-Za-z]<[^<>]*$")


# A sentence that wraps across lines between its tags. Matched over the whole
# file rather than line by line, because the line-at-a-time pass above cannot
# see it: the opening tag, the words, and the closing tag are on three
# different lines, and each line on its own looks like nothing.
#
# Found the hard way — a paragraph in Customize sat in English through a check
# that reported every string translated.
WRAPPED_TEXT = re.compile(r">\n\s+([A-Z][a-z][^<>{}]{20,200}?)\n\s*</", re.S)

# Emphasis inside a sentence, which the pattern above would otherwise read as
# the end of the text node.
INLINE_TAG = re.compile(r"</?(?:strong|em|b|i|code|span)>")


# A JSX comment: `{/*` … `*/}`, usually over several lines, none of which
# begins with a comment marker. The line-prefix rule above sees only the first
# of them, so a comment quoting an English sentence — which the ones in this
# codebase routinely do, since they explain what a screen used to say — reads
# as untranslated text.
#
# Matched on `{/*` rather than on `/*`, which is what makes this safe: the
# earlier attempt at multi-line comments matched `accept="image/*"` and ate
# four thousand characters of working code. A `/*` with a `{` in front of it
# is a comment and nothing else.
JSX_COMMENT_OPEN = re.compile(r"\{\s*/\*")
JSX_COMMENT_CLOSE = re.compile(r"\*/")


def outside_comments(source: str) -> list[str]:
    """Each line, blanked where it is inside a comment of any shape."""
    lines: list[str] = []
    in_block = False
    for line in source.split("\n"):
        opens = JSX_COMMENT_OPEN.search(line)
        if in_block:
            lines.append("")
            if JSX_COMMENT_CLOSE.search(line):
                in_block = False
            continue
        if opens and not JSX_COMMENT_CLOSE.search(line[opens.end():]):
            in_block = True
            lines.append(line[: opens.start()])
            continue
        lines.append("" if COMMENT_LINE.match(line) else line)
    return lines


def bare_strings(root: Path) -> list[tuple[str, int, str]]:
    """English that reaches a screen without being translatable."""
    found: list[tuple[str, int, str]] = []
    for path in sorted(root.rglob("*.tsx")):
        # A test asserts on English by design; it is not on anybody's screen.
        if path.name.endswith((".test.tsx", ".test.ts")):
            continue
        whole = "\n".join(outside_comments(path.read_text(encoding="utf-8")))
        # A sentence broken by an inline `<strong>` or `<code>` is still one
        # sentence to a reader, and hiding behind emphasis is how "No models
        # are configured yet" stayed in English. The tags are dropped before
        # matching, so what is reported reads as prose rather than as source.
        plain = INLINE_TAG.sub("", whole)
        for match in WRAPPED_TEXT.finditer(plain):
            text = " ".join(match.group(1).split())
            found.append((str(path), plain[: match.start()].count("\n") + 2, text))
        for number, line in enumerate(whole.split("\n"), 1):
            for pattern in (JSX_TEXT, RENDERED_PROP, SENTENCE):
                for match in pattern.finditer(line):
                    text = match.group(1).strip()
                    if text in NOT_PROSE or text.startswith(("http", "/")):
                        continue
                    if TYPE_ARGUMENT.search(line[: match.start()]):
                        continue
                    # Already translated on this line, by this very call.
                    if f't("{text}"' in line:
                        continue
                    found.append((str(path), number, text))
    return found


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
    for locale in sorted((root / "locales").glob("*.json")):
        listed = entries(locale)
        have = set(listed)
        # A key written twice means one translation silently replaces the
        # other, and reading these as a set made that invisible here — it was
        # the TypeScript compiler that noticed, which is luck rather than a
        # check.
        if len(listed) != len(have):
            seen: set[str] = set()
            for text in listed:
                if text in seen:
                    print(f"  twice:    {text}")
                    failed = True
                seen.add(text)
        missing = sorted(used - have)
        orphaned = sorted(have - used)
        held = locale.stem in MAINTAINED
        note = "" if held else "  (reported, not required)"
        print(f"{locale.stem}: {len(have & used)} of {len(used)} translated{note}")
        for text in missing:
            print(f"  missing:  {text}")
            if held:
                failed = True
        for text in orphaned:
            # Not a failure: an orphan is dead weight, not a hole on screen.
            print(f"  orphaned: {text}")

    bare = bare_strings(root)
    if bare:
        print(f"\n{len(bare)} strings reach the screen without t():")
        for path, number, text in bare:
            print(f"  {Path(path).name}:{number}  {text}")
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
