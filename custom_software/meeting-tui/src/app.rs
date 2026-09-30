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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputKind {
    /// Ask for the meeting name before starting.
    Name,
    /// Ask for the export folder.
    ExportDir,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    /// Idle: the list of saved meetings.
    List,
    /// A meeting is recording or paused.
    Live,
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
    pub mode: Mode,
    pub input: String,
    pub live: Live,
    pub message: Option<(String, Instant)>,
    pub should_quit: bool,
    pub voxtype_version: Option<String>,
    last_poll: Instant,
}

impl App {
    pub fn new() -> Self {
        let mut app = Self {
            config: AppConfig::load(),
            meetings: meeting::load_meetings(),
            table: TableState::default(),
            mode: Mode::List,
            input: String::new(),
            live: Live::default(),
            message: None,
            should_quit: false,
            voxtype_version: voxtype::version(),
            last_poll: Instant::now(),
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

    pub fn toast(&mut self, msg: impl Into<String>) {
        self.message = Some((msg.into(), Instant::now()));
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
        match self.mode {
            Mode::Input(kind) => self.on_input_key(key, kind),
            Mode::List => self.on_list_key(key),
            Mode::Live => self.on_live_key(key),
        }
    }

    fn on_list_key(&mut self, key: KeyEvent) {
        if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
            self.should_quit = true;
            return;
        }
        match key.code {
            KeyCode::Char('q') | KeyCode::Esc => self.should_quit = true,
            KeyCode::Up | KeyCode::Char('k') => self.move_selection(-1),
            KeyCode::Down | KeyCode::Char('j') => self.move_selection(1),
            KeyCode::Char('s') => {
                self.input.clear();
                self.mode = Mode::Input(InputKind::Name);
            }
            KeyCode::Char('e') | KeyCode::Enter => self.export_selected(),
            KeyCode::Char('o') => {
                let dir = self.export_dir_display();
                self.open_path(&dir);
            }
            KeyCode::Char('O') => self.open_meeting_dir(),
            KeyCode::Char('d') => {
                self.input = self.export_dir_display();
                self.mode = Mode::Input(InputKind::ExportDir);
            }
            KeyCode::Char('f') => {
                self.config.cycle_format();
                let format = self.config.export_format.clone();
                match self.config.save() {
                    Ok(()) => self.toast(format!("Export format: {format}")),
                    Err(e) => self.toast(format!("Could not save config: {e}")),
                }
            }
            KeyCode::Char('r') => {
                self.refresh_meetings();
                self.toast("List refreshed.");
            }
            _ => {}
        }
    }

    fn on_live_key(&mut self, key: KeyEvent) {
        if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
            self.should_quit = true;
            return;
        }
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
                self.mode = Mode::List;
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

    // --------------------------------------------------------------- actions

    fn submit_input(&mut self, kind: InputKind) {
        match kind {
            InputKind::Name => {
                let title = timestamped_title(&self.input);
                self.input.clear();
                match voxtype::meeting_start(&title) {
                    Ok(()) => {
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
                self.mode = Mode::List;
                if dir.as_os_str().is_empty() {
                    return;
                }
                self.config.export_dir = dir;
                match self.config.save() {
                    Ok(()) => self.toast(format!("Export folder: {}", self.export_dir_display())),
                    Err(e) => self.toast(format!("Could not save config: {e}")),
                }
            }
        }
    }

    fn toggle_pause(&mut self) {
        let paused = self.live.status.eq_ignore_ascii_case("paused");
        let result = if paused {
            voxtype::meeting_resume()
        } else {
            voxtype::meeting_pause()
        };
        match result {
            Ok(()) => {
                self.live.status = if paused { "recording" } else { "paused" }.to_string();
                self.poll_live();
            }
            Err(e) => self.toast(format!(
                "{} failed: {e}",
                if paused { "Resume" } else { "Pause" }
            )),
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
}
