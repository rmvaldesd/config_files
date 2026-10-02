//! Past meetings, read from voxtype's storage.
//!
//! voxtype writes one directory per meeting under `~/.local/share/voxtype/meetings/`, each
//! with a `metadata.json`. Reading those files is simpler and more stable than parsing the
//! human output of `voxtype meeting list`, and it needs no SQLite dependency.

use std::fs;

use serde::Deserialize;

use crate::paths;

#[derive(Debug, Clone, Deserialize)]
pub struct Meeting {
    pub id: String,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub started_at: Option<String>,
    #[serde(default)]
    #[allow(dead_code)]
    pub ended_at: Option<String>,
    #[serde(default)]
    pub duration_secs: Option<u64>,
    #[serde(default)]
    pub status: Option<String>,
    #[serde(default)]
    pub chunk_count: Option<u64>,
    #[serde(default)]
    pub storage_path: Option<String>,
}

impl Meeting {
    /// The title, or a derived one when the meeting was never named.
    pub fn display_title(&self) -> String {
        match self.title.as_deref().map(str::trim) {
            Some(t) if !t.is_empty() => t.to_string(),
            _ => format!("Meeting {}", self.started_local()),
        }
    }

    /// Title for the meetings table: same as `display_title` but without the redundant
    /// trailing `YYYY-MM-DD HH:MM:SS` that we append when starting a meeting — the Date
    /// column already shows it, and dropping it leaves room for the other columns.
    pub fn short_title(&self) -> String {
        strip_trailing_timestamp(&self.display_title())
    }

    pub fn started_local(&self) -> String {
        format_local(self.started_at.as_deref())
    }

    pub fn duration_human(&self) -> String {
        human_duration(self.duration_secs.unwrap_or(0))
    }

    pub fn status_str(&self) -> &str {
        self.status.as_deref().unwrap_or("?")
    }

    pub fn chunks(&self) -> u64 {
        self.chunk_count.unwrap_or(0)
    }

    /// Parsed `started_at` as local time, when it is a valid RFC 3339 stamp.
    pub fn started_local_dt(&self) -> Option<chrono::DateTime<chrono::Local>> {
        self.started_at
            .as_deref()
            .and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok())
            .map(|dt| dt.with_timezone(&chrono::Local))
    }
}

/// Every meeting that has a readable `metadata.json`, newest first.
pub fn load_meetings() -> Vec<Meeting> {
    let mut out = Vec::new();
    let Ok(entries) = fs::read_dir(paths::meetings_dir()) else {
        return out;
    };
    for entry in entries.flatten() {
        let path = entry.path().join("metadata.json");
        let Ok(text) = fs::read_to_string(&path) else {
            continue;
        };
        if let Ok(meeting) = serde_json::from_str::<Meeting>(&text) {
            out.push(meeting);
        }
    }
    // started_at is RFC 3339, so a plain string sort is chronological.
    out.sort_by(|a, b| b.started_at.cmp(&a.started_at));
    out
}

pub fn find_by_id<'a>(meetings: &'a [Meeting], id: &str) -> Option<&'a Meeting> {
    meetings.iter().find(|m| m.id == id)
}

/// `2026-09-30T12:31:00Z` -> `2026-09-30 12:31` in local time.
pub fn format_local(iso: Option<&str>) -> String {
    iso.and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok())
        .map(|dt| {
            dt.with_timezone(&chrono::Local)
                .format("%Y-%m-%d %H:%M")
                .to_string()
        })
        .unwrap_or_else(|| "?".to_string())
}

pub fn human_duration(secs: u64) -> String {
    let (h, m, s) = (secs / 3600, (secs % 3600) / 60, secs % 60);
    if h > 0 {
        format!("{h}h {m:02}m")
    } else if m > 0 {
        format!("{m}m {s:02}s")
    } else {
        format!("{s}s")
    }
}

/// A filesystem-friendly version of a title, for the export file name.
pub fn slugify(s: &str) -> String {
    let mut out = String::new();
    let mut last_dash = false;
    for c in s.chars() {
        if c.is_alphanumeric() {
            out.extend(c.to_lowercase());
            last_dash = false;
        } else if !last_dash {
            out.push('-');
            last_dash = true;
        }
    }
    let slug = out.trim_matches('-').to_string();
    if slug.is_empty() {
        "meeting".to_string()
    } else {
        slug
    }
}

/// Drop a trailing ` YYYY-MM-DD HH:MM:SS` from a title, char-safe.
fn strip_trailing_timestamp(s: &str) -> String {
    let chars: Vec<char> = s.trim_end().chars().collect();
    let n = chars.len();
    if n >= 20 {
        let time: String = chars[n - 8..].iter().collect();
        let sep1: String = chars[n - 9..n - 8].iter().collect();
        let date: String = chars[n - 19..n - 9].iter().collect();
        let sep2: String = chars[n - 20..n - 19].iter().collect();
        if sep1 == " " && sep2 == " " && is_clock(&time) && is_date(&date) {
            return chars[..n - 20].iter().collect();
        }
    }
    s.to_string()
}

fn is_clock(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 8
        && b[2] == b':'
        && b[5] == b':'
        && b[..2].iter().all(u8::is_ascii_digit)
        && b[3..5].iter().all(u8::is_ascii_digit)
        && b[6..].iter().all(u8::is_ascii_digit)
}

fn is_date(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 10
        && b[4] == b'-'
        && b[7] == b'-'
        && b[..4].iter().all(u8::is_ascii_digit)
        && b[5..7].iter().all(u8::is_ascii_digit)
        && b[8..].iter().all(u8::is_ascii_digit)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn slugify_basic() {
        assert_eq!(
            slugify("Standup 2026-09-30 09:15:23"),
            "standup-2026-09-30-09-15-23"
        );
        assert_eq!(slugify("   "), "meeting");
        assert_eq!(slugify("Reunión de diseño"), "reunión-de-diseño");
    }

    #[test]
    fn human_duration_formats() {
        assert_eq!(human_duration(6), "6s");
        assert_eq!(human_duration(358), "5m 58s");
        assert_eq!(human_duration(3661), "1h 01m");
    }

    #[test]
    fn strips_only_a_trailing_seconds_timestamp() {
        assert_eq!(
            strip_trailing_timestamp("daily 2026-10-02 09:32:25"),
            "daily"
        );
        assert_eq!(
            strip_trailing_timestamp("operations core 2026-09-30 11:36:17"),
            "operations core"
        );
        assert_eq!(
            strip_trailing_timestamp("Reunión 2026-10-02 09:32:25"),
            "Reunión"
        );
        // No seconds (the "Meeting <date>" fallback for unnamed meetings): keep it.
        assert_eq!(
            strip_trailing_timestamp("Meeting 2026-09-30 09:31"),
            "Meeting 2026-09-30 09:31"
        );
        assert_eq!(strip_trailing_timestamp("test"), "test");
    }
}
