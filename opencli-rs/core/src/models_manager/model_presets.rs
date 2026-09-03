use crate::auth::AuthMode;
use once_cell::sync::Lazy;
use opencli_protocol::openai_models::ModelPreset;

/// Models compiled into the binary.
///
/// Intentionally empty: this build ships provider-neutral and carries no
/// opinion about which inference service you use. Declare the models you want
/// with `[[models]]` in `config.toml`, alongside the `[model_providers.<id>]`
/// entry that serves them; both appear in the `/model` picker. See
/// `docs/config.md`.
static PRESETS: Lazy<Vec<ModelPreset>> = Lazy::new(Vec::new);

/// Provider that serves `model`, when `model` names a built-in preset.
/// Returns `None` for unknown models so callers fall back to their own default.
pub fn provider_id_for_model(model: &str) -> Option<String> {
    PRESETS
        .iter()
        .find(|preset| preset.model == model || preset.id == model)
        .and_then(|preset| preset.provider.clone())
}

/// Presets compiled into the binary.
///
/// Empty in this build, so the `/model` picker is populated entirely from the
/// user's `[[models]]` entries. Kept as a function rather than inlined so a
/// downstream build can ship its own defaults without touching call sites.
pub(super) fn builtin_model_presets(_auth_mode: Option<AuthMode>) -> Vec<ModelPreset> {
    PRESETS.clone()
}

#[cfg(any(test, feature = "test-support"))]
pub fn all_model_presets() -> &'static Vec<ModelPreset> {
    &PRESETS
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_ship_no_built_in_models() {
        // This build is provider-neutral: the picker is populated from the
        // user's `[[models]]` entries, so shipping presets here would bake in
        // an opinion about which inference service to use.
        assert!(builtin_model_presets(None).is_empty());
    }

    #[test]
    fn should_not_resolve_a_provider_for_any_model() {
        // With no presets, provider resolution always defers to config, which
        // is what lets `[[models]]` be the single source of truth.
        assert_eq!(provider_id_for_model("gpt-5.1"), None);
        assert_eq!(provider_id_for_model("anything"), None);
    }
}
