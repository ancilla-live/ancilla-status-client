#!/usr/bin/env node
//
// ancilla — status client for the Ancilla platform (npm distribution)
//
// Fetches https://ancilla.live/.well-known/ancilla-status.json and prints
// a human-readable summary. `--json` prints raw JSON. `--version` and
// `--help` work offline.
//
// This binary is not the Ancilla platform itself. See https://ancilla.live.
//

'use strict';

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const PKG = require('../package.json');
const STATUS_URL = 'https://ancilla.live/.well-known/ancilla-status.json';
const TIMEOUT_MS = 5000;
const USER_AGENT = `ancilla-status-client/${PKG.version} (npm)`;

const CACHE_DIR = path.join(
  process.env.XDG_CACHE_HOME || path.join(os.homedir(), '.cache'),
  'ancilla',
);
const CACHE_PATH = path.join(CACHE_DIR, 'last-status.json');

function printHelp() {
  console.log(`ancilla — status client for the Ancilla platform

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
    never run with real personal data.`);
}

function wrap(text, width) {
  return text.split('\n').map(para => {
    if (!para) return '';
    const words = para.split(/\s+/).filter(Boolean);
    const lines = [];
    let line = '';
    for (const w of words) {
      if (line.length + w.length + 1 > width && line) {
        lines.push(line);
        line = '';
      }
      if (line) line += ' ';
      line += w;
    }
    if (line) lines.push(line);
    return lines.join('\n');
  }).join('\n');
}

function renderHuman(s) {
  console.log(`Ancilla — ${s.phase_label}`);
  console.log(`Phase: ${s.phase}  ·  Last updated: ${s.last_updated}`);
  if (s.release_eta) {
    console.log(`Release ETA: ${s.release_eta}`);
  } else if (s.release_status === 'no-release') {
    console.log('Release ETA: not announced');
  }
  console.log();
  console.log(s.headline);
  if (s.details) {
    console.log();
    console.log(wrap(s.details, 72));
  }
  if (s.warning) {
    console.log();
    const lines = wrap(s.warning, 70).split('\n');
    lines.forEach((line, i) => {
      console.log((i === 0 ? '⚠ ' : '  ') + line);
    });
  }
  console.log();
  const links = s.links || {};
  const printLink = (label, val) => {
    if (val) console.log('  ' + label.padEnd(10) + val);
  };
  printLink('Home:', links.home);
  printLink('GitHub:', links.github);
  printLink('Reddit:', links.reddit);
  printLink('X:', links.x);
  printLink('Email:', links.email);
  printLink('Security:', links.security);
  console.log();
  console.log('(Run `ancilla --json` for raw status. `ancilla --version` for client version.)');
}

function render(text, asJson) {
  if (asJson) {
    try {
      const parsed = JSON.parse(text);
      console.log(JSON.stringify(parsed, null, 2));
    } catch {
      console.log(text);
    }
    return;
  }
  try {
    const parsed = JSON.parse(text);
    renderHuman(parsed);
  } catch (e) {
    process.stderr.write(`Status JSON did not parse: ${e.message}\n`);
    process.stderr.write(`Raw response:\n${text}\n`);
  }
}

function readCache() {
  try {
    return fs.readFileSync(CACHE_PATH, 'utf8');
  } catch {
    return null;
  }
}

function writeCache(text) {
  try {
    fs.mkdirSync(CACHE_DIR, { recursive: true });
    fs.writeFileSync(CACHE_PATH, text);
  } catch {
    /* non-fatal */
  }
}

async function fetchStatus() {
  if (typeof fetch !== 'function') {
    throw new Error('fetch() is not available; this client requires Node.js 18+.');
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(STATUS_URL, {
      signal: controller.signal,
      headers: { 'User-Agent': USER_AGENT },
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    return await res.text();
  } finally {
    clearTimeout(timer);
  }
}

async function fetchAndPrint(asJson) {
  try {
    const text = await fetchStatus();
    writeCache(text);
    render(text, asJson);
    return 0;
  } catch (e) {
    process.stderr.write(`Could not reach ${STATUS_URL}: ${e.message}\n`);
    const cached = readCache();
    if (cached) {
      process.stderr.write('Showing last cached status:\n\n');
      render(cached, asJson);
      return 2;
    }
    process.stderr.write('No cached status available. Visit https://ancilla.live in a browser.\n');
    return 1;
  }
}

async function main() {
  const arg = process.argv[2];
  switch (arg) {
    case '--version':
    case '-V':
      console.log(`ancilla ${PKG.version} (status client — not the Ancilla platform; see https://ancilla.live)`);
      return 0;
    case '--help':
    case '-h':
      printHelp();
      return 0;
    case '--json':
      return fetchAndPrint(true);
    case undefined:
      return fetchAndPrint(false);
    default:
      process.stderr.write(`Unknown argument: ${arg}\n\n`);
      printHelp();
      return 1;
  }
}

main().then(code => process.exit(code)).catch(err => {
  process.stderr.write(`Fatal: ${err.message}\n`);
  process.exit(1);
});
