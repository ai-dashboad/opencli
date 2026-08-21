use crate::auth::AuthMode;
use codex_protocol::openai_models::ModelPreset;
use codex_protocol::openai_models::ModelUpgrade;
use codex_protocol::openai_models::ReasoningEffort;
use codex_protocol::openai_models::ReasoningEffortPreset;
use indoc::indoc;
use once_cell::sync::Lazy;

pub const HIDE_GPT5_1_MIGRATION_PROMPT_CONFIG: &str = "hide_gpt5_1_migration_prompt";
pub const HIDE_GPT_5_1_CODEX_MAX_MIGRATION_PROMPT_CONFIG: &str =
    "hide_gpt-5.1-codex-max_migration_prompt";

static PRESETS: Lazy<Vec<ModelPreset>> = Lazy::new(|| {
    vec![
        ModelPreset {
            id: "glm-5.2".to_string(),
            model: "glm-5.2".to_string(),
            display_name: "GLM 5.2".to_string(),
            description: "GLM 5.2 via CheapestInference (default).".to_string(),
            default_reasoning_effort: ReasoningEffort::Medium,
            supported_reasoning_efforts: vec![
                ReasoningEffortPreset {
                    effort: ReasoningEffort::Medium,
                    description: "Standard".to_string(),
                },
            ],
            supports_personality: false,
            is_default: true,
            upgrade: None,
            show_in_picker: true,
            supported_in_api: true,
        },
        ModelPreset {
            id: "minimax-m3".to_string(),
            model: "minimax-m3".to_string(),
            display_name: "MiniMax M3".to_string(),
            description: "MiniMax M3 via CheapestInference.".to_string(),
            default_reasoning_effort: ReasoningEffort::Medium,
            supported_reasoning_efforts: vec![
                ReasoningEffortPreset {
                    effort: ReasoningEffort::Medium,
                    description: "Standard".to_string(),
                },
            ],
            supports_personality: false,
            is_default: false,
            upgrade: None,
            show_in_picker: true,
            supported_in_api: true,
        },
        ModelPreset {
            id: "deepseek-v4-flash".to_string(),
            model: "deepseek-v4-flash".to_string(),
            display_name: "DeepSeek V4 Flash".to_string(),
            description: "DeepSeek V4 Flash via CheapestInference (Core pool).".to_string(),
            default_reasoning_effort: ReasoningEffort::Medium,
            supported_reasoning_efforts: vec![
                ReasoningEffortPreset {
                    effort: ReasoningEffort::Medium,
                    description: "Standard".to_string(),
                },
            ],
            supports_personality: false,
            is_default: false,
            upgrade: None,
            show_in_picker: true,
            supported_in_api: true,
        },
        ModelPreset {
            id: "mimo-v2.5".to_string(),
            model: "mimo-v2.5".to_string(),
            display_name: "MiMo v2.5".to_string(),
            description: "MiMo v2.5 via CheapestInference (Core pool).".to_string(),
            default_reasoning_effort: ReasoningEffort::Medium,
            supported_reasoning_efforts: vec![
                ReasoningEffortPreset {
                    effort: ReasoningEffort::Medium,
                    description: "Standard".to_string(),
                },
            ],
            supports_personality: false,
            is_default: false,
            upgrade: None,
            show_in_picker: true,
            supported_in_api: true,
        },
    ]
});

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
    PRESETS.iter().cloned().collect()
}

#[cfg(any(test, feature = "test-support"))]
pub fn all_model_presets() -> &'static Vec<ModelPreset> {
    &PRESETS
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_one_default_model_is_configured() {
        let default_models = PRESETS.iter().filter(|preset| preset.is_default).count();
        assert!(default_models == 1);
    }
}
