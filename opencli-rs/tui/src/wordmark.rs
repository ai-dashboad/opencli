//! The opencli wordmark, rendered with a flowing cyan-to-magenta gradient.
//!
//! `gradient_spans` colors each character along the gradient; shifting `phase`
//! sweeps the colors sideways, which the animated splash uses to make the
//! gradient flow.

use ratatui::style::Color;
use ratatui::style::Stylize;
use ratatui::text::Span;

/// Endpoints of the sweep: cyan -> violet -> magenta, then back.
const STOPS: &[(u8, u8, u8)] = &[
    (0x22, 0xd3, 0xee), // cyan
    (0x81, 0x8c, 0xf8), // indigo
    (0xc0, 0x84, 0xfc), // violet
    (0xe8, 0x79, 0xf9), // magenta
    (0x81, 0x8c, 0xf8), // indigo (loop back for a seamless sweep)
];

/// Color at position `t` in `[0.0, 1.0)` along the looping gradient.
///
/// True colour, against the project's own rule. The rule is right for interface
/// text — an ANSI colour follows the reader's theme, and a hardcoded one can
/// come out unreadable against it. A gradient is not interface text: it is the
/// mark, it appears once on a screen that is otherwise empty, and there are no
/// ANSI colours to interpolate between. A terminal without true-colour support
/// approximates it, which is the worst that happens here.
#[allow(clippy::disallowed_methods)]
fn color_at(t: f32) -> Color {
    let t = t.rem_euclid(1.0);
    let segments = STOPS.len() - 1;
    let scaled = t * segments as f32;
    let index = (scaled as usize).min(segments - 1);
    let local = scaled - index as f32;
    let (r0, g0, b0) = STOPS[index];
    let (r1, g1, b1) = STOPS[index + 1];
    let lerp = |a: u8, b: u8| (a as f32 + (b as f32 - a as f32) * local) as u8;
    Color::Rgb(lerp(r0, r1), lerp(g0, g1), lerp(b0, b1))
}

/// Render `text` as bold gradient-colored spans. `phase` (any integer, usually a
/// millisecond tick) slides the gradient so successive frames appear to flow.
pub(crate) fn gradient_spans(text: &str, phase: u64) -> Vec<Span<'static>> {
    let chars: Vec<char> = text.chars().collect();
    let len = chars.len().max(1) as f32;
    // One full color cycle spans the word; phase shifts by ~1 cycle / 2s.
    let shift = (phase % 2000) as f32 / 2000.0;
    chars
        .into_iter()
        .enumerate()
        .map(|(i, ch)| {
            let t = i as f32 / len + shift;
            Span::from(ch.to_string()).fg(color_at(t)).bold()
        })
        .collect()
}

/// Like [`gradient_spans`] but driven by wall-clock time, so the gradient
/// visibly flows across the text on each redraw. Used for the animated
/// "Processing" status header.
pub(crate) fn flowing_gradient_spans(text: &str) -> Vec<Span<'static>> {
    let phase = crate::shimmer::elapsed_since_start().as_millis() as u64;
    gradient_spans(text, phase)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn produces_one_span_per_character() {
        let spans = gradient_spans("opencli", 0);
        assert_eq!(spans.len(), 7);
    }

    #[test]
    fn color_at_is_stable_across_the_loop_boundary() {
        // The gradient loops, so t and t+1 map to the same color.
        assert_eq!(color_at(0.0), color_at(1.0));
    }

    #[test]
    fn empty_text_yields_no_spans() {
        assert!(gradient_spans("", 0).is_empty());
    }
}
