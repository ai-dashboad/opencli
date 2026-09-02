#!/usr/bin/env sh
# Install the OpenCLI command-line agent.
#
#   curl -fsSL https://opencli.ai/install.sh | sh
#
# Deliberately POSIX `sh`, not bash: this is the first thing anyone runs, and
# it has to work on a minimal container as well as on a Mac.
#
# It does one thing — put a single binary somewhere on PATH — and says exactly
# what it did. No shell profile is edited behind the user's back; if the
# directory it lands in is not on PATH, the script says so and stops short of
# pretending the install worked.
set -eu

REPO="ai-dashboad/opencli"
VERSION="${OPENCLI_VERSION:-latest}"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "this needs $1, which is not installed"
}

# Which build to fetch.
#
# Linux gets the musl build: it is statically linked, so it runs on
# distributions whose glibc is older than the one it was built against, which
# is the failure people hit and cannot diagnose.
target_triple() {
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os" in
    Darwin)
      case "$arch" in
        arm64|aarch64) echo "aarch64-apple-darwin" ;;
        x86_64) echo "x86_64-apple-darwin" ;;
        *) die "unsupported macOS architecture: $arch" ;;
      esac
      ;;
    Linux)
      case "$arch" in
        aarch64|arm64) echo "aarch64-unknown-linux-musl" ;;
        x86_64|amd64) echo "x86_64-unknown-linux-musl" ;;
        *) die "unsupported Linux architecture: $arch" ;;
      esac
      ;;
    MINGW*|MSYS*|CYGWIN*)
      die "on Windows, download the installer from https://opencli.ai/download"
      ;;
    *)
      die "unsupported operating system: $os"
      ;;
  esac
}

# Where to put it: the first directory that already exists and is writable.
# Never created with sudo — a script that escalates privileges without being
# asked is not one to pipe into a shell.
install_dir() {
  if [ -n "${OPENCLI_INSTALL_DIR:-}" ]; then
    echo "$OPENCLI_INSTALL_DIR"
  elif [ -w /usr/local/bin ] 2>/dev/null; then
    echo /usr/local/bin
  else
    echo "$HOME/.local/bin"
  fi
}

need uname
need tar
if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO "$2" "$1"; }
else
  die "this needs curl or wget, and neither is installed"
fi

triple="$(target_triple)"
asset="opencli-${triple}.tar.gz"
# An explicit URL wins, for a mirror or a machine that cannot reach GitHub.
if [ -n "${OPENCLI_DOWNLOAD_URL:-}" ]; then
  url="$OPENCLI_DOWNLOAD_URL"
elif [ "$VERSION" = "latest" ]; then
  url="https://github.com/${REPO}/releases/latest/download/${asset}"
else
  url="https://github.com/${REPO}/releases/download/v${VERSION}/${asset}"
fi

tmp="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$tmp'" EXIT INT TERM

say "Downloading OpenCLI for ${triple}…"
fetch "$url" "$tmp/$asset" || die "could not download $url"

tar -xzf "$tmp/$asset" -C "$tmp" || die "the download could not be unpacked"
[ -f "$tmp/opencli-${triple}" ] || die "the archive did not contain the expected binary"

dir="$(install_dir)"
mkdir -p "$dir" || die "could not create $dir"
mv "$tmp/opencli-${triple}" "$dir/opencli" || die "could not write to $dir"
chmod +x "$dir/opencli"

# macOS quarantines anything downloaded, and these builds are not notarised.
# Clearing the attribute on a file the user just asked for is the whole reason
# this script is friendlier than downloading by hand.
if [ "$(uname -s)" = "Darwin" ] && command -v xattr >/dev/null 2>&1; then
  xattr -d com.apple.quarantine "$dir/opencli" 2>/dev/null || true
fi

say "Installed to $dir/opencli"

case ":$PATH:" in
  *":$dir:"*)
    say ""
    say "Run 'opencli' to start."
    ;;
  *)
    say ""
    say "$dir is not on your PATH. Add this to your shell profile:"
    say ""
    say "    export PATH=\"$dir:\$PATH\""
    ;;
esac
