//! Automatic model routing across providers.
//!
//! When routing is enabled, each user turn is classified as simple or complex
//! and the matching model is chosen. Because every built-in model preset names
//! its own provider, selecting a model here is enough to also send the turn to
//! the right gateway — cheap work to a cheap gateway, hard work to a premium one.

use crate::config::types::Routing;

/// How a turn was classified, for logging and display.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Complexity {
    Simple,
    Complex,
}

/// Classify `text` using the configured thresholds. A turn is complex when it
/// is long enough or contains any complexity keyword; otherwise it is simple.
pub fn classify(text: &str, routing: &Routing) -> Complexity {
    let normalized = text.to_lowercase();
    let has_keyword = routing
        .complex_keywords
        .iter()
        .any(|keyword| !keyword.is_empty() && normalized.contains(&keyword.to_lowercase()));

    if has_keyword || text.chars().count() >= routing.complex_min_chars {
        Complexity::Complex
    } else {
        Complexity::Simple
    }
}

/// Pick the model slug for `text`, or `None` to leave the session model as-is.
/// Returns `None` when routing is disabled or the matched tier has no model
/// configured, so callers never force an empty model.
pub fn route_model(text: &str, routing: &Routing) -> Option<String> {
    if !routing.enabled {
        return None;
    }
    match classify(text, routing) {
        Complexity::Simple => routing.simple_model.clone(),
        Complexity::Complex => routing.complex_model.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn routing() -> Routing {
        Routing {
            enabled: true,
            simple_model: Some("glm-5.2".to_string()),
            complex_model: Some("claude-sonnet-4-5".to_string()),
            complex_min_chars: 280,
            complex_keywords: vec!["refactor".to_string(), "architecture".to_string()],
        }
    }

    #[test]
    fn should_route_short_plain_turn_to_the_simple_model() {
        let model = route_model("what does this function return?", &routing());
        assert_eq!(model.as_deref(), Some("glm-5.2"));
    }

    #[test]
    fn should_route_keyword_turn_to_the_complex_model() {
        let model = route_model("please refactor this module", &routing());
        assert_eq!(model.as_deref(), Some("claude-sonnet-4-5"));
    }

    #[test]
    fn should_route_long_turn_to_the_complex_model() {
        let long = "a ".repeat(200);
        assert_eq!(
            route_model(&long, &routing()).as_deref(),
            Some("claude-sonnet-4-5")
        );
    }

    #[test]
    fn should_not_route_when_disabled() {
        let mut routing = routing();
        routing.enabled = false;
        assert_eq!(route_model("refactor everything", &routing), None);
    }

    #[test]
    fn should_leave_model_untouched_when_tier_has_no_model() {
        let mut routing = routing();
        routing.simple_model = None;
        assert_eq!(route_model("hi", &routing), None);
    }
}
