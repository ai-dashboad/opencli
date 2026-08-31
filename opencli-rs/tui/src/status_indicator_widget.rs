//! A live status indicator that shows the *latest* log line emitted by the
//! application while the agent is processing a long‑running task.

use std::time::Duration;
use std::time::Instant;

use opencli_core::protocol::Op;
use crossterm::event::KeyCode;
use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::Stylize;
use ratatui::text::Line;
use ratatui::text::Span;
use ratatui::text::Text;
use ratatui::widgets::Paragraph;
use ratatui::widgets::WidgetRef;
use unicode_width::UnicodeWidthStr;

use crate::app_event::AppEvent;
use crate::app_event_sender::AppEventSender;
use crate::exec_cell::spinner;
use crate::key_hint;
use crate::render::renderable::Renderable;
use crate::text_formatting::capitalize_first;
use crate::tui::FrameRequester;
use crate::wrapping::RtOptions;
use crate::wrapping::word_wrap_lines;

const DETAILS_MAX_LINES: usize = 3;
const DETAILS_PREFIX: &str = "  ⎿ ";

/// How long the model may produce nothing before the status line says so.
///
/// A bare spinner and a ticking clock cannot distinguish "thinking" from
/// "the gateway is wedged", which is the single most confusing way for a turn
/// to fail. After this long, say what is being waited on and how to get out.
const STALL_NOTICE_AFTER: Duration = Duration::from_secs(15);

pub(crate) struct StatusIndicatorWidget {
    /// Animated header text (defaults to "Processing").
    header: String,
    details: Option<String>,
    show_interrupt_hint: bool,
    /// Set while a turn is running and the model has not produced anything yet.
    waiting_since: Option<Instant>,

    elapsed_running: Duration,
    last_resume_at: Instant,
    is_paused: bool,
    app_event_tx: AppEventSender,
    frame_requester: FrameRequester,
    animations_enabled: bool,
}

// Format elapsed seconds into a compact human-friendly form used by the status line.
// Examples: 0s, 59s, 1m 00s, 59m 59s, 1h 00m 00s, 2h 03m 09s
pub fn fmt_elapsed_compact(elapsed_secs: u64) -> String {
    if elapsed_secs < 60 {
        return format!("{elapsed_secs}s");
    }
    if elapsed_secs < 3600 {
        let minutes = elapsed_secs / 60;
        let seconds = elapsed_secs % 60;
        return format!("{minutes}m {seconds:02}s");
    }
    let hours = elapsed_secs / 3600;
    let minutes = (elapsed_secs % 3600) / 60;
    let seconds = elapsed_secs % 60;
    format!("{hours}h {minutes:02}m {seconds:02}s")
}

impl StatusIndicatorWidget {
    pub(crate) fn new(
        app_event_tx: AppEventSender,
        frame_requester: FrameRequester,
        animations_enabled: bool,
    ) -> Self {
        Self {
            header: crate::spinner_words::random(),
            details: None,
            show_interrupt_hint: true,
            waiting_since: None,
            elapsed_running: Duration::ZERO,
            last_resume_at: Instant::now(),
            is_paused: false,

            app_event_tx,
            frame_requester,
            animations_enabled,
        }
    }

    pub(crate) fn interrupt(&self) {
        self.app_event_tx.send(AppEvent::OpenCLIOp(Op::Interrupt));
    }

    /// Update the animated header label (left of the brackets).
    pub(crate) fn update_header(&mut self, header: String) {
        self.header = header;
    }

    /// Update the details text shown below the header.
    pub(crate) fn update_details(&mut self, details: Option<String>) {
        self.details = details
            .filter(|details| !details.is_empty())
            .map(|details| capitalize_first(details.trim_start()));
    }

    #[cfg(test)]
    pub(crate) fn header(&self) -> &str {
        &self.header
    }

    #[cfg(test)]
    pub(crate) fn details(&self) -> Option<&str> {
        self.details.as_deref()
    }

    pub(crate) fn set_interrupt_hint_visible(&mut self, visible: bool) {
        self.show_interrupt_hint = visible;
    }

    #[cfg(test)]
    pub(crate) fn interrupt_hint_visible(&self) -> bool {
        self.show_interrupt_hint
    }

    pub(crate) fn pause_timer(&mut self) {
        self.pause_timer_at(Instant::now());
    }

    pub(crate) fn resume_timer(&mut self) {
        self.resume_timer_at(Instant::now());
    }

    pub(crate) fn pause_timer_at(&mut self, now: Instant) {
        if self.is_paused {
            return;
        }
        self.elapsed_running += now.saturating_duration_since(self.last_resume_at);
        self.is_paused = true;
    }

    pub(crate) fn resume_timer_at(&mut self, now: Instant) {
        if !self.is_paused {
            return;
        }
        self.last_resume_at = now;
        self.is_paused = false;
        self.frame_requester.schedule_frame();
    }

    fn elapsed_duration_at(&self, now: Instant) -> Duration {
        let mut elapsed = self.elapsed_running;
        if !self.is_paused {
            elapsed += now.saturating_duration_since(self.last_resume_at);
        }
        elapsed
    }

    fn elapsed_seconds_at(&self, now: Instant) -> u64 {
        self.elapsed_duration_at(now).as_secs()
    }

    pub fn elapsed_seconds(&self) -> u64 {
        self.elapsed_seconds_at(Instant::now())
    }

    /// Mark whether the turn is waiting on the model's first output.
    ///
    /// Called with `true` when a turn starts and `false` as soon as anything
    /// arrives, so the stall notice only ever describes a genuinely silent
    /// gateway.
    pub(crate) fn set_waiting_for_model(&mut self, waiting: bool) {
        match (waiting, self.waiting_since) {
            // Already waiting: keep the original instant so the notice reports
            // the full wait rather than restarting on every event.
            (true, Some(_)) => {}
            (true, None) => self.waiting_since = Some(Instant::now()),
            (false, _) => self.waiting_since = None,
        }
    }

    /// Text for the details slot: whatever the session set, or a stall notice
    /// once the model has been silent long enough to be worth mentioning.
    fn effective_details(&self, now: Instant) -> Option<String> {
        if let Some(details) = self.details.clone() {
            return Some(details);
        }
        let waited = now.saturating_duration_since(self.waiting_since?);
        if waited < STALL_NOTICE_AFTER {
            return None;
        }
        Some(format!(
            "No response from the model yet ({}) — it will reconnect automatically if the connection has stalled.",
            fmt_elapsed_compact(waited.as_secs())
        ))
    }

    /// Wrap the details text into a fixed width and return the lines, truncating if necessary.
    fn wrapped_details_lines(&self, width: u16) -> Vec<Line<'static>> {
        self.wrapped_details_lines_at(width, Instant::now())
    }

    fn wrapped_details_lines_at(&self, width: u16, now: Instant) -> Vec<Line<'static>> {
        let Some(details) = self.effective_details(now) else {
            return Vec::new();
        };
        let details = details.as_str();
        if width == 0 {
            return Vec::new();
        }

        let prefix_width = UnicodeWidthStr::width(DETAILS_PREFIX);
        let opts = RtOptions::new(usize::from(width))
            .initial_indent(Line::from(DETAILS_PREFIX.dim()))
            .subsequent_indent(Line::from(Span::from(" ".repeat(prefix_width)).dim()))
            .break_words(true);

        let mut out = word_wrap_lines(details.lines().map(|line| vec![line.dim()]), opts);

        if out.len() > DETAILS_MAX_LINES {
            out.truncate(DETAILS_MAX_LINES);
            let content_width = usize::from(width).saturating_sub(prefix_width).max(1);
            let max_base_len = content_width.saturating_sub(1);
            if let Some(last) = out.last_mut()
                && let Some(span) = last.spans.last_mut()
            {
                let trimmed: String = span.content.as_ref().chars().take(max_base_len).collect();
                *span = format!("{trimmed}…").dim();
            }
        }

        out
    }
}

impl Renderable for StatusIndicatorWidget {
    fn desired_height(&self, width: u16) -> u16 {
        1 + u16::try_from(self.wrapped_details_lines(width).len()).unwrap_or(0)
    }

    fn render(&self, area: Rect, buf: &mut Buffer) {
        if area.is_empty() {
            return;
        }

        // Schedule next animation frame.
        self.frame_requester
            .schedule_frame_in(Duration::from_millis(32));
        let now = Instant::now();
        let elapsed_duration = self.elapsed_duration_at(now);
        let pretty_elapsed = fmt_elapsed_compact(elapsed_duration.as_secs());

        let mut spans = Vec::with_capacity(5);
        spans.push(spinner(Some(self.last_resume_at), self.animations_enabled));
        spans.push(" ".into());
        if self.animations_enabled {
            spans.extend(crate::wordmark::flowing_gradient_spans(&self.header));
        } else if !self.header.is_empty() {
            spans.push(self.header.clone().into());
        }
        spans.push(" ".into());
        if self.show_interrupt_hint {
            spans.extend(vec![
                format!("({pretty_elapsed} • ").dim(),
                key_hint::plain(KeyCode::Esc).into(),
                " to interrupt)".dim(),
            ]);
        } else {
            spans.push(format!("({pretty_elapsed})").dim());
        }

        let mut lines = Vec::new();
        lines.push(Line::from(spans));
        if area.height > 1 {
            // If there is enough space, add the details lines below the header.
            let details = self.wrapped_details_lines_at(area.width, now);
            let max_details = usize::from(area.height.saturating_sub(1));
            lines.extend(details.into_iter().take(max_details));
        }

        Paragraph::new(Text::from(lines)).render_ref(area, buf);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::app_event::AppEvent;
    use crate::app_event_sender::AppEventSender;
    use ratatui::Terminal;
    use ratatui::backend::TestBackend;
    use std::time::Duration;
    use std::time::Instant;
    use tokio::sync::mpsc::unbounded_channel;

    use pretty_assertions::assert_eq;

    #[test]
    fn fmt_elapsed_compact_formats_seconds_minutes_hours() {
        assert_eq!(fmt_elapsed_compact(0), "0s");
        assert_eq!(fmt_elapsed_compact(1), "1s");
        assert_eq!(fmt_elapsed_compact(59), "59s");
        assert_eq!(fmt_elapsed_compact(60), "1m 00s");
        assert_eq!(fmt_elapsed_compact(61), "1m 01s");
        assert_eq!(fmt_elapsed_compact(3 * 60 + 5), "3m 05s");
        assert_eq!(fmt_elapsed_compact(59 * 60 + 59), "59m 59s");
        assert_eq!(fmt_elapsed_compact(3600), "1h 00m 00s");
        assert_eq!(fmt_elapsed_compact(3600 + 60 + 1), "1h 01m 01s");
        assert_eq!(fmt_elapsed_compact(25 * 3600 + 2 * 60 + 3), "25h 02m 03s");
    }

    #[test]
    fn renders_with_working_header() {
        let (tx_raw, _rx) = unbounded_channel::<AppEvent>();
        let tx = AppEventSender::new(tx_raw);
        let w = StatusIndicatorWidget::new(tx, crate::tui::FrameRequester::test_dummy(), true);

        // Render into a fixed-size test terminal and snapshot the backend.
        let mut terminal = Terminal::new(TestBackend::new(80, 2)).expect("terminal");
        terminal
            .draw(|f| w.render(f.area(), f.buffer_mut()))
            .expect("draw");
        insta::assert_snapshot!(terminal.backend());
    }

    #[test]
    fn renders_truncated() {
        let (tx_raw, _rx) = unbounded_channel::<AppEvent>();
        let tx = AppEventSender::new(tx_raw);
        let w = StatusIndicatorWidget::new(tx, crate::tui::FrameRequester::test_dummy(), true);

        // Render into a fixed-size test terminal and snapshot the backend.
        let mut terminal = Terminal::new(TestBackend::new(20, 2)).expect("terminal");
        terminal
            .draw(|f| w.render(f.area(), f.buffer_mut()))
            .expect("draw");
        insta::assert_snapshot!(terminal.backend());
    }

    #[test]
    fn renders_wrapped_details_panama_two_lines() {
        let (tx_raw, _rx) = unbounded_channel::<AppEvent>();
        let tx = AppEventSender::new(tx_raw);
        let mut w = StatusIndicatorWidget::new(tx, crate::tui::FrameRequester::test_dummy(), false);
        w.update_details(Some("A man a plan a canal panama".to_string()));
        w.set_interrupt_hint_visible(false);

        // Freeze time-dependent rendering (elapsed + spinner) to keep the snapshot stable.
        w.is_paused = true;
        w.elapsed_running = Duration::ZERO;

        // Prefix is 4 columns, so a width of 30 yields a content width of 26: one column
        // short of fitting the whole phrase (27 cols), forcing exactly one wrap without ellipsis.
        let mut terminal = Terminal::new(TestBackend::new(30, 3)).expect("terminal");
        terminal
            .draw(|f| w.render(f.area(), f.buffer_mut()))
            .expect("draw");
        insta::assert_snapshot!(terminal.backend());
    }

    #[test]
    fn timer_pauses_when_requested() {
        let (tx_raw, _rx) = unbounded_channel::<AppEvent>();
        let tx = AppEventSender::new(tx_raw);
        let mut widget =
            StatusIndicatorWidget::new(tx, crate::tui::FrameRequester::test_dummy(), true);

        let baseline = Instant::now();
        widget.last_resume_at = baseline;

        let before_pause = widget.elapsed_seconds_at(baseline + Duration::from_secs(5));
        assert_eq!(before_pause, 5);

        widget.pause_timer_at(baseline + Duration::from_secs(5));
        let paused_elapsed = widget.elapsed_seconds_at(baseline + Duration::from_secs(10));
        assert_eq!(paused_elapsed, before_pause);

        widget.resume_timer_at(baseline + Duration::from_secs(10));
        let after_resume = widget.elapsed_seconds_at(baseline + Duration::from_secs(13));
        assert_eq!(after_resume, before_pause + 3);
    }

    fn widget_for_waiting_tests() -> StatusIndicatorWidget {
        let (tx_raw, _rx) = unbounded_channel::<AppEvent>();
        let tx = AppEventSender::new(tx_raw);
        StatusIndicatorWidget::new(tx, crate::tui::FrameRequester::test_dummy(), false)
    }

    #[test]
    fn should_stay_quiet_while_the_model_has_only_been_silent_briefly() {
        let mut w = widget_for_waiting_tests();
        let started = Instant::now();
        w.set_waiting_for_model(true);
        w.waiting_since = Some(started);

        assert_eq!(
            w.effective_details(started + STALL_NOTICE_AFTER - Duration::from_secs(1)),
            None
        );
    }

    #[test]
    fn should_report_the_wait_once_the_model_has_been_silent_long_enough() {
        let mut w = widget_for_waiting_tests();
        let started = Instant::now();
        w.set_waiting_for_model(true);
        w.waiting_since = Some(started);

        let details = w
            .effective_details(started + STALL_NOTICE_AFTER + Duration::from_secs(5))
            .expect("a stall notice is expected once the threshold has passed");
        assert!(
            details.contains("No response from the model yet"),
            "unexpected notice: {details}"
        );
        assert!(
            details.contains("20s"),
            "notice should report the wait: {details}"
        );
    }

    #[test]
    fn should_drop_the_stall_notice_as_soon_as_the_model_responds() {
        let mut w = widget_for_waiting_tests();
        let started = Instant::now();
        w.set_waiting_for_model(true);
        w.waiting_since = Some(started);
        w.set_waiting_for_model(false);

        assert_eq!(
            w.effective_details(started + STALL_NOTICE_AFTER + Duration::from_secs(60)),
            None
        );
    }

    #[test]
    fn should_report_the_whole_wait_rather_than_restarting_the_clock() {
        let mut w = widget_for_waiting_tests();
        let started = Instant::now();
        w.set_waiting_for_model(true);
        w.waiting_since = Some(started);
        // A second "still waiting" signal must not reset the elapsed wait.
        w.set_waiting_for_model(true);

        assert_eq!(w.waiting_since, Some(started));
    }

    #[test]
    fn should_prefer_session_details_over_the_stall_notice() {
        let mut w = widget_for_waiting_tests();
        let started = Instant::now();
        w.set_waiting_for_model(true);
        w.waiting_since = Some(started);
        w.update_details(Some("Retrying after 429".to_string()));

        let details = w
            .effective_details(started + STALL_NOTICE_AFTER + Duration::from_secs(5))
            .expect("session details should still be shown");
        assert_eq!(details, "Retrying after 429");
    }

    #[test]
    fn details_overflow_adds_ellipsis() {
        let (tx_raw, _rx) = unbounded_channel::<AppEvent>();
        let tx = AppEventSender::new(tx_raw);
        let mut w = StatusIndicatorWidget::new(tx, crate::tui::FrameRequester::test_dummy(), true);
        w.update_details(Some("abcd abcd abcd abcd".to_string()));

        let lines = w.wrapped_details_lines(6);
        assert_eq!(lines.len(), DETAILS_MAX_LINES);
        let last = lines.last().expect("expected last details line");
        assert!(
            last.spans[1].content.as_ref().ends_with("…"),
            "expected ellipsis in last line: {last:?}"
        );
    }
}
