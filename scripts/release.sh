#!/usr/bin/env bash
# Cut a release: bump the version everywhere, commit, tag, push.
#
#   scripts/release.sh 0.1.1
#
# One command because the parts cannot be done half-way. The version lives in
# four files and the tag has to agree with all of them — `rust-release.yml`
# checks that and refuses the tag otherwise, twenty minutes after you pushed
# it. Bumping without tagging, or tagging without bumping, are both easy and
# both silent until then.
#
# It also refuses to move a tag that already exists. While a release has never
# produced anything, re-pushing its tag is harmless; the moment one has, the
# tag is a promise about a specific set of bytes that people have downloaded,
# and moving it makes two different builds answer to one name.
set -euo pipefail

version="${1:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta)\.[0-9]+)?$ ]]; then
  cat >&2 <<'USAGE'
usage: scripts/release.sh <x.y.z | x.y.z-alpha.N | x.y.z-beta.N>

  0.1.1   a fix, or anything users can see that does not break their setup
  0.2.0   a release with new capability in it
  1.0.0   when you are willing to promise the configuration format is stable
USAGE
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

tag="v${version}"

if [[ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]]; then
  echo "error: releases are cut from main; you are on $(git rev-parse --abbrev-ref HEAD)" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: the working tree has uncommitted changes." >&2
  echo "       A release is a commit; decide what is in it first." >&2
  exit 1
fi

git fetch --quiet --tags origin
if git rev-parse "$tag" >/dev/null 2>&1 || git ls-remote --exit-code --tags origin "$tag" >/dev/null 2>&1; then
  echo "error: $tag already exists." >&2
  echo "       A released version is a fixed set of bytes. Pick the next number." >&2
  exit 1
fi

previous="$(git tag --list 'v*' --sort=-v:refname | head -1)"
echo "Previous release: ${previous:-none}"
echo "New release:      $tag"
echo

"$root/scripts/set-version.sh" "$version" >/dev/null
cargo update --quiet --workspace --manifest-path "$root/opencli-rs/Cargo.toml"
cargo update --quiet --workspace --manifest-path "$root/desktop/src-tauri/Cargo.toml"

# The checks that would otherwise fail after the tag is pushed. Cheap here,
# expensive there.
echo "Checking the translations…"
python3 "$root/scripts/i18n-check.py"
python3 "$root/scripts/i18n-untranslated.py" >/dev/null
python3 "$root/scripts/connector-check.py" >/dev/null

echo "Checking formatting…"
(cd "$root/opencli-rs" && cargo fmt -- --config imports_granularity=Item --check >/dev/null 2>&1) || {
  echo "error: run 'cargo fmt' in opencli-rs first." >&2
  exit 1
}

git add -A
git commit --quiet --file - <<EOF
release $version

$(git log --format="- %s" "${previous:-HEAD~10}..HEAD" 2>/dev/null | head -30)
EOF

# The commit message the tag points at becomes the release notes, so the tag's
# own message is only for whoever reads `git show`.
git tag -a "$tag" -m "OpenCLI $version"

echo
echo "Committed and tagged $tag. Nothing has been pushed."
echo "Read the commit message — it becomes the release notes — then:"
echo
echo "    git push origin main $tag"
