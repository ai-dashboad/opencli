#!/usr/bin/env python3
"""Write the `latest.json` the desktop updater reads.

The updater asks one URL for one file describing the newest release: its
version, and per platform a download URL plus the minisign signature over it.
Tauri's own release action can produce this, but only if it also creates the
GitHub Release — and this repository's release is assembled from several
workflows, so it is built here instead, from whatever was actually uploaded.

Pairing is by signature: every updatable artifact is published next to a `.sig`
of the same name, so a `.sig` is the evidence that a file is one the updater can
install. Anything without one — the `.dmg` a person downloads by hand, the
`.deb` — is left out rather than guessed at, which also means Tauri renaming its
bundles does not silently produce a manifest pointing at nothing.

Usage:
    make-updater-manifest.py --version 0.1.0 \
        --dist dist-desktop --repo ai-dashboad/opencli --tag v0.1.0 \
        --notes-file notes.md --out latest.json
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# The platform keys Tauri's updater looks itself up by. Directory names under
# --dist must be exactly these.
KNOWN_PLATFORMS = {
    "darwin-x86_64",
    "darwin-aarch64",
    "linux-x86_64",
    "linux-aarch64",
    "windows-x86_64",
    "windows-aarch64",
}


# Windows is bundled twice — an NSIS installer and an MSI — and both are
# signed, so a platform can offer more than one updatable artifact. NSIS is the
# one to update through: it can replace a running application without asking for
# administrator rights, which is what an update that is meant to be quiet needs.
PREFERENCE = (".app.tar.gz.sig", "-setup.exe.sig", ".exe.sig", ".msi.sig", ".AppImage.sig")


def preferred(signatures: list[Path]) -> Path:
    """Pick which signed artifact this platform updates through."""
    for suffix in PREFERENCE:
        for signature in signatures:
            if signature.name.endswith(suffix):
                return signature
    return signatures[0]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--dist", required=True, type=Path)
    parser.add_argument("--repo", required=True, help="owner/name on GitHub")
    parser.add_argument("--tag", required=True)
    parser.add_argument("--notes-file", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()

    notes = ""
    if args.notes_file and args.notes_file.is_file():
        notes = args.notes_file.read_text(encoding="utf-8").strip()

    platforms: dict[str, dict[str, str]] = {}
    for directory in sorted(p for p in args.dist.iterdir() if p.is_dir()):
        platform = directory.name
        if platform not in KNOWN_PLATFORMS:
            print(f"skipping {platform}: not an updater platform key", file=sys.stderr)
            continue

        signatures = sorted(directory.glob("*.sig"))
        if not signatures:
            print(f"skipping {platform}: no signed artifact", file=sys.stderr)
            continue

        signature = preferred(signatures)
        artifact = signature.with_suffix("")
        if not artifact.is_file():
            print(f"error: {signature.name} has no artifact beside it", file=sys.stderr)
            return 1

        platforms[platform] = {
            "signature": signature.read_text(encoding="utf-8").strip(),
            "url": (
                f"https://github.com/{args.repo}/releases/download/{args.tag}/{artifact.name}"
            ),
        }

    if not platforms:
        print("error: no signed artifacts anywhere; refusing to publish an empty manifest",
              file=sys.stderr)
        return 1

    manifest = {
        "version": args.version,
        "notes": notes,
        "pub_date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "platforms": platforms,
    }
    args.out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {args.out} for {', '.join(sorted(platforms))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
