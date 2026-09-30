//! Thin wrapper around the `voxtype` CLI.

use std::fs;
use std::path::Path;
use std::process::Command;

use anyhow::{bail, Result};

use crate::paths;

fn run(args: &[&str]) -> Result<String> {
    let output = Command::new("voxtype")
        .args(args)
        .output()
        .map_err(|e| anyhow::anyhow!("could not run 'voxtype {}': {e}", args.join(" ")))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stderr = stderr.trim();
        let detail = if stderr.is_empty() {
            "unknown error"
        } else {
            stderr
        };
        bail!("voxtype {} failed: {detail}", args.join(" "));
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

pub fn meeting_start(title: &str) -> Result<()> {
    run(&["meeting", "start", "--title", title]).map(|_| ())
}

pub fn meeting_stop() -> Result<()> {
    run(&["meeting", "stop"]).map(|_| ())
}

pub fn meeting_pause() -> Result<()> {
    run(&["meeting", "pause"]).map(|_| ())
}

pub fn meeting_resume() -> Result<()> {
    run(&["meeting", "resume"]).map(|_| ())
}

/// Build the argv for `voxtype meeting export` (without the program name).
///
/// Pure, so the flag logic is unit-testable.
pub fn export_args(
    id: &str,
    output: &str,
    format: &str,
    speakers: bool,
    metadata: bool,
    timestamps: bool,
) -> Vec<String> {
    let mut args = vec![
        "meeting".to_string(),
        "export".to_string(),
        id.to_string(),
        "--format".to_string(),
        format.to_string(),
        "--output".to_string(),
        output.to_string(),
    ];
    if speakers {
        args.push("--speakers".to_string());
    }
    if metadata {
        args.push("--metadata".to_string());
    }
    if timestamps {
        args.push("--timestamps".to_string());
    }
    args
}

#[allow(clippy::too_many_arguments)]
pub fn meeting_export(
    id: &str,
    output: &Path,
    format: &str,
    speakers: bool,
    metadata: bool,
    timestamps: bool,
) -> Result<()> {
    let output = output.to_string_lossy().to_string();
    let args = export_args(id, &output, format, speakers, metadata, timestamps);
    let refs: Vec<&str> = args.iter().map(String::as_str).collect();
    run(&refs).map(|_| ())
}

/// Live meeting state, from the daemon's state file: `(status, meeting_id)`.
///
/// `None` when no meeting is in progress.
pub fn live_state() -> Option<(String, Option<String>)> {
    let text = fs::read_to_string(paths::meeting_state_file()).ok()?;
    parse_meeting_state(&text)
}

/// Parse the `meeting_state` file. Its first line is the status and the second (optional)
/// is the meeting id.
///
/// The daemon leaves the file behind with `idle` once a meeting ends, so a non-empty file
/// does NOT mean a meeting is running: only the active statuses count. Without this check
/// the UI would sit in "recording" forever and `meeting stop` would fail with "no meeting".
pub fn parse_meeting_state(text: &str) -> Option<(String, Option<String>)> {
    let mut lines = text.lines();
    let status = lines.next()?.trim();
    if !is_active_status(status) {
        return None;
    }
    let id = lines
        .next()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());
    Some((status.to_string(), id))
}

/// Statuses that mean a meeting is still going on (start/stop transitions included).
pub fn is_active_status(status: &str) -> bool {
    matches!(
        status.trim().to_ascii_lowercase().as_str(),
        "recording" | "paused" | "active" | "starting" | "stopping" | "transcribing"
    )
}

/// `voxtype --version` as a one-liner, for the header.
pub fn version() -> Option<String> {
    let output = Command::new("voxtype").arg("--version").output().ok()?;
    if output.status.success() {
        Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn idle_is_not_an_active_meeting() {
        // The daemon leaves this file behind with "idle" after a meeting ends.
        assert_eq!(parse_meeting_state("idle\n"), None);
        assert_eq!(parse_meeting_state("idle"), None);
        assert_eq!(parse_meeting_state("stopped\n"), None);
        assert_eq!(parse_meeting_state("completed\n"), None);
        assert_eq!(parse_meeting_state(""), None);
    }

    #[test]
    fn recording_carries_the_meeting_id() {
        let parsed = parse_meeting_state("recording\nabc-123\n").unwrap();
        assert_eq!(parsed.0, "recording");
        assert_eq!(parsed.1.as_deref(), Some("abc-123"));
    }

    #[test]
    fn paused_is_active_without_an_id() {
        let parsed = parse_meeting_state("paused\n").unwrap();
        assert_eq!(parsed.0, "paused");
        assert_eq!(parsed.1, None);
    }

    #[test]
    fn active_statuses_are_case_insensitive() {
        assert!(is_active_status("Recording"));
        assert!(is_active_status(" PAUSED "));
        assert!(!is_active_status("Idle"));
    }

    #[test]
    fn export_args_include_only_the_selected_flags() {
        let args = export_args("id1", "/tmp/x.md", "markdown", true, false, true);
        assert_eq!(&args[0..3], &["meeting", "export", "id1"]);
        assert!(args.contains(&"--speakers".to_string()));
        assert!(args.contains(&"--timestamps".to_string()));
        assert!(!args.contains(&"--metadata".to_string()));

        let none = export_args("id2", "/tmp/y.txt", "text", false, false, false);
        assert!(!none.contains(&"--speakers".to_string()));
        assert!(!none.contains(&"--timestamps".to_string()));
        assert!(!none.contains(&"--metadata".to_string()));
    }
}
