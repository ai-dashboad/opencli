//! Models the user can install, as data rather than code.
//!
//! Two sources, merged. The bundled entries ship with the build and are
//! updated by releasing a new one. The user's own live in
//! `~/.opencli/models.toml`, and an entry there with the same tag replaces the
//! bundled one entirely rather than being merged field by field — a half-edited
//! entry is harder to reason about than a replaced one.
//!
//! This mirrors [`crate::providers`], which was already data. Having the two
//! catalogues follow different rules made one of them impossible to extend
//! without a rebuild, for no reason anyone could state.
//!
//! One field carries most of the weight: whether a model calls tools. A model
//! that cannot is close to useless for agent work here, and a catalogue that
//! left it out would be recommending disappointment.

use serde::Deserialize;
use serde::Serialize;
use std::path::Path;

/// Entries embedded at build time. Adding one is a new `.toml` file here.
static CATALOG_DIR: include_dir::Dir<'_> =
    include_dir::include_dir!("$CARGO_MANIFEST_DIR/src/model_catalog/entries");

/// Where a user's own entries live, relative to their OpenCLI home.
const USER_FILE: &str = "models.toml";

/// A model on offer.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CatalogModel {
    /// What to pull. Whatever the source, this goes to the runtime unchanged:
    /// `qwen2.5-coder:7b`, `hf.co/owner/repo:Q4_K_M`, `modelscope.cn/owner/repo`.
    pub tag: String,
    pub name: String,
    /// What it is for, in a sentence someone choosing can act on.
    pub note: String,
    /// Approximate download, for judging what will fit.
    #[serde(default)]
    pub size_gb: f32,
    /// Memory it wants to run comfortably — larger than the download, because
    /// the weights are not the only thing resident.
    #[serde(default)]
    pub needs_gb: f32,
    /// Whether it calls tools. The single most useful fact in the catalogue.
    #[serde(default)]
    pub tools: bool,
    #[serde(default)]
    pub context: u32,
    /// What the model is for, which is how someone chooses one.
    ///
    /// Grouped by purpose rather than by who published it: a person picking a
    /// model is deciding what they want to do, not which company they prefer.
    #[serde(default = "default_purpose")]
    pub purpose: String,
    /// Set on entries the user added, so the UI can offer to edit those and
    /// not the bundled ones.
    #[serde(default, skip_deserializing)]
    pub user_defined: bool,
}

fn default_purpose() -> String {
    "general".to_string()
}

/// The purposes entries are grouped under, in the order they are shown.
///
/// A fixed list rather than whatever appears in the files: an entry with a
/// misspelt purpose would otherwise create a group of one, silently.
pub const PURPOSES: &[(&str, &str)] = &[
    ("coding", "Coding"),
    ("general", "General purpose"),
    ("small", "Small and fast"),
];

/// Whether a purpose is one this build groups by.
pub fn is_known_purpose(purpose: &str) -> bool {
    PURPOSES.iter().any(|(id, _)| *id == purpose)
}

/// A user's catalogue file.
#[derive(Debug, Default, Serialize, Deserialize)]
struct UserCatalog {
    #[serde(default)]
    models: Vec<CatalogModel>,
}

/// Entries that ship with the build.
pub fn bundled() -> Vec<CatalogModel> {
    let mut entries: Vec<CatalogModel> = CATALOG_DIR
        .files()
        .filter(|file| file.path().extension().is_some_and(|ext| ext == "toml"))
        .filter_map(|file| toml::from_str(file.contents_utf8()?).ok())
        .collect();
    entries.sort_by(|a, b| a.needs_gb.total_cmp(&b.needs_gb).then(a.tag.cmp(&b.tag)));
    entries
}

fn user_path(opencli_home: &Path) -> std::path::PathBuf {
    opencli_home.join(USER_FILE)
}

/// Entries the user added. A missing or unreadable file yields none: a broken
/// catalogue should cost the additions, not the whole panel.
pub fn user_entries(opencli_home: &Path) -> Vec<CatalogModel> {
    let Ok(text) = std::fs::read_to_string(user_path(opencli_home)) else {
        return Vec::new();
    };
    let parsed: UserCatalog = match toml::from_str(&text) {
        Ok(parsed) => parsed,
        Err(_) => return Vec::new(),
    };
    parsed
        .models
        .into_iter()
        .map(|mut entry| {
            entry.user_defined = true;
            entry
        })
        .collect()
}

/// Everything on offer, with the user's entries winning on a shared tag.
pub fn all(opencli_home: &Path) -> Vec<CatalogModel> {
    let mine = user_entries(opencli_home);
    let overridden: std::collections::HashSet<&str> =
        mine.iter().map(|entry| entry.tag.as_str()).collect();

    let mut entries: Vec<CatalogModel> = bundled()
        .into_iter()
        .filter(|entry| !overridden.contains(entry.tag.as_str()))
        .collect();
    entries.extend(mine);
    entries.sort_by(|a, b| a.needs_gb.total_cmp(&b.needs_gb).then(a.tag.cmp(&b.tag)));
    entries
}

/// Add or replace one of the user's entries.
pub fn upsert(opencli_home: &Path, entry: CatalogModel) -> std::io::Result<()> {
    let mut mine = user_entries(opencli_home);
    match mine.iter_mut().find(|existing| existing.tag == entry.tag) {
        Some(existing) => *existing = entry,
        None => mine.push(entry),
    }
    write(opencli_home, &mine)
}

/// Remove one of the user's entries.
///
/// Returns whether anything was removed. A bundled entry cannot be deleted —
/// only shadowed by one with the same tag — so that a build's own catalogue
/// stays whole.
pub fn remove(opencli_home: &Path, tag: &str) -> std::io::Result<bool> {
    let mut mine = user_entries(opencli_home);
    let before = mine.len();
    mine.retain(|entry| entry.tag != tag);
    let removed = mine.len() != before;
    if removed {
        write(opencli_home, &mine)?;
    }
    Ok(removed)
}

fn write(opencli_home: &Path, entries: &[CatalogModel]) -> std::io::Result<()> {
    let catalog = UserCatalog {
        models: entries.to_vec(),
    };
    let text = toml::to_string_pretty(&catalog).map_err(std::io::Error::other)?;
    std::fs::write(
        user_path(opencli_home),
        format!(
            "# Models you have added to the catalogue.\n\
             # An entry here replaces a bundled one with the same tag.\n\n{text}"
        ),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn entry(tag: &str, needs: f32) -> CatalogModel {
        CatalogModel {
            tag: tag.into(),
            name: tag.into(),
            note: "a note".into(),
            size_gb: needs - 1.0,
            needs_gb: needs,
            tools: true,
            context: 32768,
            purpose: "general".into(),
            user_defined: false,
        }
    }

    #[test]
    fn should_ship_a_catalogue_that_parses() {
        let entries = bundled();
        assert!(entries.len() >= 8, "got {}", entries.len());
        for entry in &entries {
            assert!(!entry.tag.is_empty());
            assert!(!entry.note.is_empty(), "`{}` needs a note", entry.tag);
            assert!(
                entry.needs_gb > 0.0,
                "`{}` needs a memory figure",
                entry.tag
            );
        }
    }

    #[test]
    fn should_be_honest_about_models_that_do_not_call_tools() {
        // A catalogue that hid this would recommend disappointment.
        let entries = bundled();
        let without: Vec<&CatalogModel> = entries.iter().filter(|entry| !entry.tools).collect();
        assert!(
            !without.is_empty(),
            "the catalogue should include some, and say so"
        );
        for entry in without {
            assert!(
                entry.note.to_lowercase().contains("tool"),
                "`{}` must say so in its note",
                entry.tag
            );
        }
    }

    #[test]
    fn should_group_every_bundled_entry_under_a_known_purpose() {
        // A misspelt purpose would otherwise make a group of one, silently.
        for entry in bundled() {
            assert!(
                is_known_purpose(&entry.purpose),
                "`{}` has purpose `{}`, which is not one of the groups",
                entry.tag,
                entry.purpose
            );
        }
    }

    #[test]
    fn should_have_something_to_offer_in_every_group() {
        // An empty heading is worse than no heading.
        for (id, label) in PURPOSES {
            assert!(
                bundled().iter().any(|entry| entry.purpose == *id),
                "nothing is offered under `{label}`"
            );
        }
    }

    #[test]
    fn should_order_by_what_a_machine_needs() {
        // Someone choosing scans from the top; the smallest first is the order
        // that answers "what can I run" without arithmetic.
        let entries = bundled();
        for pair in entries.windows(2) {
            assert!(pair[0].needs_gb <= pair[1].needs_gb);
        }
    }

    #[test]
    fn should_return_only_bundled_entries_when_the_user_added_none() {
        let dir = tempdir().expect("tempdir");
        assert_eq!(all(dir.path()).len(), bundled().len());
        assert!(all(dir.path()).iter().all(|entry| !entry.user_defined));
    }

    #[test]
    fn should_add_an_entry_of_the_users_own() {
        let dir = tempdir().expect("tempdir");
        upsert(dir.path(), entry("mine:7b", 8.0)).expect("upsert");

        let entries = all(dir.path());
        let mine = entries
            .iter()
            .find(|found| found.tag == "mine:7b")
            .expect("listed");
        assert!(mine.user_defined, "the UI needs to know which are editable");
        assert_eq!(entries.len(), bundled().len() + 1);
    }

    #[test]
    fn should_let_a_users_entry_replace_a_bundled_one() {
        // Replaced whole rather than merged field by field: a half-overridden
        // entry is harder to reason about than a replaced one.
        let dir = tempdir().expect("tempdir");
        let bundled_tag = bundled()[0].tag.clone();
        let mut replacement = entry(&bundled_tag, 99.0);
        replacement.note = "my own words".into();
        upsert(dir.path(), replacement).expect("upsert");

        let entries = all(dir.path());
        let found: Vec<&CatalogModel> = entries
            .iter()
            .filter(|entry| entry.tag == bundled_tag)
            .collect();
        assert_eq!(found.len(), 1, "one entry per tag, not two");
        assert_eq!(found[0].note, "my own words");
        assert!(found[0].user_defined);
    }

    #[test]
    fn should_update_an_entry_rather_than_adding_it_twice() {
        let dir = tempdir().expect("tempdir");
        upsert(dir.path(), entry("mine:7b", 8.0)).expect("first");
        let mut changed = entry("mine:7b", 8.0);
        changed.note = "changed".into();
        upsert(dir.path(), changed).expect("second");

        let mine = user_entries(dir.path());
        assert_eq!(mine.len(), 1);
        assert_eq!(mine[0].note, "changed");
    }

    #[test]
    fn should_remove_a_users_entry_and_restore_what_it_shadowed() {
        let dir = tempdir().expect("tempdir");
        let bundled_tag = bundled()[0].tag.clone();
        let mut replacement = entry(&bundled_tag, 99.0);
        replacement.note = "mine".into();
        upsert(dir.path(), replacement).expect("upsert");

        assert!(remove(dir.path(), &bundled_tag).expect("remove"));

        let entries = all(dir.path());
        let restored = entries
            .iter()
            .find(|entry| entry.tag == bundled_tag)
            .expect("the bundled entry comes back");
        assert!(!restored.user_defined);
    }

    #[test]
    fn should_report_nothing_removed_for_an_entry_that_was_never_added() {
        let dir = tempdir().expect("tempdir");
        assert!(!remove(dir.path(), "never-added").expect("remove"));
    }

    #[test]
    fn should_ignore_a_broken_user_file_rather_than_losing_the_catalogue() {
        // A typo in one file should cost the additions, not the whole panel.
        let dir = tempdir().expect("tempdir");
        std::fs::write(user_path(dir.path()), "this is not toml [[[").expect("write");
        assert_eq!(all(dir.path()).len(), bundled().len());
    }
}
