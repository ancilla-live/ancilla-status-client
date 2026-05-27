#!/usr/bin/env bash
#
# Build + upload the `ancilla` source package to Launchpad PPA.
#
# Prerequisites:
#   - PGP key for registry@ancilla.live in ~/.gnupg
#   - Public key uploaded to keyserver.ubuntu.com + registered on Launchpad profile
#   - PPA activated at https://launchpad.net/~<user>/+archive/ubuntu/ancilla
#   - dput-ng installed: sudo apt install dput-ng
#   - Build deps: sudo apt install devscripts debhelper rustc cargo quilt
#
# Usage:
#   ./scripts/publish-ppa.sh                    # build source package; no upload
#   ./scripts/publish-ppa.sh --confirm <user>   # build + dput upload (uses ppa:<user>/ancilla)
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

red()    { printf '\033[1;31m%s\033[0m\n' "$1" >&2; }
green()  { printf '\033[1;32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$1"; }
bold()   { printf '\033[1m%s\033[0m\n' "$1"; }

# Check required tools
for cmd in debuild dpkg-buildpackage debchange dput; do
    if ! command -v $cmd >/dev/null 2>&1; then
        red "✘ Missing: $cmd"
        red "  Install: sudo apt install devscripts debhelper dput-ng quilt"
        exit 1
    fi
done

# Verify the maintainer key exists
KEY_EMAIL="registry@ancilla.live"
if ! gpg --list-secret-keys "$KEY_EMAIL" >/dev/null 2>&1; then
    red "✘ No GPG secret key for $KEY_EMAIL"
    red "  Generate: gpg --quick-generate-key 'Ancilla maintainer <$KEY_EMAIL>' rsa4096 sign 2y"
    exit 1
fi

# Build source package (-S = source-only; -sa = include orig.tar.gz; -d = skip build-deps
# check since we're not building binaries locally — Launchpad does that).
bold "→ Building source package..."
debuild -S -sa -d -k"$KEY_EMAIL"

# Show what was built
green "✓ Source package built:"
ls -la ../ancilla_*.changes ../ancilla_*.dsc ../ancilla_*_source.changes 2>/dev/null || true

if [[ "${1:-}" != "--confirm" ]]; then
    yellow ""
    yellow "Source package built but NOT uploaded."
    yellow "To upload to a PPA:"
    yellow "  ./scripts/publish-ppa.sh --confirm <launchpad-username>"
    yellow ""
    yellow "Example: ./scripts/publish-ppa.sh --confirm ancillalive"
    exit 0
fi

PPA_USER="${2:-}"
if [[ -z "$PPA_USER" ]]; then
    red "✘ Pass Launchpad username as second arg: --confirm <user>"
    exit 1
fi

CHANGES_FILE=$(ls -t ../ancilla_*_source.changes 2>/dev/null | head -1)
[[ -f "$CHANGES_FILE" ]] || { red "✘ No source.changes file found"; exit 1; }

bold "→ Uploading $CHANGES_FILE to ppa:$PPA_USER/ancilla..."
dput "ppa:$PPA_USER/ancilla" "$CHANGES_FILE"

green "✓ Uploaded. Track build at: https://launchpad.net/~$PPA_USER/+archive/ubuntu/ancilla/+packages"
yellow ""
yellow "Launchpad will build for noble (and any other configured series) in 10-30 min."
yellow "On success, users add the PPA + install:"
yellow "  sudo add-apt-repository ppa:$PPA_USER/ancilla"
yellow "  sudo apt update && sudo apt install ancilla"
