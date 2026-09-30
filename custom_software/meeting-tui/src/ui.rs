//! Rendering. Two views (idle list / live meeting) plus a modal prompt.

use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Cell, Clear, Paragraph, Row, Table, Wrap};
use ratatui::Frame;

use crate::app::{App, InputKind, Mode};

pub fn draw(f: &mut Frame, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(3),
            Constraint::Length(2),
        ])
        .split(f.area());

    draw_header(f, app, chunks[0]);
    match app.mode {
        Mode::Live => draw_live(f, app, chunks[1]),
        _ => draw_list(f, app, chunks[1]),
    }
    draw_footer(f, app, chunks[2]);

    if let Mode::Input(kind) = app.mode {
        draw_input(f, app, kind, f.area());
    }
}

fn draw_header(f: &mut Frame, app: &App, area: Rect) {
    let (label, color) = if !app.live.active {
        ("IDLE", Color::DarkGray)
    } else if app.live.status.eq_ignore_ascii_case("paused") {
        ("MEETING PAUSED", Color::Yellow)
    } else {
        ("MEETING RECORDING", Color::Red)
    };

    let version = app.voxtype_version.as_deref().unwrap_or("voxtype");
    let line = Line::from(vec![
        Span::styled(
            " meeting-tui ",
            Style::default().add_modifier(Modifier::BOLD),
        ),
        Span::styled(
            format!("[{label}]"),
            Style::default().fg(color).add_modifier(Modifier::BOLD),
        ),
        Span::raw(format!("   {version}")),
    ]);
    let block = Block::default()
        .borders(Borders::ALL)
        .title("voxtype meetings");
    f.render_widget(Paragraph::new(line).block(block), area);
}

fn draw_list(f: &mut Frame, app: &App, area: Rect) {
    let header = Row::new(vec!["Title", "Date", "Duration", "Chunks", "Status"])
        .style(Style::default().add_modifier(Modifier::BOLD));

    let rows = app.meetings.iter().map(|m| {
        Row::new(vec![
            Cell::from(m.display_title()),
            Cell::from(m.started_local()),
            Cell::from(m.duration_human()),
            Cell::from(m.chunks().to_string()),
            Cell::from(m.status_str().to_string()),
        ])
    });

    let widths = [
        Constraint::Min(26),
        Constraint::Length(16),
        Constraint::Length(10),
        Constraint::Length(7),
        Constraint::Length(11),
    ];

    let title = format!(
        "Saved meetings ({})   export -> {}",
        app.meetings.len(),
        app.export_dir_display()
    );

    let table = Table::new(rows, widths)
        .header(header)
        .block(Block::default().borders(Borders::ALL).title(title))
        .row_highlight_style(
            Style::default()
                .add_modifier(Modifier::REVERSED)
                .add_modifier(Modifier::BOLD),
        )
        .highlight_symbol("> ");

    // The table state is cloned so `draw` can stay read-only; it is tiny.
    let mut state = app.table.clone();
    f.render_stateful_widget(table, area, &mut state);
}

fn draw_live(f: &mut Frame, app: &App, area: Rect) {
    let title = app
        .live
        .title
        .clone()
        .unwrap_or_else(|| "(unnamed)".to_string());
    let status = if app.live.status.is_empty() {
        "recording".to_string()
    } else {
        app.live.status.to_uppercase()
    };

    let lines = vec![
        Line::from(""),
        Line::from(vec![
            Span::styled("  State:   ", Style::default().add_modifier(Modifier::BOLD)),
            Span::styled(
                status,
                Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
            ),
        ]),
        Line::from(vec![
            Span::styled("  Elapsed: ", Style::default().add_modifier(Modifier::BOLD)),
            Span::raw(app.elapsed()),
        ]),
        Line::from(vec![
            Span::styled("  Title:   ", Style::default().add_modifier(Modifier::BOLD)),
            Span::raw(title),
        ]),
        Line::from(""),
        Line::from("  p   pause / resume"),
        Line::from("  x   stop and transcribe"),
        Line::from("  q   close this window (the recording keeps going)"),
    ];

    let block = Block::default().borders(Borders::ALL).title("Live meeting");
    f.render_widget(
        Paragraph::new(lines)
            .block(block)
            .wrap(Wrap { trim: false }),
        area,
    );
}

fn draw_footer(f: &mut Frame, app: &App, area: Rect) {
    let hints = match app.mode {
        Mode::Input(InputKind::Name) => "type a name  ·  Enter start  ·  Esc cancel",
        Mode::Input(InputKind::ExportDir) => "type a folder (or ~/...)  ·  Enter save  ·  Esc cancel",
        Mode::Live => "p pause/resume  ·  x stop  ·  q quit",
        Mode::List => {
            "s start  ·  e/Enter export  ·  o open folder  ·  O meeting folder  ·  d set folder  ·  f format  ·  r refresh  ·  q quit"
        }
    };

    let mut lines = vec![Line::from(Span::styled(
        hints,
        Style::default().fg(Color::DarkGray),
    ))];
    if let Some(msg) = app.message_text() {
        lines.push(Line::from(Span::styled(
            msg.to_string(),
            Style::default().fg(Color::Green),
        )));
    }
    f.render_widget(Paragraph::new(lines), area);
}

fn draw_input(f: &mut Frame, app: &App, kind: InputKind, area: Rect) {
    let (prompt, hint) = match kind {
        InputKind::Name => (
            "Meeting name (Enter to start, Esc to cancel)",
            "empty -> \"Meeting <timestamp>\"",
        ),
        InputKind::ExportDir => (
            "Export folder (Enter to save, Esc to cancel)",
            "e.g. ~/meeting-transcriptions",
        ),
    };

    let rect = centered_rect(66, 5, area);
    f.render_widget(Clear, rect);

    // A trailing block is the cursor, so there is no dependency on the cursor API.
    let content = vec![
        Line::from(format!("{}▏", app.input)),
        Line::from(Span::styled(hint, Style::default().fg(Color::DarkGray))),
    ];
    let block = Block::default().borders(Borders::ALL).title(prompt);
    f.render_widget(Paragraph::new(content).block(block), rect);
}

fn centered_rect(width: u16, height: u16, area: Rect) -> Rect {
    let w = width.min(area.width);
    let h = height.min(area.height);
    Rect {
        x: area.x + (area.width.saturating_sub(w)) / 2,
        y: area.y + (area.height.saturating_sub(h)) / 2,
        width: w,
        height: h,
    }
}
