"""ancilla — status client for the Ancilla platform (PyPI distribution).

Fetches https://ancilla.live/.well-known/ancilla-status.json and renders
a human-readable summary. ``--json`` prints raw JSON. ``--version`` and
``--help`` work offline.

Stdlib-only; no external dependencies.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

from . import __version__

STATUS_URL = "https://ancilla.live/.well-known/ancilla-status.json"
TIMEOUT_SEC = 5
USER_AGENT = f"ancilla-status-client/{__version__} (pypi)"


def cache_path() -> Path:
    base = os.environ.get("XDG_CACHE_HOME")
    if base:
        root = Path(base)
    else:
        root = Path.home() / ".cache"
    return root / "ancilla" / "last-status.json"


def read_cache() -> str | None:
    try:
        return cache_path().read_text(encoding="utf-8")
    except OSError:
        return None


def write_cache(text: str) -> None:
    try:
        p = cache_path()
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
    except OSError:
        pass  # non-fatal


def fetch_status() -> str:
    req = urllib.request.Request(STATUS_URL, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as resp:
        if resp.status != 200:
            raise RuntimeError(f"HTTP {resp.status}")
        return resp.read().decode("utf-8")


def wrap(text: str, width: int) -> str:
    out_lines: list[str] = []
    for para in text.split("\n"):
        if not para:
            out_lines.append("")
            continue
        words = para.split()
        line = ""
        for w in words:
            if line and len(line) + len(w) + 1 > width:
                out_lines.append(line)
                line = ""
            if line:
                line += " "
            line += w
        if line:
            out_lines.append(line)
    return "\n".join(out_lines)


def render_human(status: dict) -> None:
    print(f"Ancilla — {status.get('phase_label', '')}")
    print(f"Phase: {status.get('phase', '')}  ·  Last updated: {status.get('last_updated', '')}")
    eta = status.get("release_eta")
    if eta:
        print(f"Release ETA: {eta}")
    elif status.get("release_status") == "no-release":
        print("Release ETA: not announced")
    print()
    print(status.get("headline", ""))
    details = status.get("details")
    if details:
        print()
        print(wrap(details, 72))
    warning = status.get("warning")
    if warning:
        print()
        wrapped = wrap(warning, 70).split("\n")
        for i, line in enumerate(wrapped):
            print(("⚠ " if i == 0 else "  ") + line)
    print()
    links = status.get("links", {}) or {}
    label_map = [
        ("Home:", links.get("home")),
        ("GitHub:", links.get("github")),
        ("Reddit:", links.get("reddit")),
        ("X:", links.get("x")),
        ("Email:", links.get("email")),
        ("Security:", links.get("security")),
    ]
    for label, value in label_map:
        if value:
            print(f"  {label:<10}{value}")
    print()
    print("(Run `ancilla --json` for raw status. `ancilla --version` for client version.)")


def render(text: str, as_json: bool) -> None:
    if as_json:
        try:
            parsed = json.loads(text)
            print(json.dumps(parsed, indent=2, sort_keys=True))
        except json.JSONDecodeError:
            print(text)
        return
    try:
        parsed = json.loads(text)
        render_human(parsed)
    except json.JSONDecodeError as e:
        print(f"Status JSON did not parse: {e}", file=sys.stderr)
        print(f"Raw response:\n{text}", file=sys.stderr)


def print_help() -> None:
    print(
        """\
ancilla — status client for the Ancilla platform

USAGE:
    ancilla              Print the current Ancilla project status
    ancilla --json       Print the raw status JSON
    ancilla --version    Print this client's version
    ancilla --help       Print this help

ABOUT:
    This binary is a small status client, not the Ancilla platform itself.
    It fetches the live project status from https://ancilla.live and
    renders it.

    The Ancilla platform is in active development. See https://ancilla.live
    for the current status and project details.

    Pre-release Ancilla code, when shared privately, is sandbox-only —
    never run with real personal data."""
    )


def fetch_and_print(as_json: bool) -> int:
    try:
        text = fetch_status()
        write_cache(text)
        render(text, as_json)
        return 0
    except (urllib.error.URLError, urllib.error.HTTPError, RuntimeError, OSError, TimeoutError) as e:
        print(f"Could not reach {STATUS_URL}: {e}", file=sys.stderr)
        cached = read_cache()
        if cached:
            print("Showing last cached status:\n", file=sys.stderr)
            render(cached, as_json)
            return 2
        print(
            "No cached status available. Visit https://ancilla.live in a browser.",
            file=sys.stderr,
        )
        return 1


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    arg = args[0] if args else None

    if arg in ("--version", "-V"):
        print(
            f"ancilla {__version__} "
            f"(status client — not the Ancilla platform; see https://ancilla.live)"
        )
        return 0
    if arg in ("--help", "-h"):
        print_help()
        return 0
    if arg == "--json":
        return fetch_and_print(as_json=True)
    if arg is None:
        return fetch_and_print(as_json=False)
    print(f"Unknown argument: {arg}\n", file=sys.stderr)
    print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
