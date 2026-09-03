//! Catalog of known OpenAI-compatible providers.
//!
//! The catalog is *data*, not compiled-in defaults: nothing here is active
//! until the user opts in with `opencli provider add <id>`, which writes a
//! `[model_providers.<id>]` section into their `config.toml`. Keeping it out of
//! [`crate::model_provider_info::built_in_model_providers`] is deliberate — the
//! binary stays provider-neutral and ships no keys, while users still get a
//! short path to a working setup instead of hand-writing base URLs.

use serde::Deserialize;

/// Catalog entries embedded at build time. Adding a provider is a new `.toml`
/// file here; no code change is required.
static CATALOG_DIR: include_dir::Dir<'_> =
    include_dir::include_dir!("$CARGO_MANIFEST_DIR/src/providers/catalog");

/// A provider the user can opt into.
#[derive(Debug, Clone, Deserialize, PartialEq)]
pub struct CatalogProvider {
    /// Key used in `[model_providers.<id>]` and in `opencli provider add <id>`.
    pub id: String,
    /// Human-readable name.
    pub name: String,
    /// OpenAI-compatible base URL.
    pub base_url: String,
    /// Wire protocol; every entry currently speaks Chat Completions.
    #[serde(default = "default_wire_api")]
    pub wire_api: String,
    /// Environment variable holding the API key, when one is needed.
    #[serde(default)]
    pub env_key: Option<String>,
    /// Where to read more, or sign up for a key.
    #[serde(default)]
    pub docs: Option<String>,
    /// Whether this provider needs a credential at all. Local runtimes do not.
    #[serde(default)]
    pub requires_key: bool,
    /// Localhost ports to probe during `provider scan`. Empty for hosted
    /// providers, which cannot be discovered by looking at this machine.
    #[serde(default)]
    pub scan_ports: Vec<u16>,
}

fn default_wire_api() -> String {
    "chat".to_string()
}

impl CatalogProvider {
    /// Whether this entry describes something running on this machine.
    pub fn is_local(&self) -> bool {
        !self.scan_ports.is_empty()
    }
}

/// Every catalog entry, sorted so local runtimes come first — they are the ones
/// a user can start using without signing up for anything.
pub fn all() -> Vec<CatalogProvider> {
    let mut providers: Vec<CatalogProvider> = CATALOG_DIR
        .files()
        .filter_map(|file| {
            let contents = file.contents_utf8()?;
            match toml::from_str::<CatalogProvider>(contents) {
                Ok(provider) => Some(provider),
                Err(err) => {
                    tracing::error!(
                        "ignoring malformed provider catalog entry {}: {err}",
                        file.path().display()
                    );
                    None
                }
            }
        })
        .collect();
    providers.sort_by(|a, b| {
        b.is_local()
            .cmp(&a.is_local())
            .then_with(|| a.id.cmp(&b.id))
    });
    providers
}

/// Look up one entry by its catalog id.
pub fn find(id: &str) -> Option<CatalogProvider> {
    all().into_iter().find(|provider| provider.id == id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_parse_every_bundled_entry() {
        // `all()` skips malformed files, so compare against the file count to
        // catch an entry that silently failed to parse.
        let file_count = CATALOG_DIR.files().count();
        assert_eq!(all().len(), file_count, "a catalog entry failed to parse");
        assert!(file_count > 0);
    }

    #[test]
    fn should_list_local_runtimes_before_hosted_providers() {
        let providers = all();
        let first_hosted = providers
            .iter()
            .position(|p| !p.is_local())
            .expect("catalog should contain hosted providers");
        assert!(
            providers[..first_hosted]
                .iter()
                .all(CatalogProvider::is_local),
            "local runtimes should be listed first"
        );
    }

    #[test]
    fn should_require_a_key_for_hosted_providers_only() {
        for provider in all() {
            if provider.is_local() {
                assert!(!provider.requires_key, "{} is local", provider.id);
            } else {
                assert!(provider.requires_key, "{} is hosted", provider.id);
                assert!(provider.env_key.is_some(), "{} needs env_key", provider.id);
            }
        }
    }

    #[test]
    fn should_find_a_known_provider_and_reject_an_unknown_one() {
        assert_eq!(find("ollama").map(|p| p.id), Some("ollama".to_string()));
        assert_eq!(find("not-a-provider"), None);
    }
}
