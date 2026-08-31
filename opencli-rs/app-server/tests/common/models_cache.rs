use chrono::DateTime;
use chrono::Utc;
use opencli_protocol::openai_models::ConfigShellToolType;
use opencli_protocol::openai_models::ModelInfo;
use opencli_protocol::openai_models::ModelInstructionsVariables;
use opencli_protocol::openai_models::ModelMessages;
use opencli_protocol::openai_models::ModelPreset;
use opencli_protocol::openai_models::ModelVisibility;
use opencli_protocol::openai_models::TruncationPolicyConfig;
use serde_json::json;
use std::path::Path;

/// Convert a ModelPreset to ModelInfo for cache storage.
fn preset_to_info(preset: &ModelPreset, priority: i32) -> ModelInfo {
    ModelInfo {
        slug: preset.id.clone(),
        display_name: preset.display_name.clone(),
        description: Some(preset.description.clone()),
        default_reasoning_level: Some(preset.default_reasoning_effort),
        supported_reasoning_levels: preset.supported_reasoning_efforts.clone(),
        shell_type: ConfigShellToolType::ShellCommand,
        visibility: if preset.show_in_picker {
            ModelVisibility::List
        } else {
            ModelVisibility::Hide
        },
        supported_in_api: true,
        priority,
        upgrade: preset.upgrade.as_ref().map(|u| u.into()),
        base_instructions: "base instructions".to_string(),
        model_messages: None,
        supports_reasoning_summaries: false,
        support_verbosity: false,
        default_verbosity: None,
        apply_patch_tool_type: None,
        truncation_policy: TruncationPolicyConfig::bytes(10_000),
        supports_parallel_tool_calls: false,
        context_window: Some(272_000),
        auto_compact_token_limit: None,
        effective_context_window_percent: 95,
        experimental_supported_tools: Vec::new(),
    }
}

/// The models these tests run against.
///
/// Declared here rather than taken from `all_model_presets()`: this build ships
/// no built-in models on purpose — the picker is populated from the user's
/// `[[models]]` — so a helper that read the presets would seed nothing and
/// every assertion below it would be vacuous.
fn test_presets() -> Vec<ModelPreset> {
    use opencli_protocol::openai_models::ReasoningEffort;
    use opencli_protocol::openai_models::ReasoningEffortPreset;

    let effort = |effort, description: &str| ReasoningEffortPreset {
        effort,
        description: description.to_string(),
    };
    let efforts = || {
        vec![
            effort(ReasoningEffort::Low, "Fast responses with lighter reasoning"),
            effort(
                ReasoningEffort::Medium,
                "Balances speed and reasoning depth for everyday tasks",
            ),
            effort(ReasoningEffort::High, "Greater reasoning depth for complex problems"),
            effort(
                ReasoningEffort::XHigh,
                "Extra high reasoning depth for complex problems",
            ),
        ]
    };

    let preset = |id: &str, description: &str, efforts, is_default| ModelPreset {
        id: id.to_string(),
        model: id.to_string(),
        provider: None,
        supported_in_api: true,
        display_name: id.to_string(),
        description: description.to_string(),
        default_reasoning_effort: ReasoningEffort::Medium,
        supported_reasoning_efforts: efforts,
        show_in_picker: true,
        upgrade: None,
        is_default,
        supports_personality: false,
    };

    vec![
        preset(
            "test-model-pro",
            "Latest frontier agentic coding model.",
            efforts(),
            true,
        ),
        preset(
            "test-model-max",
            "OpenCLI-optimized flagship for deep and fast reasoning.",
            efforts(),
            false,
        ),
        preset(
            "test-model-mini",
            "Optimized for opencli. Cheaper, faster, but less capable.",
            vec![
                effort(
                    ReasoningEffort::Medium,
                    "Dynamically adjusts reasoning based on the task",
                ),
                effort(
                    ReasoningEffort::High,
                    "Maximizes reasoning depth for complex or ambiguous problems",
                ),
            ],
            false,
        ),
        preset(
            "gpt-5.2",
            "Latest frontier model with improvements across knowledge, reasoning and coding",
            vec![
                effort(
                    ReasoningEffort::Low,
                    "Balances speed with some reasoning; useful for straightforward queries and \
                     short explanations",
                ),
                effort(
                    ReasoningEffort::Medium,
                    "Provides a solid balance of reasoning depth and latency for general-purpose \
                     tasks",
                ),
                effort(
                    ReasoningEffort::High,
                    "Maximizes reasoning depth for complex or ambiguous problems",
                ),
                effort(
                    ReasoningEffort::XHigh,
                    "Extra high reasoning depth for complex problems",
                ),
            ],
            false,
        ),
    ]
}

/// Write a models_cache.json file to the opencli home directory.
/// This prevents ModelsManager from making network requests to refresh models.
/// The cache will be treated as fresh (within TTL) and used instead of fetching from the network.
pub fn write_models_cache(opencli_home: &Path) -> std::io::Result<()> {
    // Lower priority sorts earlier, so the first model gets priority 0.
    let models: Vec<ModelInfo> = test_presets()
        .iter()
        .enumerate()
        .map(|(index, preset)| preset_to_info(preset, index as i32))
        .collect();

    write_models_cache_with_models(opencli_home, models)
}

/// Write a models_cache.json file with specific models.
/// Useful when tests need specific models to be available.
pub fn write_models_cache_with_models(
    opencli_home: &Path,
    models: Vec<ModelInfo>,
) -> std::io::Result<()> {
    let cache_path = opencli_home.join("models_cache.json");
    // DateTime<Utc> serializes to RFC3339 format by default with serde
    let fetched_at: DateTime<Utc> = Utc::now();
    let cache = json!({
        "fetched_at": fetched_at,
        "etag": null,
        "models": models
    });
    std::fs::write(cache_path, serde_json::to_string_pretty(&cache)?)
}

/// Write a cache whose model can carry a personality.
///
/// Kept separate from [`write_models_cache`]: `supports_personality` is derived
/// from the instructions template, so adding one to the shared models would
/// change what every model-listing assertion expects.
pub fn write_personality_models_cache(opencli_home: &Path) -> std::io::Result<()> {
    const BASE: &str = "You are OpenCLI, a coding agent based on GPT-5. You and the user share \
                        the same workspace and collaborate to achieve the user's goals.";
    const FRIENDLY: &str = "Be warm and explain your reasoning.";

    let mut info = preset_to_info(&test_presets()[0], 0);
    // The opening sentence is what `thread_resume` asserts on to prove the
    // base instructions survived a resume, so the template has to carry it
    // rather than being an arbitrary placeholder string.
    info.model_messages = Some(ModelMessages {
        instructions_template: Some(format!("{BASE}\n{{{{ personality }}}}")),
        instructions_variables: Some(ModelInstructionsVariables {
            personality_default: Some("Answer plainly.".to_string()),
            personality_friendly: Some(FRIENDLY.to_string()),
            personality_pragmatic: Some("Be terse. Answers, not commentary.".to_string()),
        }),
    });
    // The session's starting personality is already rendered into the base
    // instructions. Leaving these out of step makes the agent announce the
    // personality it started with, which reads as a change that never
    // happened.
    info.base_instructions = format!("{BASE}\n{FRIENDLY}");
    write_models_cache_with_models(opencli_home, vec![info])
}
