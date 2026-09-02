#!/usr/bin/env bash
# Move every version number in the repository to the same value.
#
# A release is one tag and one number, but that number is written in four
# places: the Rust workspace (the CLI), the desktop crate, the Tauri bundle
# manifest, and the web UI. They had already drifted — 0.94.0, 0.1.0, 0.1.0 and
# 0.0.0-dev — which matters more than it looks: the desktop updater decides
# whether an update exists by comparing the running app's version against the
# one in `latest.json`. Two halves of a release disagreeing about which release
# they are is a bug with no error message.
#
# Usage: scripts/set-version.sh 0.2.0
set -euo pipefail

version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta)\.[0-9]+)?$ ]]; then
  echo "usage: $0 <x.y.z | x.y.z-alpha.N | x.y.z-beta.N>" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"

# The Rust workspace: every crate inherits `version.workspace = true`.
perl -0pi -e "s/^version = \"[^\"]+\"/version = \"$version\"/m" \
  "$root/opencli-rs/Cargo.toml"

# The desktop crate and its bundle manifest.
perl -0pi -e "s/^version = \"[^\"]+\"/version = \"$version\"/m" \
  "$root/desktop/src-tauri/Cargo.toml"
perl -0pi -e "s/(\"version\": \")[^\"]+(\")/\${1}$version\${2}/" \
  "$root/desktop/src-tauri/tauri.conf.json"

# The web UI, which shows the version in Settings.
perl -0pi -e "s/(\"version\": \")[^\"]+(\")/\${1}$version\${2}/" \
  "$root/web/package.json"

# The npm wrapper's version is written at publish time by
# `scripts/stage_npm_packages.py --release-version`, so it stays a placeholder.

echo "set version to $version in:"
echo "  opencli-rs/Cargo.toml"
echo "  desktop/src-tauri/Cargo.toml"
echo "  desktop/src-tauri/tauri.conf.json"
echo "  web/package.json"
echo
echo "next: cargo update -w --manifest-path opencli-rs/Cargo.toml to refresh the lock files,"
echo "      then commit and tag v$version"
