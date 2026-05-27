#!/usr/bin/env bash
#
# Build + push the `ancilla-live/ancilla` Docker image to Docker Hub.
#
# Reads access token from ~/.local/share/ancilla-publishing/docker-hub.token
# (chmod 600). Uses docker login via stdin (token never appears in argv).
#
# Multi-arch: linux/amd64 + linux/arm64 via buildx.
#
# Usage:
#   ./scripts/publish-docker.sh             # build for local arch only (no push)
#   ./scripts/publish-docker.sh --confirm   # multi-arch buildx + push
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOKEN_FILE="$HOME/.local/share/ancilla-publishing/docker-hub.token"
NAMESPACE="ancilla-live"
IMAGE="ancilla"
VERSION="0.0.1"

red()    { printf '\033[1;31m%s\033[0m\n' "$1" >&2; }
green()  { printf '\033[1;32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$1"; }
bold()   { printf '\033[1m%s\033[0m\n' "$1"; }

cd "$REPO_ROOT"

if [[ "${1:-}" != "--confirm" ]]; then
    bold "→ Local-arch build (no push)..."
    docker build --platform=linux/amd64 -t "${NAMESPACE}/${IMAGE}:test" .
    green "✓ Local build successful: ${NAMESPACE}/${IMAGE}:test"
    echo
    docker run --rm "${NAMESPACE}/${IMAGE}:test" --version
    docker run --rm "${NAMESPACE}/${IMAGE}:test"
    echo
    yellow "To actually publish (multi-arch + push): ./scripts/publish-docker.sh --confirm"
    exit 0
fi

# === --confirm path: real push ===

[[ -f "$TOKEN_FILE" ]] || { red "✘ Token file not found: $TOKEN_FILE"; exit 1; }
perms=$(stat -c '%a' "$TOKEN_FILE")
[[ "$perms" == "600" ]] || { red "✘ Token permissions $perms != 600"; exit 1; }

# Set up buildx if needed
if ! docker buildx inspect ancilla-builder >/dev/null 2>&1; then
    bold "→ Creating buildx builder 'ancilla-builder'..."
    docker buildx create --name ancilla-builder --driver docker-container --use
fi
docker buildx use ancilla-builder

# Login via stdin (token never on argv / never in shell history)
bold "→ Logging in to Docker Hub as $NAMESPACE..."
cat "$TOKEN_FILE" | docker login -u "$NAMESPACE" --password-stdin docker.io

cleanup() {
    bold "→ Logging out..."
    docker logout docker.io || true
}
trap cleanup EXIT

bold "→ Multi-arch buildx + push..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t "${NAMESPACE}/${IMAGE}:${VERSION}" \
    -t "${NAMESPACE}/${IMAGE}:latest" \
    --push \
    .

green "✓ Pushed ${NAMESPACE}/${IMAGE}:${VERSION} (amd64 + arm64)"
green "  Verify: https://hub.docker.com/r/${NAMESPACE}/${IMAGE}"
echo
yellow "Next:"
yellow "  1. Revoke the token: https://hub.docker.com/settings/security"
yellow "  2. shred -u $TOKEN_FILE"
