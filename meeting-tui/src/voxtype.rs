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
    let mut args: Vec<&str> = vec![
        "meeting", "export", id, "--format", format, "--output", &output,
    ];
    if speakers {
        args.push("--speakers");
    }
    if metadata {
        args.push("--metadata");
    }
    if timestamps {
        args.push("--timestamps");
    }
    run(&args).map(|_| ())
}

/// Live meeting state, from the daemon's state file: `(status, meeting_id)`.
///
/// `None` when no meeting is in progress (file missing or empty).
pub fn live_state() -> Option<(String, Option<String>)> {
    let text = fs::read_to_string(paths::meeting_state_file()).ok()?;
    let mut lines = text.lines();
    let status = lines.next()?.trim().to_string();
    if status.is_empty() {
        return None;
    }
    let id = lines
        .next()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());
    Some((status, id))
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
