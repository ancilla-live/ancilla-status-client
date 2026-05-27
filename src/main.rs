//! Ancilla status client.
//!
//! Fetches https://ancilla.live/.well-known/ancilla-status.json and prints
//! a human-readable status summary. `--json` prints the raw JSON. `--version`
//! and `--help` work offline.
//!
//! This binary is NOT the Ancilla platform itself. It is a small client that
//! reports the current development status of the Ancilla project. See
//! https://ancilla.live for project details.

use std::fs;
use std::io;
use std::path::PathBuf;
use std::process::ExitCode;
use std::time::Duration;

use serde::Deserialize;

const STATUS_URL: &str = "https://ancilla.live/.well-known/ancilla-status.json";
const PKG_VERSION: &str = env!("CARGO_PKG_VERSION");
const TIMEOUT: Duration = Duration::from_secs(5);
const USER_AGENT: &str = concat!("ancilla-status-client/", env!("CARGO_PKG_VERSION"));

#[derive(Debug, Deserialize)]
struct Status {
    phase_label: String,
    phase: String,
    last_updated: String,
    headline: String,
    details: Option<String>,
    links: Links,
    warning: Option<String>,
    #[serde(default)]
    release_status: Option<String>,
    #[serde(default)]
    release_eta: Option<String>,
}

#[derive(Debug, Deserialize)]
struct Links {
    home: Option<String>,
    github: Option<String>,
    reddit: Option<String>,
    x: Option<String>,
    email: Option<String>,
    #[serde(default)]
    security: Option<String>,
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();

    match args.first().map(String::as_str) {
        Some("--version") | Some("-V") => {
            println!(
                "ancilla {PKG_VERSION} (status client — not the Ancilla platform; see https://ancilla.live)"
            );
            ExitCode::SUCCESS
        }
        Some("--help") | Some("-h") => {
            print_help();
            ExitCode::SUCCESS
        }
        Some("--json") => fetch_and_print(OutputMode::Json),
        None => fetch_and_print(OutputMode::Human),
        Some(other) => {
            eprintln!("Unknown argument: {other}\n");
            print_help();
            ExitCode::FAILURE
        }
    }
}

enum OutputMode {
    Human,
    Json,
}

fn print_help() {
    println!(
        "ancilla — status client for the Ancilla platform

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
    never run with real personal data.
"
    );
}

fn fetch_and_print(mode: OutputMode) -> ExitCode {
    match fetch_status() {
        Ok(json_text) => {
            let _ = cache_write(&json_text);
            render(&json_text, &mode);
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("Could not reach {STATUS_URL}: {e}");
            match cache_read() {
                Some(cached) => {
                    eprintln!("Showing last cached status:\n");
                    render(&cached, &mode);
                    // Non-zero so scripts can detect we're showing stale data
                    ExitCode::from(2)
                }
                None => {
                    eprintln!(
                        "No cached status available. Visit https://ancilla.live in a browser."
                    );
                    ExitCode::FAILURE
                }
            }
        }
    }
}

fn fetch_status() -> Result<String, String> {
    let agent = ureq::AgentBuilder::new()
        .timeout(TIMEOUT)
        .user_agent(USER_AGENT)
        .build();

    let response = agent
        .get(STATUS_URL)
        .call()
        .map_err(|e| format!("{e}"))?;

    if response.status() != 200 {
        return Err(format!("HTTP {}", response.status()));
    }

    response
        .into_string()
        .map_err(|e| format!("read body: {e}"))
}

fn render(json_text: &str, mode: &OutputMode) {
    match mode {
        OutputMode::Json => {
            // Pretty-print for readability; keep parseable.
            match serde_json::from_str::<serde_json::Value>(json_text) {
                Ok(v) => println!("{}", serde_json::to_string_pretty(&v).unwrap_or_else(|_| json_text.to_string())),
                Err(_) => println!("{json_text}"),
            }
        }
        OutputMode::Human => match serde_json::from_str::<Status>(json_text) {
            Ok(status) => print_human(&status),
            Err(e) => {
                eprintln!("Status JSON did not parse: {e}");
                eprintln!("Raw response:\n{json_text}");
            }
        },
    }
}

fn print_human(s: &Status) {
    println!("Ancilla — {}", s.phase_label);
    println!("Phase: {}  ·  Last updated: {}", s.phase, s.last_updated);
    if let Some(eta) = &s.release_eta {
        println!("Release ETA: {eta}");
    } else if matches!(s.release_status.as_deref(), Some("no-release")) {
        println!("Release ETA: not announced");
    }
    println!();
    println!("{}", s.headline);
    if let Some(details) = &s.details {
        println!();
        for line in wrap(details, 72) {
            println!("{line}");
        }
    }
    if let Some(warning) = &s.warning {
        println!();
        let wrapped = wrap(warning, 70);
        for (i, line) in wrapped.iter().enumerate() {
            if i == 0 {
                println!("⚠ {line}");
            } else {
                println!("  {line}");
            }
        }
    }
    println!();
    let print_link = |label: &str, value: &Option<String>| {
        if let Some(v) = value {
            println!("  {label:<10}{v}");
        }
    };
    print_link("Home:", &s.links.home);
    print_link("GitHub:", &s.links.github);
    print_link("Reddit:", &s.links.reddit);
    print_link("X:", &s.links.x);
    print_link("Email:", &s.links.email);
    print_link("Security:", &s.links.security);
    println!();
    println!("(Run `ancilla --json` for raw status. `ancilla --version` for client version.)");
}

fn wrap(text: &str, width: usize) -> Vec<String> {
    let mut out = Vec::new();
    for para in text.split('\n') {
        if para.is_empty() {
            out.push(String::new());
            continue;
        }
        let mut line = String::new();
        for word in para.split_whitespace() {
            if line.len() + word.len() + 1 > width && !line.is_empty() {
                out.push(line.clone());
                line.clear();
            }
            if !line.is_empty() {
                line.push(' ');
            }
            line.push_str(word);
        }
        if !line.is_empty() {
            out.push(line);
        }
    }
    out
}

fn cache_path() -> Option<PathBuf> {
    let base = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".cache")))?;
    Some(base.join("ancilla").join("last-status.json"))
}

fn cache_write(text: &str) -> io::Result<()> {
    let path = cache_path().ok_or_else(|| io::Error::other("no cache dir"))?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, text)
}

fn cache_read() -> Option<String> {
    cache_path().and_then(|p| fs::read_to_string(p).ok())
}
