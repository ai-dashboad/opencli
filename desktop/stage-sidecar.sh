#!/usr/bin/env bash
# Put the current `opencli` beside the app before it is bundled.
#
# The desktop process does not serve the agent itself: it runs the `opencli`
# binary next to it, bundled by Tauri as an `externalBin`. That copy is staged
# by hand, and for a day it was not — so every change to the agent, the
# gateway and the history reader was built, committed, and never reached the
# running app, while frontend changes arrived every time because Vite rebuilds
# and Tauri re-embeds them. The two halves of the same release drifted twelve
# hours apart without a single error to say so.
#
# Run from `desktop/`, by `beforeBuildCommand`, so it cannot be forgotten.
set -euo pipefail

target="$(rustc -vV | sed -n 's/^host: //p')"
root="$(cd "$(dirname "$0")/.." && pwd)"

cargo build --release --manifest-path "$root/opencli-rs/Cargo.toml" -p opencli-cli --bin opencli

mkdir -p "$root/desktop/src-tauri/bin"
cp -f "$root/opencli-rs/target/release/opencli" "$root/desktop/src-tauri/bin/opencli-$target"
echo "staged opencli-$target from this build"
