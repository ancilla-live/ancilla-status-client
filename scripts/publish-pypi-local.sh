#!/usr/bin/env bash
#
# Local PyPI publish — fallback only.
#
# The PRIMARY way to publish to PyPI is the GitHub Actions workflow at
# `.github/workflows/publish-pypi.yml` which uses OIDC trusted publishing
# (no token on disk). Use THIS script only if the GitHub Actions path is
# broken or unavailable.
#
# Reads token from ~/.local/share/ancilla-publishing/pypi.token (chmod 600).
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY_DIR="$REPO_ROOT/python"
TOKEN_FILE="$HOME/.local/share/ancilla-publishing/pypi.token"

red()    { printf '\033[1;31m%s\033[0m\n' "$1" >&2; }
green()  { printf '\033[1;32m%s\033[0m\n' "$1"; }
yellow() { printf '\033[1;33m%s\033[0m\n' "$1"; }
bold()   { printf '\033[1m%s\033[0m\n' "$1"; }

if [[ ! -f "$TOKEN_FILE" ]]; then
    red "✘ Token file not found: $TOKEN_FILE"
    red "  Generate at https://pypi.org/manage/account/token/"
    red "  Then: install -m 600 /dev/null \"$TOKEN_FILE\" && \$EDITOR \"$TOKEN_FILE\""
    red ""
    red "  IMPORTANT: Prefer the GitHub Actions OIDC workflow instead."
    red "  This script is fallback only."
    exit 1
fi

perms=$(stat -c '%a' "$TOKEN_FILE")
[[ "$perms" == "600" ]] || { red "✘ Token permissions $perms != 600"; exit 1; }

if [[ -s "$HOME/.pypirc" ]]; then
    yellow "⚠ ~/.pypirc exists. This script bypasses it via env var."
fi

# Build
bold "→ Setting up build venv..."
VENV=$(mktemp -d)
trap 'rm -rf "$VENV"' EXIT
python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip build twine

bold "→ Building sdist + wheel..."
cd "$PY_DIR"
rm -rf dist/ build/ ancilla.egg-info/
"$VENV/bin/python" -m build

bold "→ Validating with twine..."
"$VENV/bin/twine" check --strict dist/*

bold "→ Files to be uploaded:"
ls -la dist/

# Publish
TWINE_USERNAME=__token__
TWINE_PASSWORD="$(cat "$TOKEN_FILE")"
export TWINE_USERNAME TWINE_PASSWORD

cleanup() { unset TWINE_USERNAME TWINE_PASSWORD; rm -rf "$VENV"; }
trap cleanup EXIT

if [[ "${1:-}" == "--confirm" ]]; then
    bold "→ Uploading to PyPI..."
    "$VENV/bin/twine" upload dist/*
    green "✓ Published. Visit https://pypi.org/project/ancilla/ to verify."
    yellow ""
    yellow "Next: revoke this token at https://pypi.org/manage/account/token/"
    yellow "      then: shred -u $TOKEN_FILE"
else
    bold "→ Dry-run (twine check passed; no upload)..."
    green "✓ Dry-run passed."
    yellow ""
    yellow "To actually publish: ./scripts/publish-pypi-local.sh --confirm"
fi
