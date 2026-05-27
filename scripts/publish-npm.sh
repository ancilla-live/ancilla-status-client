#!/usr/bin/env bash
#
# Publish the `ancilla` status-client to npm.
#
# Reads NPM token from ~/.local/share/ancilla-publishing/npm.token (chmod 600)
# and uses it via env var — NEVER writes to ~/.npmrc on disk.
#
# Usage:
#   ./scripts/publish-npm.sh                # dry-run (npm pack)
#   ./scripts/publish-npm.sh --confirm      # actually publishes
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NPM_DIR="$REPO_ROOT/npm"
TOKEN_FILE="$HOME/.local/share/ancilla-publishing/npm.token"

red()    { printf '\033[1;31m%s\033[0m\n' "$1" >&2; }
green()  { printf '\033[1;32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$1"; }
bold()   { printf '\033[1m%s\033[0m\n' "$1"; }

# === Sanity checks ===
[[ -d "$NPM_DIR" ]] || { red "✘ npm/ dir not found"; exit 1; }

if [[ ! -f "$TOKEN_FILE" ]]; then
    red "✘ Token file not found: $TOKEN_FILE"
    red "  Generate at https://www.npmjs.com/settings/<user>/tokens"
    red "  Type: 'Automation' (bypasses 2FA prompt for CI)"
    red "  Then: install -m 600 /dev/null \"$TOKEN_FILE\" && \$EDITOR \"$TOKEN_FILE\""
    exit 1
fi

perms=$(stat -c '%a' "$TOKEN_FILE")
if [[ "$perms" != "600" ]]; then
    red "✘ Token file has insecure permissions: $perms (must be 600)"
    exit 1
fi

if [[ -s "$HOME/.npmrc" ]] && grep -q "_authToken" "$HOME/.npmrc" 2>/dev/null; then
    yellow "⚠ ~/.npmrc has _authToken set. This script bypasses it via env var, but consider clearing."
fi

# === Pre-flight: lint package.json + show what'll be published ===
bold "→ Validating package.json..."
node -e "JSON.parse(require('node:fs').readFileSync('$NPM_DIR/package.json'))" \
    && green "✓ package.json parses"

bold "→ Listing files that would be published..."
cd "$NPM_DIR"
npm pack --dry-run 2>&1 | grep -E '^npm notice'

# === Publish ===
TOKEN_VAL="$(cat "$TOKEN_FILE")"
export NODE_AUTH_TOKEN="$TOKEN_VAL"
export NPM_TOKEN="$TOKEN_VAL"

cleanup() {
    unset NODE_AUTH_TOKEN NPM_TOKEN TOKEN_VAL
}
trap cleanup EXIT

# Use temp .npmrc that just references env, never written to disk persistently
TMP_NPMRC="$(mktemp)"
trap 'rm -f "$TMP_NPMRC"; cleanup' EXIT
echo "//registry.npmjs.org/:_authToken=\${NPM_TOKEN}" > "$TMP_NPMRC"

if [[ "${1:-}" == "--confirm" ]]; then
    bold "→ Publishing to npm..."
    npm publish --userconfig "$TMP_NPMRC" --access=public
    green "✓ Published. Visit https://www.npmjs.com/package/ancilla to verify."
    yellow ""
    yellow "Next:"
    yellow "  1. Revoke this token at https://www.npmjs.com/settings/<user>/tokens"
    yellow "  2. Delete the local copy: shred -u $TOKEN_FILE"
else
    bold "→ Dry-run (npm publish --dry-run)..."
    npm publish --userconfig "$TMP_NPMRC" --access=public --dry-run
    green "✓ Dry-run passed."
    yellow ""
    yellow "To actually publish: ./scripts/publish-npm.sh --confirm"
fi
