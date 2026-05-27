# Publishing the `ancilla` status client

This document describes how to publish (or re-publish) the `ancilla` package to each registry.

**Secrets discipline:** all API tokens live in `~/.local/share/ancilla-publishing/` (mode 700, files mode 600). NEVER in this repo. NEVER in `~/.cargo/credentials.toml`. NEVER in shell history (use `$(cat …)` substitution; never paste tokens directly).

**Email used for registry accounts:** `registry@ancilla.live` (routed via Cloudflare to maintainer's inbox).

---

## §1 crates.io (Rust)

### Account setup (one-time)

1. Visit https://crates.io and click **Log in with GitHub**. Authenticate with the GitHub user that owns the `ancilla-live` org.
2. Visit https://crates.io/settings/profile → fill in:
   - **Email:** `registry@ancilla.live`
   - Confirm via the email link
3. Visit https://crates.io/settings/tokens → **New token**:
   - **Name:** `ancilla-publish-2026-05-27` (date-tagged so rotation is obvious)
   - **Scopes:** `publish-update` only
   - **Crates:** restrict to `ancilla` only (after first publish, before subsequent rotations)
   - **Expiry:** 30 days
4. Save the token to `~/.local/share/ancilla-publishing/crates-io.token`:
   ```bash
   install -m 600 /dev/null ~/.local/share/ancilla-publishing/crates-io.token
   $EDITOR ~/.local/share/ancilla-publishing/crates-io.token
   # paste token, save, close
   ```

### Publishing

```bash
cd ~/code/ancilla-live/ancilla-status-client
./scripts/publish-crates-io.sh             # dry-run first
./scripts/publish-crates-io.sh --confirm   # actually publishes
```

### Post-publish

1. Verify at https://crates.io/crates/ancilla
2. Test install in a sandbox:
   ```bash
   # In a throwaway VM or container, NOT your dev machine:
   cargo install ancilla
   ancilla --version
   ancilla
   ```
3. **Revoke** the publish token at https://crates.io/settings/tokens
4. Delete or rotate the local token: `rm ~/.local/share/ancilla-publishing/crates-io.token`

---

## §2 npm

### Account setup (one-time)

1. Visit https://www.npmjs.com/signup
2. Username: `ancilla` (claims the `ancilla` package owner; check availability first)
3. Email: `registry@ancilla.live`
4. Password: generate via password manager
5. Verify email
6. Enable 2FA: https://www.npmjs.com/settings/ancilla/profile → enable **Auth-only** 2FA (TOTP, not SMS)

### Token setup

1. Visit https://www.npmjs.com/settings/ancilla/tokens → **Generate New Token (Classic)**
2. Type: **Automation** (bypasses 2FA prompt for CI; otherwise need OTP per publish)
3. Save to `~/.local/share/ancilla-publishing/npm.token` (chmod 600)

### Publishing

```bash
cd ~/code/ancilla-live/ancilla-status-client/npm
# Note: a separate package.json + JS wrapper lives here (TBD; not yet written)
npm publish --access=public  # NPM_TOKEN read from env
```

(npm publishing requires a JS wrapper that downloads the Rust binary or a pure-JS reimplementation. To be written in a follow-up commit.)

---

## §3 PyPI

### Account setup (one-time)

1. Visit https://pypi.org/account/register/
2. Username: `ancilla-maintainer`
3. Email: `registry@ancilla.live`
4. Password: generate via password manager
5. Verify email
6. Enable 2FA (mandatory for new accounts): TOTP via authenticator app
7. **Set up Trusted Publisher (OIDC) instead of API tokens:**
   - Visit https://pypi.org/manage/account/publishing/
   - Add a pending publisher for project `ancilla`:
     - **Owner:** `ancilla-live`
     - **Repository:** `ancilla-status-client`
     - **Workflow:** `publish-pypi.yml`
     - **Environment:** `pypi-publish`
   - Save
8. After first publish, the pending-publisher becomes an active trusted publisher tied to the project.

### Publishing

Trusted publishing means GitHub Actions publishes directly — NO token on disk anywhere.

```yaml
# .github/workflows/publish-pypi.yml (in this repo)
name: Publish to PyPI
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to publish'
        required: true

jobs:
  publish:
    runs-on: ubuntu-latest
    environment: pypi-publish
    permissions:
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install build
      - run: python -m build
      - uses: pypa/gh-action-pypi-publish@release/v1
```

(A separate Python wrapper module is needed; TBD.)

---

## §4 Docker Hub

### Account setup (one-time)

1. Visit https://hub.docker.com/signup
2. Username: `ancilla` (claims the namespace)
3. Email: `registry@ancilla.live`
4. Password: generate via password manager
5. Verify email
6. Enable 2FA: https://hub.docker.com/settings/security → TOTP

### Token

1. Visit https://hub.docker.com/settings/security → **Access Tokens** → **New Access Token**
2. Description: `ancilla-publish-2026-05-27`
3. Permissions: **Read, Write, Delete** (or Read, Write if Delete not needed)
4. Save to `~/.local/share/ancilla-publishing/docker-hub.token` (chmod 600)

### Publishing

```bash
echo "$(cat ~/.local/share/ancilla-publishing/docker-hub.token)" \
  | docker login -u ancilla --password-stdin
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ancilla/ancilla:0.0.1 \
  -t ancilla/ancilla:latest \
  --push .
docker logout
```

(A `Dockerfile` is needed; TBD.)

---

## §5 Snapcraft

Account `ancillalive` registered 2026-05-27 with `registry@ancilla.live`. Snap name `ancilla` claimed via web (no CLI needed). Auto-build pipeline configured via https://snapcraft.io/build linked to `ancilla-live/ancilla-status-client` on GitHub. Builds queued on every push to main; releases to `latest/stable` channel on successful build.

`snapcraft.yaml` lives at repo root. Uses `core24` base with `platforms: amd64, arm64` (NOT the deprecated `architectures` key). Build plugin: `rust`. Confinement: `strict`. Plug: `network` only.

No local snap build infrastructure needed — Launchpad-via-Snapcraft does the work.

---

## §6 Launchpad PPA (apt)

Deferrable. Requires PGP key generation for signing. See `~/docs/projects/ancilla/PACKAGE_NAMESPACE_RESERVATION.md §2.2`.

---

## §7 Homebrew tap

Tap repo: https://github.com/ancilla-live/homebrew-ancilla (public, created 2026-05-27).

Formula: `Formula/ancilla.rb` — uses cargo to install from the crates.io tarball (SHA256 pinned). Requires `rust` as build dependency.

Install path for end users:
```bash
brew tap ancilla-live/ancilla
brew install ancilla
```

(Brew normalizes the `homebrew-ancilla` repo name to the `ancilla` tap.)

---

## §8 Flathub

Deferrable. Requires:
- Flatpak manifest in a separate repo
- DNS-TXT verification of `ancilla.live`
- Submission PR to `flathub/flathub`

Not urgent pre-launch.

---

## §9 Token rotation cadence

| Registry | Cadence | Trigger |
|---|---|---|
| crates.io | Per-publish + 30-day default | Revoke immediately after publish |
| npm | Per-publish + 90-day | Revoke after publish |
| PyPI | N/A — OIDC trusted publishing | No tokens to rotate |
| Docker Hub | 90-day | Revoke when expired |
| Snapcraft | 90-day | Revoke when expired |

---

## §10 Audit log

Append each publish to the bottom of this file. Date, version, registry, status.

| Date | Version | Registry | Status | Notes |
|---|---|---|---|---|
| 2026-05-27 | 0.0.1 | crates.io | ✅ live | Published as `ancilla`. https://crates.io/crates/ancilla. License-file pointer; no SPDX commitment. |
| 2026-05-27 | 0.0.1 | npm | ✅ live | Published as `ancilla` under user `covenator`. https://www.npmjs.com/package/ancilla. JS implementation (stdlib `fetch`). Bypass-2FA Granular token used + revoked post-publish. |
| 2026-05-27 | 0.0.1 | PyPI | ✅ live | Published as `ancilla-live` (bare `ancilla` taken by an unrelated quant-finance lib). https://pypi.org/project/ancilla-live/. Trusted Publishing (OIDC) — zero tokens on disk. |
| 2026-05-27 | 0.0.1 | Docker Hub | ✅ live | Published as `ancillalive/ancilla` (bare `ancilla` taken since 2015). https://hub.docker.com/r/ancillalive/ancilla. Multi-arch amd64 + arm64. Alpine 3.20 base, ~18 MB. |
| 2026-05-27 | 0.0.1 | Homebrew tap | ✅ live | Tap at `ancilla-live/homebrew-ancilla`. Cargo-build formula. |
| 2026-05-27 | 0.0.1 | Snap Store | ⏳ building | Snap name `ancilla` registered under publisher `ancillalive`. Auto-build via Snapcraft GitHub integration triggered on commit `758f9bb`. Builds for amd64 + arm64. |
