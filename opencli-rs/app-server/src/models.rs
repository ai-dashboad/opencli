use std::sync::Arc;

use opencli_app_server_protocol::Model;
use opencli_app_server_protocol::ReasoningEffortOption;
use opencli_core::ThreadManager;
use opencli_core::config::Config;
use opencli_core::models_manager::manager::RefreshStrategy;
use opencli_protocol::openai_models::ModelPreset;
use opencli_protocol::openai_models::ReasoningEffortPreset;

pub async fn supported_models(thread_manager: Arc<ThreadManager>, config: &Config) -> Vec<Model> {
    thread_manager
        .list_models(config, RefreshStrategy::OnlineIfUncached)
        .await
        .into_iter()
        .filter(|preset| preset.show_in_picker)
        .map(model_from_preset)
        .collect()
}

fn model_from_preset(preset: ModelPreset) -> Model {
    Model {
        id: preset.id.to_string(),
        model: preset.model.to_string(),
        display_name: preset.display_name.to_string(),
        description: preset.description.to_string(),
        supported_reasoning_efforts: reasoning_efforts_from_preset(
            preset.supported_reasoning_efforts,
        ),
        default_reasoning_effort: preset.default_reasoning_effort,
        supports_personality: preset.supports_personality,
        is_default: preset.is_default,
    }
}

fn reasoning_efforts_from_preset(
    efforts: Vec<ReasoningEffortPreset>,
) -> Vec<ReasoningEffortOption> {
    efforts
        .iter()
        .map(|preset| ReasoningEffortOption {
            reasoning_effort: preset.effort,
            description: preset.description.to_string(),
        })
        .collect()
}
