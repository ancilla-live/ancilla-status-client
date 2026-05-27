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

Live at `ppa:ancillalive/ancilla`. Source uploaded + accepted 2026-05-27; Launchpad builds binaries for `noble` (Ubuntu 24.04 LTS) on its servers (~30 min per arch).

### What's in the source package
- `debian/control` — package metadata + build-deps (rustc + cargo from apt)
- `debian/rules` — cargo-based build via debhelper
- `debian/changelog` — versioned `0.0.1-1~noble1` (suffix `~noble1` per Ubuntu PPA convention)
- `debian/copyright` — "see ancilla.live" (matches license-rescission posture)
- `debian/patches/0001-debian-toolchain-compat.patch` — downgrades upstream Cargo.toml from edition 2024 / rust-version 1.85 to edition 2021 / rust-version 1.74, so Ubuntu noble's stock rustc 1.75 can build it. (Code uses no edition-2024-specific features.)
- `debian/source/format` — `3.0 (quilt)`

### Signing
- Maintainer GPG key: `B5FDA55399F4E5184D42063F5C5367E051A11731` (RSA4096; SC + encrypt subkey; expires 2028-05-26)
- UID: `Ancilla maintainer <registry@ancilla.live>`
- Key on `keyserver.ubuntu.com`; registered at https://launchpad.net/~ancillalive/+editpgpkeys
- Passphrase: stored in Master's password manager
- Private key location: `~/.gnupg/` (mode 700, owner-only)

### Rebuild + re-upload procedure
```bash
cd ~/code/ancilla-live/ancilla-status-client

# Sanity: ensure Cargo.toml is unpatched (edition=2024) before building orig.tar.gz
quilt pop -a 2>/dev/null || true

# Rebuild orig.tar.gz from CURRENT (clean) source
cp -r . /tmp/ancilla-0.0.1
find /tmp/ancilla-0.0.1/.git -delete 2>/dev/null
find /tmp/ancilla-0.0.1/target -delete 2>/dev/null
find /tmp/ancilla-0.0.1/debian -delete 2>/dev/null
tar czf ../ancilla_0.0.1.orig.tar.gz -C /tmp ancilla-0.0.1
find /tmp/ancilla-0.0.1 -delete

# Build source package + sign
./scripts/publish-ppa.sh

# Remove dput tracker file if re-uploading
rm -f ../ancilla_*~noble*_source.ppa.upload

# Upload
./scripts/publish-ppa.sh --confirm ancillalive
```

### Install path for users (after Launchpad finishes building)
```bash
sudo add-apt-repository ppa:ancillalive/ancilla
sudo apt update
sudo apt install ancilla
```

### Common rejection causes
- **"Reversed (or previously applied) patch detected"** → Cargo.toml in orig.tar.gz is in patched state. Run `quilt pop -a` before building orig.tar.gz.
- **"Package was already uploaded to ppa"** → dput tracker file from previous attempt blocks re-upload. Delete `../ancilla_*_source.ppa.upload` and retry.

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
| Snapcraft | N/A — `snapcraft login` keeps creds in snapd keyring | `snapcraft logout` when done |
| Launchpad PPA | GPG key rotated annually | Renew `gpg --quick-add-key` on expiry; re-upload to keyserver.ubuntu.com |

## §9.5 Pending Master-side revocations (2026-05-27)

These tokens were used during initial publish; should be revoked at the registry side:

- [ ] **crates.io** — revoke `ancilla-first-publish-2026-05-27` at https://crates.io/settings/tokens
- [ ] **npm** — revoke `ancilla-first-publish-2026-05-27` at https://www.npmjs.com/settings/covenator/tokens
- [ ] **Docker Hub** — revoke `ancilla-publish-2026-05-27` at https://hub.docker.com/settings/security
- [ ] **Cloudflare** — revoke the temporary "ancilla" API token at https://dash.cloudflare.com/profile/api-tokens (used once for email-routing rule)
- [ ] **Cloudflare tunnel** — rotate the cloudflared tunnel credentials inadvertently echoed during early discovery; at Cloudflare dashboard → Networks → Tunnels

Local copies of tokens already shredded — registry-side revocation is independent.

---

## §9.6 Identity discipline (locked 2026-05-27)

After an initial security audit on 2026-05-27 found Master's personal Gmail address + real name in the git commit history of two public repos (`ancilla-status-client` + `homebrew-ancilla`), the following hardening was applied:

1. **Global git config:** `user.email` set to `13875865+covenator@users.noreply.github.com` (the GitHub noreply form). All FUTURE commits across the user's entire system default to this. Personal-email opt-in requires explicit repo-local override.
2. **Repo-local config:** the two affected repos have explicit `user.email` + `user.name = covenator` for belt-and-braces.
3. **Cleanup:** the two affected repos were rewritten with `git filter-repo --email-callback --name-callback` (mapping `rjaswant6@gmail.com` → noreply form; `Jaswant R` → `covenator`), then **deleted + recreated** to fully wipe the orphan commit objects from GitHub's server (the alternative force-GC-via-Support route was not needed). The recreate preserved repo NAME + description + topics + visibility, so all URL-based downstream automations (crates.io repo link, npm repo link, PyPI repo link, Docker Hub link, Homebrew formula source) continued to work. The `pypi-publish` GitHub Environment was recreated for OIDC Trusted Publishing.

**Lesson for future public-repo work:** always verify `git config user.email` shows the noreply form before the first commit on a public repo. The pre-push safety hook in `~/projects/ancilla/scripts/git-hooks/pre-push` should be extended to fail-loud on personal-email commits (TODO).

## §10 Audit log

Append each publish to the bottom of this file. Date, version, registry, status.

| Date | Version | Registry | Status | Notes |
|---|---|---|---|---|
| 2026-05-27 | 0.0.1 | crates.io | ✅ live | Published as `ancilla`. https://crates.io/crates/ancilla. License-file pointer; no SPDX commitment. |
| 2026-05-27 | 0.0.1 | npm | ✅ live | Published as `ancilla` under user `covenator`. https://www.npmjs.com/package/ancilla. JS implementation (stdlib `fetch`). Bypass-2FA Granular token used + revoked post-publish. |
| 2026-05-27 | 0.0.1 | PyPI | ✅ live | Published as `ancilla-live` (bare `ancilla` taken by an unrelated quant-finance lib). https://pypi.org/project/ancilla-live/. Trusted Publishing (OIDC) — zero tokens on disk. |
| 2026-05-27 | 0.0.1 | Docker Hub | ✅ live | Published as `ancillalive/ancilla` (bare `ancilla` taken since 2015). https://hub.docker.com/r/ancillalive/ancilla. Multi-arch amd64 + arm64. Alpine 3.20 base, ~18 MB. |
| 2026-05-27 | 0.0.1 | Homebrew tap | ✅ live | Tap at `ancilla-live/homebrew-ancilla`. Cargo-build formula. |
| 2026-05-27 | 0.0.1 | Launchpad PPA | ⏳ building | Source accepted to `ppa:ancillalive/ancilla` 2026-05-27 ~19:07 IST after fix of orig.tar.gz cleanliness. Launchpad builds amd64 + arm64 binaries. GPG-signed by maintainer key `B5FDA553...A11731`. |
| 2026-05-27 | 0.0.1 | Snap Store | ⏳ remote-building | Snap name `ancilla` registered under publisher `ancillalive`. Initial Snapcraft Build Service (GitHub-connected) succeeded on Launchpad but artifacts never auto-uploaded to store. Switched to local `snapcraft remote-build` flow + manual `snapcraft upload`. |
