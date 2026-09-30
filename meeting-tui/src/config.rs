//! This app's own settings, kept in `~/.config/meeting-tui/config.toml`.
//!
//! It is intentionally NOT versioned in the repo (unlike the voxtype config): the export
//! folder is per-machine state and the app rewrites the file whenever it changes.

use std::fs;
use std::path::PathBuf;

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::paths;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct AppConfig {
    /// Where `e` writes the exported transcripts (default `~/meeting-transcriptions`).
    pub export_dir: PathBuf,
    /// One of `markdown`, `text`, `json` — passed straight to `voxtype meeting export`.
    pub export_format: String,
    pub include_speakers: bool,
    pub include_metadata: bool,
    pub include_timestamps: bool,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            export_dir: paths::default_export_dir(),
            export_format: "markdown".to_string(),
            include_speakers: true,
            include_metadata: true,
            include_timestamps: false,
        }
    }
}

impl AppConfig {
    pub fn load() -> Self {
        fs::read_to_string(paths::app_config_file())
            .ok()
            .and_then(|text| toml::from_str(&text).ok())
            .unwrap_or_default()
    }

    pub fn save(&self) -> Result<()> {
        let path = paths::app_config_file();
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(&path, toml::to_string_pretty(self)?)?;
        Ok(())
    }

    /// File extension for the current format.
    pub fn extension(&self) -> &'static str {
        match self.export_format.as_str() {
            "json" => "json",
            "text" => "txt",
            _ => "md",
        }
    }

    /// Cycle markdown -> text -> json -> markdown.
    pub fn cycle_format(&mut self) {
        self.export_format = match self.export_format.as_str() {
            "markdown" => "text",
            "text" => "json",
            _ => "markdown",
        }
        .to_string();
    }
}
