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
#
# `OPENCLI_QUICK=1` builds the iteration profile instead of the release one:
# the same binary without the whole-program optimisation, minutes rather than
# ten of them. Never use it for anything anyone else will run — which is why
# the line it prints says which of the two went in.
set -euo pipefail

target="$(rustc -vV | sed -n 's/^host: //p')"
root="$(cd "$(dirname "$0")/.." && pwd)"
profile="${OPENCLI_QUICK:+quick}"
profile="${profile:-release}"

# Windows executables carry the suffix, and Tauri looks for the sidecar under
# the name it would have on the platform being built for. Staged without it,
# the bundle builds and ships an app that cannot find its agent.
suffix=""
case "$target" in
  *-windows-*) suffix=".exe" ;;
esac

cargo build --profile "$profile" --manifest-path "$root/opencli-rs/Cargo.toml" \
  -p opencli-cli --bin opencli

mkdir -p "$root/desktop/src-tauri/bin"
cp -f "$root/opencli-rs/target/$profile/opencli$suffix" \
  "$root/desktop/src-tauri/bin/opencli-$target$suffix"
echo "staged opencli-$target$suffix from the $profile profile"
