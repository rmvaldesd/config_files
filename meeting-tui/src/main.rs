//! meeting-tui — a ratatui front-end for voxtype meeting recording.
//!
//! Replaces the old Quickshell meeting panel: start / stop / pause a meeting, give it a
//! name (a timestamp is appended), and, while idle, browse past meetings and export them
//! to a folder of your choice.

mod app;
mod config;
mod meeting;
mod paths;
mod ui;
mod voxtype;

use std::io;
use std::time::Duration;

use anyhow::Result;
use crossterm::event::{self, Event, KeyEventKind};
use crossterm::execute;
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;

use app::App;

fn main() -> Result<()> {
    handle_cli();

    install_panic_hook();

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new();
    let result = run(&mut terminal, &mut app);

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    if let Err(err) = result {
        eprintln!("meeting-tui: {err:#}");
        std::process::exit(1);
    }
    Ok(())
}

fn run<B: ratatui::backend::Backend>(terminal: &mut Terminal<B>, app: &mut App) -> Result<()> {
    loop {
        terminal.draw(|f| ui::draw(f, app))?;

        // Wake up at least 4x/s to poll the daemon and redraw the timer.
        if event::poll(Duration::from_millis(250))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    app.on_key(key);
                }
            }
        }
        app.tick();

        if app.should_quit {
            return Ok(());
        }
    }
}

/// `--version` / `--help` for a smoke test and for `which`-style checks, without a TTY.
fn handle_cli() {
    let version = env!("CARGO_PKG_VERSION");
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.iter().any(|a| a == "--version" || a == "-V") {
        println!("meeting-tui {version}");
        std::process::exit(0);
    }
    if args.iter().any(|a| a == "--help" || a == "-h") {
        println!(
            "meeting-tui {version} — voxtype meeting control panel\n\n\
             Run it from a terminal: the SUPER+SHIFT+M bind opens it in a floating foot window.\n\n\
             Keys:\n  \
             s start   p pause/resume   x stop\n  \
             e export  o open folder    d set export folder   f format   r refresh   q quit"
        );
        std::process::exit(0);
    }
}

/// Restore the terminal even if the app panics, so the shell is not left in raw mode.
fn install_panic_hook() {
    let previous = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        let _ = disable_raw_mode();
        let _ = execute!(io::stdout(), LeaveAlternateScreen);
        previous(info);
    }));
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::app::{InputKind, Mode};
    use ratatui::backend::TestBackend;

    fn render(app: &App) {
        let mut terminal = Terminal::new(TestBackend::new(100, 30)).unwrap();
        terminal.draw(|f| ui::draw(f, app)).unwrap();
    }

    #[test]
    fn renders_list_view() {
        render(&App::new());
    }

    #[test]
    fn renders_input_modal() {
        let mut app = App::new();
        app.mode = Mode::Input(InputKind::Name);
        app.input = "Standup".to_string();
        render(&app);
    }

    #[test]
    fn renders_live_view() {
        let mut app = App::new();
        app.mode = Mode::Live;
        app.live.active = true;
        app.live.status = "recording".to_string();
        app.live.title = Some("Daily".to_string());
        app.live.started = Some(chrono::Local::now());
        render(&app);
    }
}
