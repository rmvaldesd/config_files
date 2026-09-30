//! Where things live: the voxtype data/runtime dirs and this app's own config.
//!
//! Everything is derived from the XDG environment variables with the usual fallbacks, so
//! the app agrees with what the voxtype daemon and the shell already use.

use std::env;
use std::path::PathBuf;

fn env_path(var: &str) -> Option<PathBuf> {
    env::var_os(var).map(PathBuf::from)
}

pub fn home() -> PathBuf {
    env_path("HOME").unwrap_or_else(|| PathBuf::from("."))
}

/// `$XDG_DATA_HOME` (default `~/.local/share`): voxtype keeps `voxtype/meetings/` here.
pub fn data_dir() -> PathBuf {
    env_path("XDG_DATA_HOME").unwrap_or_else(|| home().join(".local/share"))
}

/// `$XDG_CONFIG_HOME` (default `~/.config`): this app's own config lives here.
pub fn config_dir() -> PathBuf {
    env_path("XDG_CONFIG_HOME").unwrap_or_else(|| home().join(".config"))
}

/// `$XDG_RUNTIME_DIR` (default `/tmp`): voxtype writes its live state files here.
pub fn runtime_dir() -> PathBuf {
    env_path("XDG_RUNTIME_DIR").unwrap_or_else(|| PathBuf::from("/tmp"))
}

pub fn meetings_dir() -> PathBuf {
    data_dir().join("voxtype").join("meetings")
}

/// The daemon writes `<status>\n<meeting_id>` here while a meeting is active.
pub fn meeting_state_file() -> PathBuf {
    runtime_dir().join("voxtype").join("meeting_state")
}

pub fn app_config_file() -> PathBuf {
    config_dir().join("meeting-tui").join("config.toml")
}

/// Default export folder, `~/meeting-transcriptions`, until the user changes it in the UI.
pub fn default_export_dir() -> PathBuf {
    home().join("meeting-transcriptions")
}

/// Expand a leading `~` / `~/` in a user-typed path.
pub fn expand_tilde(s: &str) -> PathBuf {
    let s = s.trim();
    if s == "~" {
        home()
    } else if let Some(rest) = s.strip_prefix("~/") {
        home().join(rest)
    } else {
        PathBuf::from(s)
    }
}
