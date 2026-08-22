//! Learned model context windows.
//!
//! Provider gateways report their real context window when they reject an
//! over-long request (`context_limit_tokens`). Rather than hard-coding a window
//! per model, opencli records that value here, keyed by model slug, and reuses
//! it so future turns auto-compact against the model's true limit — for any
//! model, without a code change.

use std::collections::HashMap;
use std::path::Path;
use std::path::PathBuf;

const STORE_FILE: &str = "model_windows.json";

fn store_path(opencli_home: &Path) -> PathBuf {
    opencli_home.join(STORE_FILE)
}

/// Load the learned window for `slug`, if one was recorded.
pub(crate) fn learned_window(opencli_home: &Path, slug: &str) -> Option<i64> {
    load(opencli_home).get(slug).copied()
}

/// Record `window` as the learned context window for `slug`, keeping the
/// smallest value seen so auto-compaction stays safely under the real limit.
pub(crate) fn record_window(opencli_home: &Path, slug: &str, window: i64) {
    if window <= 0 {
        return;
    }
    let mut map = load(opencli_home);
    let entry = map.entry(slug.to_string()).or_insert(window);
    *entry = (*entry).min(window);
    let value = *entry;
    // Re-borrow to write the possibly-updated value without aliasing.
    map.insert(slug.to_string(), value);
    save(opencli_home, &map);
}

fn load(opencli_home: &Path) -> HashMap<String, i64> {
    std::fs::read_to_string(store_path(opencli_home))
        .ok()
        .and_then(|contents| serde_json::from_str(&contents).ok())
        .unwrap_or_default()
}

fn save(opencli_home: &Path, map: &HashMap<String, i64>) {
    if let Ok(contents) = serde_json::to_string_pretty(map) {
        let _ = std::fs::write(store_path(opencli_home), contents);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn should_record_and_read_back_a_learned_window() {
        let dir = tempdir().expect("tempdir");
        assert_eq!(learned_window(dir.path(), "glm-5.2"), None);
        record_window(dir.path(), "glm-5.2", 202_752);
        assert_eq!(learned_window(dir.path(), "glm-5.2"), Some(202_752));
    }

    #[test]
    fn should_keep_the_smallest_window_seen() {
        let dir = tempdir().expect("tempdir");
        record_window(dir.path(), "m", 200_000);
        record_window(dir.path(), "m", 150_000);
        record_window(dir.path(), "m", 180_000);
        assert_eq!(learned_window(dir.path(), "m"), Some(150_000));
    }

    #[test]
    fn should_ignore_non_positive_windows() {
        let dir = tempdir().expect("tempdir");
        record_window(dir.path(), "m", 0);
        record_window(dir.path(), "m", -5);
        assert_eq!(learned_window(dir.path(), "m"), None);
    }
}
