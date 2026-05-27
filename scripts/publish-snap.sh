#!/usr/bin/env bash
#
# Build + publish the `ancilla` snap to the Snap Store.
#
# Prerequisites:
#   - Master is logged in to Snapcraft Store: `snapcraft login` (interactive)
#     OR has exported credentials: `snapcraft export-login --acls=package_access,package_push ~/.local/share/ancilla-publishing/snapcraft.creds`
#   - `ancilla` name registered: `snapcraft register ancilla`
#   - LXD or multipass installed for snap building
#
# Usage:
#   ./scripts/publish-snap.sh             # build only
#   ./scripts/publish-snap.sh --confirm   # build + upload to stable channel
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREDS_FILE="$HOME/.local/share/ancilla-publishing/snapcraft.creds"

red()    { printf '\033[1;31m%s\033[0m\n' "$1" >&2; }
green()  { printf '\033[1;32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$1"; }
bold()   { printf '\033[1m%s\033[0m\n' "$1"; }

if ! command -v snapcraft >/dev/null; then
    red "✘ snapcraft CLI not installed."
    red "  Install: sudo snap install snapcraft --classic"
    exit 1
fi

cd "$REPO_ROOT/snap"

bold "→ Building snap (this may take a few minutes)..."
snapcraft

SNAP_FILE=$(ls -t "$REPO_ROOT"/snap/*.snap 2>/dev/null | head -1)
[[ -f "$SNAP_FILE" ]] || { red "✘ No .snap file produced"; exit 1; }

green "✓ Built: $SNAP_FILE"
ls -la "$SNAP_FILE"

if [[ "${1:-}" != "--confirm" ]]; then
    yellow ""
    yellow "Build complete. To upload + release to stable channel:"
    yellow "  ./scripts/publish-snap.sh --confirm"
    exit 0
fi

bold "→ Uploading to Snap Store..."

if [[ -f "$CREDS_FILE" ]]; then
    perms=$(stat -c '%a' "$CREDS_FILE")
    [[ "$perms" == "600" ]] || { red "✘ creds file perms $perms != 600"; exit 1; }
    export SNAPCRAFT_STORE_CREDENTIALS=$(cat "$CREDS_FILE")
    cleanup() { unset SNAPCRAFT_STORE_CREDENTIALS; }
    trap cleanup EXIT
else
    yellow "⚠ No creds file at $CREDS_FILE — falling back to interactive login."
    yellow "  After this works once, run: snapcraft export-login --acls=package_access,package_push --snaps=ancilla $CREDS_FILE && chmod 600 $CREDS_FILE"
    snapcraft login
fi

bold "→ Uploading + releasing to stable..."
snapcraft upload --release=stable "$SNAP_FILE"

green "✓ Uploaded + released to stable channel."
green "  Verify: https://snapcraft.io/ancilla"
yellow ""
yellow "Test:  sudo snap install ancilla"
