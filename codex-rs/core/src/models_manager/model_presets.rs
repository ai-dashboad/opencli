use crate::auth::AuthMode;
use crate::model_provider_info::ANTHROPIC_PROVIDER_ID;
use crate::model_provider_info::CHEAPESTINFERENCE_PROVIDER_ID;
use crate::model_provider_info::DEEPSEEK_PROVIDER_ID;
use crate::model_provider_info::GOOGLE_PROVIDER_ID;
use crate::model_provider_info::GROQ_PROVIDER_ID;
use crate::model_provider_info::MISTRAL_PROVIDER_ID;
use crate::model_provider_info::MOONSHOT_PROVIDER_ID;
use crate::model_provider_info::OPENROUTER_PROVIDER_ID;
use crate::model_provider_info::XAI_PROVIDER_ID;
use crate::model_provider_info::ZHIPU_PROVIDER_ID;
use crate::model_provider_info::built_in_model_providers;
use codex_protocol::openai_models::ModelPreset;
use codex_protocol::openai_models::ModelUpgrade;
use codex_protocol::openai_models::ReasoningEffort;
use codex_protocol::openai_models::ReasoningEffortPreset;
use indoc::indoc;
use once_cell::sync::Lazy;

pub const HIDE_GPT5_1_MIGRATION_PROMPT_CONFIG: &str = "hide_gpt5_1_migration_prompt";
pub const HIDE_GPT_5_1_CODEX_MAX_MIGRATION_PROMPT_CONFIG: &str =
    "hide_gpt-5.1-codex-max_migration_prompt";

/// Build a preset for a chat-completions model served by `provider`. These
/// models expose a single reasoning effort because third-party gateways do not
/// implement the OpenAI reasoning-effort knob.
fn preset(id: &str, display_name: &str, provider: &str, description: &str) -> ModelPreset {
    ModelPreset {
        id: id.to_string(),
        model: id.to_string(),
        provider: Some(provider.to_string()),
        display_name: display_name.to_string(),
        description: description.to_string(),
        default_reasoning_effort: ReasoningEffort::Medium,
        supported_reasoning_efforts: vec![ReasoningEffortPreset {
            effort: ReasoningEffort::Medium,
            description: "Standard".to_string(),
        }],
        supports_personality: false,
        is_default: false,
        upgrade: None,
        show_in_picker: true,
        supported_in_api: true,
    }
}

static PRESETS: Lazy<Vec<ModelPreset>> = Lazy::new(|| {
    let mut presets = vec![
        // CheapestInference — the default gateway. This list mirrors what the
        // gateway's GET /v1/models actually serves; models absent there are
        // deliberately not listed because selecting them fails at request time.
        preset(
            "glm-5.2",
            "GLM 5.2",
            CHEAPESTINFERENCE_PROVIDER_ID,
            "GLM 5.2 via CheapestInference (default).",
        ),
        preset(
            "minimax-m3",
            "MiniMax M3",
            CHEAPESTINFERENCE_PROVIDER_ID,
            "MiniMax M3 via CheapestInference.",
        ),
        preset(
            "deepseek-v4-flash",
            "DeepSeek V4 Flash",
            CHEAPESTINFERENCE_PROVIDER_ID,
            "DeepSeek V4 Flash via CheapestInference (Core pool).",
        ),
        preset(
            "mimo-v2.5",
            "MiMo v2.5",
            CHEAPESTINFERENCE_PROVIDER_ID,
            "MiMo v2.5 via CheapestInference (Core pool).",
        ),
        // OpenRouter — brokers most of the market behind one key.
        preset(
            "anthropic/claude-sonnet-4.5",
            "Claude Sonnet 4.5 (OpenRouter)",
            OPENROUTER_PROVIDER_ID,
            "Anthropic Claude Sonnet 4.5 brokered by OpenRouter.",
        ),
        preset(
            "openai/gpt-5.1",
            "GPT-5.1 (OpenRouter)",
            OPENROUTER_PROVIDER_ID,
            "OpenAI GPT-5.1 brokered by OpenRouter.",
        ),
        preset(
            "google/gemini-2.5-pro",
            "Gemini 2.5 Pro (OpenRouter)",
            OPENROUTER_PROVIDER_ID,
            "Google Gemini 2.5 Pro brokered by OpenRouter.",
        ),
        preset(
            "deepseek/deepseek-chat",
            "DeepSeek Chat (OpenRouter)",
            OPENROUTER_PROVIDER_ID,
            "DeepSeek Chat brokered by OpenRouter.",
        ),
        preset(
            "qwen/qwen3-coder",
            "Qwen3 Coder (OpenRouter)",
            OPENROUTER_PROVIDER_ID,
            "Qwen3 Coder brokered by OpenRouter.",
        ),
        // Anthropic direct, via its OpenAI-compatible surface.
        preset(
            "claude-sonnet-4-5",
            "Claude Sonnet 4.5",
            ANTHROPIC_PROVIDER_ID,
            "Anthropic Claude Sonnet 4.5, direct.",
        ),
        preset(
            "claude-opus-4-1",
            "Claude Opus 4.1",
            ANTHROPIC_PROVIDER_ID,
            "Anthropic Claude Opus 4.1, direct.",
        ),
        preset(
            "claude-haiku-4-5",
            "Claude Haiku 4.5",
            ANTHROPIC_PROVIDER_ID,
            "Anthropic Claude Haiku 4.5, direct.",
        ),
        // DeepSeek direct.
        preset(
            "deepseek-chat",
            "DeepSeek Chat",
            DEEPSEEK_PROVIDER_ID,
            "DeepSeek Chat, direct.",
        ),
        preset(
            "deepseek-reasoner",
            "DeepSeek Reasoner",
            DEEPSEEK_PROVIDER_ID,
            "DeepSeek Reasoner, direct.",
        ),
        // Moonshot / Kimi direct.
        preset(
            "kimi-k2-0905-preview",
            "Kimi K2",
            MOONSHOT_PROVIDER_ID,
            "Moonshot Kimi K2, direct.",
        ),
        // Zhipu / GLM direct.
        preset(
            "glm-4.6",
            "GLM 4.6",
            ZHIPU_PROVIDER_ID,
            "Zhipu GLM 4.6, direct.",
        ),
        // xAI direct.
        preset("grok-4", "Grok 4", XAI_PROVIDER_ID, "xAI Grok 4, direct."),
        preset(
            "grok-code-fast-1",
            "Grok Code Fast",
            XAI_PROVIDER_ID,
            "xAI Grok Code Fast, direct.",
        ),
        // Google Gemini direct, via its OpenAI-compatible surface.
        preset(
            "gemini-2.5-pro",
            "Gemini 2.5 Pro",
            GOOGLE_PROVIDER_ID,
            "Google Gemini 2.5 Pro, direct.",
        ),
        preset(
            "gemini-2.5-flash",
            "Gemini 2.5 Flash",
            GOOGLE_PROVIDER_ID,
            "Google Gemini 2.5 Flash, direct.",
        ),
        // Groq — fast open-weight inference.
        preset(
            "llama-3.3-70b-versatile",
            "Llama 3.3 70B",
            GROQ_PROVIDER_ID,
            "Meta Llama 3.3 70B on Groq.",
        ),
        // Mistral direct.
        preset(
            "codestral-latest",
            "Codestral",
            MISTRAL_PROVIDER_ID,
            "Mistral Codestral, direct.",
        ),
    ];

    // Exactly one preset must be the default; GLM 5.2 on the default gateway.
    if let Some(default_preset) = presets.iter_mut().find(|p| p.id == "glm-5.2") {
        default_preset.is_default = true;
    }

    presets
});

/// Provider that serves `model`, when `model` names a built-in preset.
/// Returns `None` for unknown models so callers fall back to their own default.
pub fn provider_id_for_model(model: &str) -> Option<String> {
    PRESETS
        .iter()
        .find(|preset| preset.model == model || preset.id == model)
        .and_then(|preset| preset.provider.clone())
}

/// A preset is usable only when its provider's API key is present in the
/// environment. Presets whose provider needs no key (local servers) always
/// qualify. Hiding the rest keeps the picker free of options that would fail
/// on first request.
fn provider_key_is_available(provider_id: &str) -> bool {
    let Some(provider) = built_in_model_providers().get(provider_id).cloned() else {
        return false;
    };
    match provider.env_key {
        Some(env_key) => std::env::var(env_key)
            .ok()
            .is_some_and(|value| !value.trim().is_empty()),
        None => true,
    }
}

#[allow(dead_code)]
fn gpt_52_codex_upgrade() -> ModelUpgrade {
    ModelUpgrade {
        id: "gpt-5.2-codex".to_string(),
        reasoning_effort_mapping: None,
        migration_config_key: "gpt-5.2-codex".to_string(),
        model_link: Some("https://openai.com/index/introducing-gpt-5-2-codex".to_string()),
        upgrade_copy: Some(
            "Codex is now powered by gpt-5.2-codex, our latest frontier agentic coding model. It is smarter and faster than its predecessors and capable of long-running project-scale work."
                .to_string(),
        ),
        migration_markdown: Some(
            indoc! {r#"
                **Codex just got an upgrade. Introducing {model_to}.**

                Codex is now powered by gpt-5.2-codex, our latest frontier agentic coding model. It is smarter and faster than its predecessors and capable of long-running project-scale work. Learn more about {model_to} at https://openai.com/index/introducing-gpt-5-2-codex

                You can continue using {model_from} if you prefer.
            "#}
            .to_string(),
        ),
    }
}

pub(super) fn builtin_model_presets(_auth_mode: Option<AuthMode>) -> Vec<ModelPreset> {
    let available: Vec<ModelPreset> = PRESETS
        .iter()
        .filter(|preset| {
            preset
                .provider
                .as_deref()
                .is_none_or(provider_key_is_available)
        })
        .cloned()
        .collect();

    // Never hand back an empty picker: if the user has configured no keys at
    // all, fall back to the full list so the UI can still explain what is
    // missing rather than showing nothing.
    if available.is_empty() {
        PRESETS.iter().cloned().collect()
    } else {
        available
    }
}

#[cfg(any(test, feature = "test-support"))]
pub fn all_model_presets() -> &'static Vec<ModelPreset> {
    &PRESETS
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_configure_exactly_one_default_model() {
        let default_models = PRESETS.iter().filter(|preset| preset.is_default).count();
        assert_eq!(default_models, 1);
    }

    #[test]
    fn should_bind_every_preset_to_a_known_built_in_provider() {
        let providers = built_in_model_providers();
        for preset in PRESETS.iter() {
            let provider_id = preset
                .provider
                .as_deref()
                .unwrap_or_else(|| panic!("preset {} has no provider", preset.id));
            assert!(
                providers.contains_key(provider_id),
                "preset {} references unknown provider {provider_id}",
                preset.id
            );
        }
    }

    #[test]
    fn should_only_list_presets_whose_provider_key_is_available() {
        let listed = builtin_model_presets(None);
        // The fallback path returns everything, and only kicks in when no
        // provider at all is usable; distinguish the two cases.
        let any_available = PRESETS.iter().any(|preset| {
            preset
                .provider
                .as_deref()
                .is_none_or(provider_key_is_available)
        });
        if any_available {
            for preset in &listed {
                let provider_id = preset.provider.as_deref().unwrap_or("openai");
                assert!(
                    provider_key_is_available(provider_id),
                    "listed preset {} routes to {provider_id}, whose key is not set",
                    preset.id
                );
            }
        } else {
            assert_eq!(listed.len(), PRESETS.len());
        }
    }

    #[test]
    fn should_treat_keyless_providers_as_available() {
        // The OpenAI provider carries no env_key of its own, so it must never
        // be filtered out for lack of one.
        assert!(provider_key_is_available("openai"));
    }

    #[test]
    fn should_resolve_provider_for_a_known_model() {
        assert_eq!(
            provider_id_for_model("glm-5.2").as_deref(),
            Some(CHEAPESTINFERENCE_PROVIDER_ID)
        );
        assert_eq!(
            provider_id_for_model("claude-sonnet-4-5").as_deref(),
            Some(ANTHROPIC_PROVIDER_ID)
        );
        assert_eq!(provider_id_for_model("not-a-real-model"), None);
    }
}
