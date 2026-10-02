//! Rendering. Three views (idle list / live meeting / configuration) plus a modal prompt.

use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Cell, Clear, Paragraph, Row, Table, Wrap};
use ratatui::Frame;

use crate::app::{App, InputKind, Mode};
use crate::paths;

pub fn draw(f: &mut Frame, app: &App) {
    let area = f.area();
    // Lay the hints out for the real width and reserve exactly the rows they need, so the
    // tail (e.g. "c configuration") is never cut off on a narrow window.
    let hint_lines = layout_hints(&hint_segments(app), area.width as usize);
    let message_rows = u16::from(app.message_text().is_some());
    let footer_height = (hint_lines.len() as u16 + message_rows).max(1);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(3),
            Constraint::Length(footer_height),
        ])
        .split(area);

    draw_header(f, app, chunks[0]);
    match app.mode {
        Mode::Live => draw_live(f, app, chunks[1]),
        Mode::Settings => draw_settings(f, app, chunks[1]),
        _ => draw_list(f, app, chunks[1]),
    }
    draw_footer(f, app, &hint_lines, chunks[2]);

    if let Mode::Input(kind) = app.mode {
        draw_input(f, app, kind, area);
    }
}

fn draw_header(f: &mut Frame, app: &App, area: Rect) {
    let status = app.live.status.to_ascii_lowercase();
    let (label, color) = if !app.live.active {
        ("IDLE", Color::DarkGray)
    } else if status == "paused" {
        ("MEETING PAUSED", Color::Yellow)
    } else if status == "stopping" || status == "transcribing" {
        ("MEETING FINISHING", Color::Cyan)
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

/// Fixed widths of the meetings table. The title column takes whatever is left over.
const DATE_W: u16 = 16; // 2026-10-02 11:36
const DURATION_W: u16 = 10; // 55m 41s / 1h 01m
const CHUNKS_W: u16 = 6; // "Chunks"
const STATUS_W: u16 = 9; // "completed"

/// Column plan for the meetings table, sized to the available width.
///
/// The fixed columns always keep their width and the title is the one that flexes (and
/// gets ellipsized). Before this, the sum of the constraints could exceed the width and
/// ratatui squeezed *every* column, truncating the date, duration and status.
struct ListLayout {
    headers: Vec<&'static str>,
    widths: Vec<Constraint>,
    title_width: u16,
    show_duration: bool,
    show_chunks: bool,
}

fn list_layout(width: u16) -> ListLayout {
    // 2 border cells + 2 for the "> " highlight + one space between each pair of columns.
    let show_duration = width >= 58;
    let show_chunks = width >= 66;
    let columns = 3 + u16::from(show_duration) + u16::from(show_chunks);
    let overhead = 2 + 2 + (columns - 1);

    let mut fixed = DATE_W + STATUS_W;
    if show_duration {
        fixed += DURATION_W;
    }
    if show_chunks {
        fixed += CHUNKS_W;
    }
    let title_width = width.saturating_sub(overhead + fixed).max(12);

    let mut headers: Vec<&'static str> = vec!["Title", "Date"];
    let mut widths: Vec<Constraint> =
        vec![Constraint::Length(title_width), Constraint::Length(DATE_W)];
    if show_duration {
        headers.push("Duration");
        widths.push(Constraint::Length(DURATION_W));
    }
    if show_chunks {
        headers.push("Chunks");
        widths.push(Constraint::Length(CHUNKS_W));
    }
    headers.push("Status");
    widths.push(Constraint::Length(STATUS_W));

    ListLayout {
        headers,
        widths,
        title_width,
        show_duration,
        show_chunks,
    }
}

fn draw_list(f: &mut Frame, app: &App, area: Rect) {
    let layout = list_layout(area.width);
    let (title_width, show_duration, show_chunks) = (
        layout.title_width as usize,
        layout.show_duration,
        layout.show_chunks,
    );

    let header =
        Row::new(layout.headers.clone()).style(Style::default().add_modifier(Modifier::BOLD));

    let rows = app.meetings.iter().map(|m| {
        let mut cells = vec![
            Cell::from(ellipsize(&m.display_title(), title_width)),
            Cell::from(m.started_local()),
        ];
        if show_duration {
            cells.push(Cell::from(m.duration_human()));
        }
        if show_chunks {
            cells.push(Cell::from(m.chunks().to_string()));
        }
        cells.push(Cell::from(m.status_str().to_string()));
        Row::new(cells)
    });

    let title = format!(
        "Saved meetings ({})   export -> {}",
        app.meetings.len(),
        shorten_home(&app.export_dir_display())
    );

    let table = Table::new(rows, layout.widths)
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

/// Truncate `s` to `max` columns, adding `…` when it does not fit.
fn ellipsize(s: &str, max: usize) -> String {
    if max == 0 {
        return String::new();
    }
    if s.chars().count() <= max {
        return s.to_string();
    }
    let mut out: String = s.chars().take(max - 1).collect();
    out.push('…');
    out
}

/// `/home/rodrigo/foo` -> `~/foo`, so the table title is not dominated by the path.
fn shorten_home(path: &str) -> String {
    let home = paths::home().display().to_string();
    if path == home {
        "~".to_string()
    } else if let Some(rest) = path.strip_prefix(&format!("{home}/")) {
        format!("~/{rest}")
    } else {
        path.to_string()
    }
}

fn draw_settings(f: &mut Frame, app: &App, area: Rect) {
    let header =
        Row::new(vec!["Setting", "Value"]).style(Style::default().add_modifier(Modifier::BOLD));
    let rows = app
        .settings_rows()
        .into_iter()
        .map(|(label, value)| Row::new(vec![Cell::from(label), Cell::from(value)]));
    let widths = [Constraint::Length(22), Constraint::Min(24)];

    let table = Table::new(rows, widths)
        .header(header)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title("Configuration"),
        )
        .row_highlight_style(
            Style::default()
                .add_modifier(Modifier::REVERSED)
                .add_modifier(Modifier::BOLD),
        )
        .highlight_symbol("> ");

    let mut state = app.settings.clone();
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

fn draw_footer(f: &mut Frame, app: &App, hint_lines: &[String], area: Rect) {
    let mut lines: Vec<Line> = hint_lines
        .iter()
        .map(|hint| {
            Line::from(Span::styled(
                hint.clone(),
                Style::default().fg(Color::DarkGray),
            ))
        })
        .collect();
    if let Some(msg) = app.message_text() {
        lines.push(Line::from(Span::styled(
            msg.to_string(),
            Style::default().fg(Color::Green),
        )));
    }
    f.render_widget(Paragraph::new(lines), area);
}

/// The key hints for the current mode, as separate pieces so they can wrap.
fn hint_segments(app: &App) -> Vec<String> {
    let segments: &[&str] = match app.mode {
        Mode::Input(InputKind::Name) => &["type a name", "Enter start", "Esc cancel"],
        Mode::Input(InputKind::ExportDir) => {
            &["type a folder (or ~/...)", "Enter save", "Esc cancel"]
        }
        Mode::Live => &["p pause/resume", "x stop", "q quit"],
        Mode::Settings => &["↑↓ move", "Enter change", "Esc back"],
        Mode::List => &[
            "s start",
            "e/Enter export",
            "o folder",
            "O meeting dir",
            "c configuration",
            "r refresh",
            "q quit",
        ],
    };
    segments.iter().map(|segment| segment.to_string()).collect()
}

/// Greedy layout of the hints into lines no wider than `width` columns.
///
/// Every segment is kept: on a narrow window the hints wrap to more lines instead of being
/// cut off at the right edge.
fn layout_hints(segments: &[String], width: usize) -> Vec<String> {
    const SEP: &str = " · ";
    let width = width.max(1);
    let mut lines: Vec<String> = Vec::new();
    let mut current = String::new();
    for segment in segments {
        if current.is_empty() {
            current = segment.clone();
            continue;
        }
        let candidate = format!("{current}{SEP}{segment}");
        if candidate.chars().count() <= width {
            current = candidate;
        } else {
            lines.push(std::mem::take(&mut current));
            current = segment.clone();
        }
    }
    if !current.is_empty() {
        lines.push(current);
    }
    if lines.is_empty() {
        lines.push(String::new());
    }
    lines
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

#[cfg(test)]
mod tests {
    use super::*;

    fn list_segments() -> Vec<String> {
        [
            "s start",
            "e/Enter export",
            "o folder",
            "O meeting dir",
            "c configuration",
            "r refresh",
            "q quit",
        ]
        .iter()
        .map(|segment| segment.to_string())
        .collect()
    }

    #[test]
    fn wide_window_uses_a_single_line() {
        let lines = layout_hints(&list_segments(), 100);
        assert_eq!(lines.len(), 1);
        assert!(lines[0].contains("c configuration"));
    }

    #[test]
    fn narrow_window_wraps_without_losing_any_hint() {
        let segments = list_segments();
        let lines = layout_hints(&segments, 40);
        assert!(lines.len() > 1, "should wrap at 40 columns");
        for line in &lines {
            assert!(
                line.chars().count() <= 40,
                "line wider than the window: {line}"
            );
        }
        for segment in &segments {
            assert!(
                lines.iter().any(|line| line.contains(segment.as_str())),
                "hint lost when wrapping: {segment}"
            );
        }
    }

    #[test]
    fn tiny_width_still_keeps_every_segment() {
        let segments = list_segments();
        let lines = layout_hints(&segments, 1);
        for segment in &segments {
            assert!(lines.iter().any(|line| line == segment), "lost {segment}");
        }
    }

    #[test]
    fn ellipsize_keeps_short_text_and_marker_on_long() {
        assert_eq!(ellipsize("daily", 10), "daily");
        let cut = ellipsize("daily 2026-10-02 09:32:25", 10);
        assert_eq!(cut.chars().count(), 10);
        assert!(cut.ends_with('…'), "{cut}");
    }

    #[test]
    fn list_layout_keeps_the_fixed_columns_at_100_cols() {
        let layout = list_layout(100);
        assert_eq!(
            layout.headers,
            ["Title", "Date", "Duration", "Chunks", "Status"]
        );
        assert!(
            layout.title_width >= 20,
            "title column too narrow: {}",
            layout.title_width
        );
        // borders + highlight + spacing + every column must not exceed the width.
        let total = 2 + 2 + 4 + layout.title_width + DATE_W + DURATION_W + CHUNKS_W + STATUS_W;
        assert!(total <= 100, "columns overflow the window: {total}");
    }

    #[test]
    fn list_layout_drops_columns_when_narrow() {
        let narrow = list_layout(50);
        assert!(!narrow.show_chunks, "chunks should be dropped at 50 cols");
        assert!(!narrow.show_duration);
        assert!(narrow.title_width >= 12);
    }
}
