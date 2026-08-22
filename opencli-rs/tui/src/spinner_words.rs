//! Playful status words for the working spinner.
//!
//! A new word is picked when a turn starts, so it stays stable during the turn
//! but varies between turns — the same idea as Claude Code's rotating gerunds.

use rand::seq::IndexedRandom;

const WORDS: &[&str] = &[
    "Cogitating",
    "Percolating",
    "Ruminating",
    "Pondering",
    "Noodling",
    "Tinkering",
    "Conjuring",
    "Synthesizing",
    "Untangling",
    "Deliberating",
    "Assembling",
    "Brewing",
    "Wrangling",
    "Finagling",
    "Marinating",
    "Calibrating",
];

/// A random working word, e.g. "Cogitating". Deterministic under test so
/// snapshots and header assertions stay stable.
pub(crate) fn random() -> String {
    if cfg!(test) {
        return "Processing".to_string();
    }
    WORDS
        .choose(&mut rand::rng())
        .copied()
        .unwrap_or("Processing")
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn random_returns_a_known_word() {
        // Under test the picker is pinned to "Processing" for determinism.
        assert_eq!(random(), "Processing");
    }
}
