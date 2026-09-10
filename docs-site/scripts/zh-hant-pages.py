#!/usr/bin/env python3
"""Derive the traditional Chinese documentation from the simplified one.

The interface strings already do this in `scripts/i18n-zh-hant.py`, which
converts a JSON dictionary. The pages are the same problem in a different
container: twenty-four markdown files rather than one map of sentences.

Both the character table and the word list are reused from that script rather
than copied, so a correction made for the interface reaches the documentation
too. Nothing in either table is a latin character, so code blocks, URLs, file
paths and option names pass through untouched — which is why the whole file can
be converted without parsing it.

    python3 scripts/zh-hant-pages.py

Rerun it after editing a zh-CN page. The result is reviewed, not trusted:
anything it gets wrong is a normal edit to the file it wrote.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

SITE = Path(__file__).resolve().parent.parent
CONVERTER = SITE.parent / "scripts" / "i18n-zh-hant.py"


def load_converter():
    spec = importlib.util.spec_from_file_location("i18n_zh_hant", CONVERTER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.convert


def main() -> int:
    convert = load_converter()
    docs = "docusaurus-plugin-content-docs/current"
    source = SITE / "i18n" / "zh-CN" / docs
    target = SITE / "i18n" / "zh-TW" / docs

    written = 0
    for path in sorted(source.rglob("*")):
        if path.is_dir() or path.suffix not in {".md", ".mdx", ".json"}:
            continue
        destination = target / path.relative_to(source)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(convert(path.read_text(encoding="utf-8")), encoding="utf-8")
        written += 1

    print(f"  zh-TW  {written} pages from zh-CN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
