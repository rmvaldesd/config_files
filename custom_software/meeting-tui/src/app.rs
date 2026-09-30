//! Application state and key handling.

use std::fs;
use std::process::Command;
use std::time::{Duration, Instant};

use chrono::Local;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ratatui::widgets::TableState;

use crate::config::AppConfig;
use crate::meeting::{self, Meeting};
use crate::paths;
use crate::voxtype;

/// Number of rows on the configuration screen.
pub const SETTINGS_COUNT: usize = 5;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputKind {
    /// Ask for the meeting name before starting.
    Name,
    /// Ask for the export folder.
    ExportDir,
}

/// Something you can flip on/off for the export (persisted in the config).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExportFlag {
    Speakers,
    Timestamps,
    Metadata,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    /// Idle: the list of saved meetings.
    List,
    /// A meeting is recording or paused.
    Live,
    /// The configuration screen.
    Settings,
    /// A modal text prompt.
    Input(InputKind),
}

#[derive(Debug, Default)]
pub struct Live {
    pub active: bool,
    pub status: String,
    pub meeting_id: Option<String>,
    pub title: Option<String>,
    pub started: Option<chrono::DateTime<Local>>,
}

pub struct App {
    pub config: AppConfig,
    pub meetings: Vec<Meeting>,
    pub table: TableState,
    pub settings: TableState,
    pub mode: Mode,
    pub input: String,
    pub live: Live,
    pub message: Option<(String, Instant)>,
    pub should_quit: bool,
    pub voxtype_version: Option<String>,
    last_poll: Instant,
    /// Set when we start a meeting ourselves: the daemon needs a moment to write the
    /// state file, and that gap must not be mistaken for "the meeting already ended".
    pending_start: Option<Instant>,
    /// Where the text prompt returns to when it closes (List for a new name, Settings for
    /// the export folder).
    input_return: Mode,
}

impl App {
    pub fn new() -> Self {
        let mut settings = TableState::default();
        settings.select(Some(0));
        let mut app = Self {
            config: AppConfig::load(),
            meetings: meeting::load_meetings(),
            table: TableState::default(),
            settings,
            mode: Mode::List,
            input: String::new(),
            live: Live::default(),
            message: None,
            should_quit: false,
            voxtype_version: voxtype::version(),
            last_poll: Instant::now(),
            pending_start: None,
            input_return: Mode::List,
        };
        if !app.meetings.is_empty() {
            app.table.select(Some(0));
        }
        app.poll_live();
        if app.live.active {
            app.mode = Mode::Live;
        }
        app
    }

    pub fn message_text(&self) -> Option<&str> {
        self.message.as_ref().map(|(m, _)| m.as_str())
    }

    pub fn export_dir_display(&self) -> String {
        self.config.export_dir.display().to_string()
    }

    /// The configuration screen rows: `(label, current value)`.
    pub fn settings_rows(&self) -> Vec<(&'static str, String)> {
        vec![
            ("Export format", self.config.export_format.clone()),
            ("Export folder", self.export_dir_display()),
            (
                "Include speakers",
                on_off(self.config.include_speakers).to_string(),
            ),
            (
                "Include timestamps",
                on_off(self.config.include_timestamps).to_string(),
            ),
            (
                "Include metadata",
                on_off(self.config.include_metadata).to_string(),
            ),
        ]
    }

    pub fn toast(&mut self, msg: impl Into<String>) {
        self.message = Some((msg.into(), Instant::now()));
    }

    fn save_config(&mut self, message: String) {
        match self.config.save() {
            Ok(()) => self.toast(message),
            Err(e) => self.toast(format!("Could not save config: {e}")),
        }
    }

    pub fn refresh_meetings(&mut self) {
        self.meetings = meeting::load_meetings();
        if self.meetings.is_empty() {
            self.table.select(None);
        } else {
            let sel = self
                .table
                .selected()
                .unwrap_or(0)
                .min(self.meetings.len() - 1);
            self.table.select(Some(sel));
        }
    }

    fn selected(&self) -> Option<&Meeting> {
        self.table.selected().and_then(|i| self.meetings.get(i))
    }

    // ---------------------------------------------------------------- polling

    /// Called every loop tick: refresh live state and the list at ~1 Hz.
    pub fn tick(&mut self) {
        let now = Instant::now();
        if now.duration_since(self.last_poll) >= Duration::from_millis(1000) {
            self.last_poll = now;
            self.poll_live();
            if !self.live.active {
                self.refresh_meetings();
            }
        }
        if let Some((_, stamp)) = &self.message {
            if now.duration_since(*stamp) >= Duration::from_secs(8) {
                self.message = None;
            }
        }
    }

    fn poll_live(&mut self) {
        match voxtype::live_state() {
            Some((status, id)) => {
                self.pending_start = None;
                if !self.live.active {
                    self.live = Live::default();
                    self.live.active = true;
                    self.mode = Mode::Live;
                }
                self.live.status = status;
                self.live.meeting_id = id;

                let meta = self
                    .live
                    .meeting_id
                    .as_deref()
                    .and_then(|id| meeting::find_by_id(&self.meetings, id));
                if self.live.title.is_none() {
                    if let Some(m) = meta {
                        self.live.title = Some(m.display_title());
                    }
                }
                if self.live.started.is_none() {
                    self.live.started = meta
                        .and_then(|m| m.started_local_dt())
                        .or_else(|| Some(Local::now()));
                }
            }
            None => {
                if self.live.active {
                    // We may have just started it: wait a few seconds for the daemon to
                    // write the state file before declaring the meeting finished.
                    if self
                        .pending_start
                        .is_some_and(|t| t.elapsed() < Duration::from_secs(6))
                    {
                        return;
                    }
                    self.pending_start = None;
                    self.live = Live::default();
                    self.mode = Mode::List;
                    self.refresh_meetings();
                    self.toast("Meeting finished. Transcript saved.");
                }
            }
        }
    }

    /// Elapsed time of the active meeting, as `m:ss` or `h:mm:ss`.
    pub fn elapsed(&self) -> String {
        let Some(started) = self.live.started else {
            return "0:00".to_string();
        };
        let secs = (Local::now() - started).num_seconds().max(0) as u64;
        let (h, m, s) = (secs / 3600, (secs % 3600) / 60, secs % 60);
        if h > 0 {
            format!("{h}:{m:02}:{s:02}")
        } else {
            format!("{m}:{s:02}")
        }
    }

    // ------------------------------------------------------------- key input

    pub fn on_key(&mut self, key: KeyEvent) {
        // Ctrl-C quits from anywhere.
        if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
            self.should_quit = true;
            return;
        }
        match self.mode {
            Mode::Input(kind) => self.on_input_key(key, kind),
            Mode::List => self.on_list_key(key),
            Mode::Live => self.on_live_key(key),
            Mode::Settings => self.on_settings_key(key),
        }
    }

    fn on_list_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Char('q') | KeyCode::Esc => self.should_quit = true,
            KeyCode::Up | KeyCode::Char('k') => self.move_selection(-1),
            KeyCode::Down | KeyCode::Char('j') => self.move_selection(1),
            KeyCode::Char('s') => {
                self.input.clear();
                self.input_return = Mode::List;
                self.mode = Mode::Input(InputKind::Name);
            }
            KeyCode::Char('e') | KeyCode::Enter => self.export_selected(),
            KeyCode::Char('o') => {
                let dir = self.export_dir_display();
                self.open_path(&dir);
            }
            KeyCode::Char('O') => self.open_meeting_dir(),
            KeyCode::Char('c') => {
                self.settings.select(Some(0));
                self.mode = Mode::Settings;
            }
            KeyCode::Char('r') => {
                self.refresh_meetings();
                self.toast("List refreshed.");
            }
            _ => {}
        }
    }

    fn on_settings_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('c') => self.mode = Mode::List,
            KeyCode::Up | KeyCode::Char('k') => self.move_settings(-1),
            KeyCode::Down | KeyCode::Char('j') => self.move_settings(1),
            KeyCode::Enter | KeyCode::Char(' ') => self.activate_setting(),
            _ => {}
        }
    }

    fn on_live_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Char('q') | KeyCode::Esc => self.should_quit = true,
            KeyCode::Char('p') => self.toggle_pause(),
            KeyCode::Char('x') => self.stop_meeting(),
            _ => {}
        }
    }

    fn on_input_key(&mut self, key: KeyEvent, kind: InputKind) {
        match key.code {
            KeyCode::Esc => {
                self.input.clear();
                self.mode = self.input_return;
            }
            KeyCode::Enter => self.submit_input(kind),
            KeyCode::Backspace => {
                self.input.pop();
            }
            KeyCode::Char(c) => self.input.push(c),
            _ => {}
        }
    }

    fn move_selection(&mut self, delta: isize) {
        if self.meetings.is_empty() {
            return;
        }
        let len = self.meetings.len() as isize;
        let current = self.table.selected().unwrap_or(0) as isize;
        self.table
            .select(Some((current + delta).rem_euclid(len) as usize));
    }

    fn move_settings(&mut self, delta: isize) {
        let len = SETTINGS_COUNT as isize;
        let current = self.settings.selected().unwrap_or(0) as isize;
        self.settings
            .select(Some((current + delta).rem_euclid(len) as usize));
    }

    // --------------------------------------------------------------- actions

    /// Change whatever row of the configuration screen is selected.
    fn activate_setting(&mut self) {
        match self.settings.selected().unwrap_or(0) {
            0 => {
                self.config.cycle_format();
                let format = self.config.export_format.clone();
                self.save_config(format!("Export format: {format}"));
            }
            1 => {
                self.input = self.export_dir_display();
                self.input_return = Mode::Settings;
                self.mode = Mode::Input(InputKind::ExportDir);
            }
            2 => self.toggle_export_flag(ExportFlag::Speakers),
            3 => self.toggle_export_flag(ExportFlag::Timestamps),
            4 => self.toggle_export_flag(ExportFlag::Metadata),
            _ => {}
        }
    }

    fn submit_input(&mut self, kind: InputKind) {
        match kind {
            InputKind::Name => {
                let title = timestamped_title(&self.input);
                self.input.clear();
                match voxtype::meeting_start(&title) {
                    Ok(()) => {
                        self.pending_start = Some(Instant::now());
                        self.live = Live {
                            active: true,
                            status: "recording".to_string(),
                            meeting_id: None,
                            title: Some(title),
                            started: Some(Local::now()),
                        };
                        self.mode = Mode::Live;
                        self.toast("Recording. 'p' pause/resume, 'x' stop.");
                    }
                    Err(e) => {
                        self.mode = Mode::List;
                        self.toast(format!("Start failed: {e}"));
                    }
                }
            }
            InputKind::ExportDir => {
                let dir = paths::expand_tilde(&self.input);
                self.input.clear();
                self.mode = self.input_return;
                if dir.as_os_str().is_empty() {
                    return;
                }
                self.config.export_dir = dir;
                let message = format!("Export folder: {}", self.export_dir_display());
                self.save_config(message);
            }
        }
    }

    fn toggle_pause(&mut self) {
        let status = self.live.status.to_ascii_lowercase();
        let result = if status == "paused" {
            voxtype::meeting_resume().map(|()| "recording")
        } else if matches!(status.as_str(), "recording" | "active" | "starting") {
            voxtype::meeting_pause().map(|()| "paused")
        } else {
            self.toast("Nothing to pause.");
            return;
        };
        match result {
            Ok(next) => {
                self.live.status = next.to_string();
                self.poll_live();
            }
            Err(e) => self.toast(format!("Pause/resume failed: {e}")),
        }
    }

    fn stop_meeting(&mut self) {
        match voxtype::meeting_stop() {
            Ok(()) => self.toast("Stopping; voxtype is finishing the transcript."),
            Err(e) => self.toast(format!("Stop failed: {e}")),
        }
    }

    fn export_selected(&mut self) {
        let Some(meeting) = self.selected().cloned() else {
            self.toast("No meeting selected.");
            return;
        };
        let dir = self.config.export_dir.clone();
        if let Err(e) = fs::create_dir_all(&dir) {
            self.toast(format!("Could not create {}: {e}", dir.display()));
            return;
        }
        let ext = self.config.extension();
        let base = meeting::slugify(&meeting.display_title());
        let mut path = dir.join(format!("{base}.{ext}"));
        let mut n = 2;
        while path.exists() {
            path = dir.join(format!("{base}-{n}.{ext}"));
            n += 1;
        }
        let result = voxtype::meeting_export(
            &meeting.id,
            &path,
            &self.config.export_format,
            self.config.include_speakers,
            self.config.include_metadata,
            self.config.include_timestamps,
        );
        match result {
            Ok(()) => self.toast(format!("Exported: {}", path.display())),
            Err(e) => self.toast(format!("Export failed: {e}")),
        }
    }

    fn open_meeting_dir(&mut self) {
        let Some(path) = self.selected().and_then(|m| m.storage_path.clone()) else {
            self.toast("No folder recorded for this meeting.");
            return;
        };
        self.open_path(&path);
    }

    fn open_path(&mut self, path: &str) {
        match Command::new("xdg-open").arg(path).spawn() {
            Ok(_) => self.toast(format!("Opening {path}")),
            Err(e) => self.toast(format!("Could not open {path}: {e}")),
        }
    }

    /// Flip one export flag and persist it.
    fn toggle_export_flag(&mut self, flag: ExportFlag) {
        let (name, value) = match flag {
            ExportFlag::Speakers => {
                self.config.include_speakers = !self.config.include_speakers;
                ("speakers", self.config.include_speakers)
            }
            ExportFlag::Timestamps => {
                self.config.include_timestamps = !self.config.include_timestamps;
                ("timestamps", self.config.include_timestamps)
            }
            ExportFlag::Metadata => {
                self.config.include_metadata = !self.config.include_metadata;
                ("metadata", self.config.include_metadata)
            }
        };
        let message = format!("Export {name}: {}", on_off(value));
        self.save_config(message);
    }
}

fn on_off(value: bool) -> &'static str {
    if value {
        "on"
    } else {
        "off"
    }
}

/// `<name> <timestamp>`, or `Meeting <timestamp>` when the name is empty.
pub fn timestamped_title(name: &str) -> String {
    let name = name.trim();
    let base = if name.is_empty() { "Meeting" } else { name };
    let stamp = Local::now().format("%Y-%m-%d %H:%M:%S");
    format!("{base} {stamp}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_name_becomes_default_timestamped_title() {
        let title = timestamped_title("   ");
        assert!(title.starts_with("Meeting "), "{title}");
    }

    #[test]
    fn given_name_is_kept_and_timestamped() {
        let title = timestamped_title("Daily");
        assert!(title.starts_with("Daily "), "{title}");
    }

    #[test]
    fn settings_screen_lists_every_option() {
        let app = App::new();
        let rows = app.settings_rows();
        assert_eq!(rows.len(), SETTINGS_COUNT);
        let labels: Vec<&str> = rows.iter().map(|(label, _)| *label).collect();
        assert!(labels.contains(&"Export format"));
        assert!(labels.contains(&"Export folder"));
        assert!(labels.contains(&"Include speakers"));
        assert!(labels.contains(&"Include timestamps"));
        assert!(labels.contains(&"Include metadata"));
    }
}
