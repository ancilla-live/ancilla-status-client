# `ancilla` — status client

A small command-line client that fetches the current development status of the [Ancilla](https://ancilla.live) platform from `https://ancilla.live/.well-known/ancilla-status.json` and prints it.

**This is not the Ancilla platform itself.** The Ancilla platform is in active development; no code has been released yet. This client exists so people who hear about Ancilla can run `ancilla` and see the current status without checking the website.

## Install

```bash
pip install ancilla-live
```

(The PyPI distribution is `ancilla-live` because `ancilla` is taken by an unrelated quantitative-finance library. The installed CLI is still `ancilla`. Also available as `cargo install ancilla` and `npm i -g ancilla` — see [ancilla.live](https://ancilla.live) for all channels.)

## Usage

```
$ ancilla
Ancilla — In active development
Phase: active-development  ·  Last updated: 2026-05-27

Ancilla is in active development. No code has been released yet.

Six-pillar local-first personal AI platform (Mission Control, Bastion, Nexus,
Aegis, Beacon, Lens). Specification phase complete; implementation pending.
The maintainer will release code only when satisfied with quality and security.

⚠ Pre-release code, when shared privately, is sandbox-only — never run with
  real personal data. Expect compromise, leakage, or corruption.

  Home:    https://ancilla.live
  GitHub:  https://github.com/ancilla-live
  Reddit:  https://reddit.com/r/ancilla_live
  X:       https://x.com/ancilla_live
  Email:   hello@ancilla.live

(Run `ancilla --json` for raw status. `ancilla --version` for client version.)
```

- `ancilla` — human-readable status
- `ancilla --json` — raw status JSON
- `ancilla --version` — client version
- `ancilla --help` — help

## Behaviour

- Fetches `https://ancilla.live/.well-known/ancilla-status.json` with a 5-second timeout
- Caches the last successful response at `$XDG_CACHE_HOME/ancilla/last-status.json` (or `~/.cache/ancilla/`)
- If the fetch fails, falls back to the cached response and exits 2 to signal stale data
- If no cache exists, exits 1 and points the user at the website

## Dependencies

Minimal by design:
- [`ureq`](https://crates.io/crates/ureq) — pure-Rust HTTP, no async runtime
- [`serde`](https://crates.io/crates/serde) + [`serde_json`](https://crates.io/crates/serde_json) — parsing

## Source

This repo: [github.com/ancilla-live/ancilla-status-client](https://github.com/ancilla-live/ancilla-status-client)

The full Ancilla platform repo (currently a placeholder): [github.com/ancilla-live/ancilla](https://github.com/ancilla-live/ancilla)

## Status

Pre-release. The Ancilla platform itself is not published. Visit [ancilla.live](https://ancilla.live) for current status.
