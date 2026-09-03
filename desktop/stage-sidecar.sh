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
#
# `OPENCLI_TARGET` names the triple to stage for, and must be whatever
# `cargo tauri build` was given with `--target`. Tauri looks for the sidecar
# under the triple *it* is building for, and it takes that from the CLI
# binary's own architecture rather than from `rustc` — so an arm64 runner
# whose `cargo-tauri` was installed as an x86_64 build looked for
# `opencli-x86_64-apple-darwin`, found the `opencli-aarch64-apple-darwin` this
# script had just staged, and failed after twenty-eight minutes of compiling.
# Passing the triple to both is what keeps them talking about the same thing.
set -euo pipefail

host="$(rustc -vV | sed -n 's/^host: //p')"
target="${OPENCLI_TARGET:-$host}"
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

# Building for the host is the ordinary case and keeps the shared
# `target/release` directory, which is most of why a rebuild here is quick.
# An explicit target only costs its own directory when it differs.
if [ "$target" = "$host" ]; then
  cargo build --profile "$profile" --manifest-path "$root/opencli-rs/Cargo.toml" \
    -p opencli-cli --bin opencli
  built="$root/opencli-rs/target/$profile/opencli$suffix"
else
  cargo build --profile "$profile" --target "$target" \
    --manifest-path "$root/opencli-rs/Cargo.toml" -p opencli-cli --bin opencli
  built="$root/opencli-rs/target/$target/$profile/opencli$suffix"
fi

mkdir -p "$root/desktop/src-tauri/bin"
cp -f "$built" "$root/desktop/src-tauri/bin/opencli-$target$suffix"
echo "staged opencli-$target$suffix from the $profile profile"
