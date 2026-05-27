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

Deferrable. Requires Ubuntu One account + `snap register ancilla` within 6 months of intent. Not urgent for namespace-claim purposes — Snap is a lower squat-risk than crates.io/npm/PyPI.

---

## §6 Launchpad PPA (apt)

Deferrable. Requires PGP key generation for signing. See `~/docs/projects/ancilla/PACKAGE_NAMESPACE_RESERVATION.md §2.2`.

---

## §7 Homebrew tap

Just create the repo `github.com/ancilla-live/homebrew-ancilla` with a `Formula/ancilla.rb` file. No external account needed; tied to the GitHub org. Deferrable until a release binary exists to download.

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
| _pending_ | 0.0.1 | crates.io | not yet | first publish |
