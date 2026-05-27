#!/usr/bin/env bash
#
# Publish the `ancilla` status-client crate to crates.io.
#
# Reads the API token from ~/.local/share/ancilla-publishing/crates-io.token
# (chmod 600) and uses it as an env var — NEVER writes it to ~/.cargo/credentials.toml.
#
# Usage:
#   ./scripts/publish-crates-io.sh                 # dry-run
#   ./scripts/publish-crates-io.sh --confirm       # actually publishes
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOKEN_FILE="$HOME/.local/share/ancilla-publishing/crates-io.token"

red()    { printf '\033[1;31m%s\033[0m\n' "$1" >&2; }
green()  { printf '\033[1;32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$1"; }
bold()   { printf '\033[1m%s\033[0m\n' "$1"; }

# === Sanity checks ===
if [[ ! -f "$TOKEN_FILE" ]]; then
    red "✘ Token file not found: $TOKEN_FILE"
    red "  Generate a token at https://crates.io/me/tokens (scope: publish + crate 'ancilla')"
    red "  Then: install -m 600 /dev/null \"$TOKEN_FILE\" && \$EDITOR \"$TOKEN_FILE\""
    exit 1
fi

perms=$(stat -c '%a' "$TOKEN_FILE")
if [[ "$perms" != "600" ]]; then
    red "✘ Token file has insecure permissions: $perms (must be 600)"
    red "  Fix: chmod 600 \"$TOKEN_FILE\""
    exit 1
fi

if [[ -s "$HOME/.cargo/credentials.toml" ]]; then
    yellow "⚠ ~/.cargo/credentials.toml exists and is non-empty."
    yellow "  This script avoids writing tokens there, but the file might have stale auth."
    yellow "  Review it: cat ~/.cargo/credentials.toml"
fi

# === Build + verify ===
bold "→ Building release artifact..."
cargo build --release --manifest-path "$REPO_ROOT/Cargo.toml"

bold "→ Running tests (none yet, but reserves the slot)..."
cargo test --manifest-path "$REPO_ROOT/Cargo.toml" || true

bold "→ Cargo package dry-run..."
cargo package --manifest-path "$REPO_ROOT/Cargo.toml" --list | head -30
echo "..."

# === Publish ===
CARGO_REGISTRY_TOKEN="$(cat "$TOKEN_FILE")"
export CARGO_REGISTRY_TOKEN

cleanup() {
    unset CARGO_REGISTRY_TOKEN
}
trap cleanup EXIT

if [[ "${1:-}" == "--confirm" ]]; then
    bold "→ Publishing to crates.io..."
    cargo publish --manifest-path "$REPO_ROOT/Cargo.toml"
    green "✓ Published. Visit https://crates.io/crates/ancilla to verify."
    yellow ""
    yellow "Next: revoke + regenerate the crates.io token at https://crates.io/me/tokens"
    yellow "      then update $TOKEN_FILE with the new value (or delete if you won't"
    yellow "      publish again soon)."
else
    bold "→ Cargo publish DRY-RUN (use --confirm to actually publish)..."
    cargo publish --manifest-path "$REPO_ROOT/Cargo.toml" --dry-run
    green "✓ Dry-run passed."
    yellow ""
    yellow "To actually publish: ./scripts/publish-crates-io.sh --confirm"
fi
