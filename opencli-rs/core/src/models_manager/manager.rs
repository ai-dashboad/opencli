use super::cache::ModelsCacheManager;
use crate::api_bridge::auth_provider_from_auth;
use crate::api_bridge::map_api_error;
use crate::auth::AuthManager;
use crate::auth::AuthMode;
use crate::config::Config;
use crate::config::types::CustomModel;
use crate::default_client::build_reqwest_client;
use crate::error::OpenCLIErr;
use crate::error::Result as CoreResult;
use crate::features::Feature;
use crate::model_provider_info::ModelProviderInfo;
use crate::models_manager::collaboration_mode_presets::builtin_collaboration_mode_presets;
use crate::models_manager::model_info;
use crate::models_manager::model_presets::builtin_model_presets;
use http::HeaderMap;
use opencli_api::ModelsClient;
use opencli_api::ReqwestTransport;
use opencli_protocol::config_types::CollaborationModeMask;
use opencli_protocol::openai_models::ModelInfo;
use opencli_protocol::openai_models::ModelPreset;
use opencli_protocol::openai_models::ModelsResponse;
use opencli_protocol::openai_models::ReasoningEffort;
use opencli_protocol::openai_models::ReasoningEffortPreset;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;
use tokio::sync::TryLockError;
use tokio::time::timeout;
use tracing::error;

const MODEL_CACHE_FILE: &str = "models_cache.json";
const DEFAULT_MODEL_CACHE_TTL: Duration = Duration::from_secs(300);
const MODELS_REFRESH_TIMEOUT: Duration = Duration::from_secs(5);

/// Strategy for refreshing available models.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RefreshStrategy {
    /// Always fetch from the network, ignoring cache.
    Online,
    /// Only use cached data, never fetch from the network.
    Offline,
    /// Use cache if available and fresh, otherwise fetch from the network.
    OnlineIfUncached,
}

/// Coordinates remote model discovery plus cached metadata on disk.
#[derive(Debug)]
pub struct ModelsManager {
    local_models: Vec<ModelPreset>,
    remote_models: RwLock<Vec<ModelInfo>>,
    auth_manager: Arc<AuthManager>,
    etag: RwLock<Option<String>>,
    cache_manager: ModelsCacheManager,
    provider: ModelProviderInfo,
}

impl ModelsManager {
    /// Construct a manager scoped to the provided `AuthManager`.
    ///
    /// Uses `opencli_home` to store cached model metadata and initializes with built-in presets.
    pub fn new(opencli_home: PathBuf, auth_manager: Arc<AuthManager>) -> Self {
        let cache_path = opencli_home.join(MODEL_CACHE_FILE);
        let cache_manager = ModelsCacheManager::new(cache_path, DEFAULT_MODEL_CACHE_TTL);
        Self {
            local_models: builtin_model_presets(auth_manager.get_internal_auth_mode()),
            remote_models: RwLock::new(Self::load_remote_models_from_file().unwrap_or_default()),
            auth_manager,
            etag: RwLock::new(None),
            cache_manager,
            provider: ModelProviderInfo::create_openai_provider(),
        }
    }

    /// List all available models, refreshing according to the specified strategy.
    ///
    /// Returns model presets sorted by priority and filtered by auth mode and visibility.
    pub async fn list_models(
        &self,
        config: &Config,
        refresh_strategy: RefreshStrategy,
    ) -> Vec<ModelPreset> {
        if let Err(err) = self
            .refresh_available_models(config, refresh_strategy)
            .await
        {
            error!("failed to refresh available models: {err}");
        }
        let remote_models = self.get_remote_models(config).await;
        self.build_available_models(remote_models, config)
    }

    /// List collaboration mode presets.
    ///
    /// Returns a static set of presets seeded with the configured model.
    pub fn list_collaboration_modes(&self) -> Vec<CollaborationModeMask> {
        builtin_collaboration_mode_presets()
    }

    /// Attempt to list models without blocking, using the current cached state.
    ///
    /// Returns an error if the internal lock cannot be acquired.
    pub fn try_list_models(&self, config: &Config) -> Result<Vec<ModelPreset>, TryLockError> {
        let remote_models = self.try_get_remote_models(config)?;
        Ok(self.build_available_models(remote_models, config))
    }

    // todo(aibrahim): should be visible to core only and sent on session_configured event
    /// Get the model identifier to use, refreshing according to the specified strategy.
    ///
    /// If `model` is provided, returns it directly. Otherwise selects the default based on
    /// auth mode and available models.
    pub async fn get_default_model(
        &self,
        model: &Option<String>,
        config: &Config,
        refresh_strategy: RefreshStrategy,
    ) -> String {
        if let Some(model) = model.as_ref() {
            return model.to_string();
        }
        if let Err(err) = self
            .refresh_available_models(config, refresh_strategy)
            .await
        {
            error!("failed to refresh available models: {err}");
        }
        let remote_models = self.get_remote_models(config).await;
        let available = self.build_available_models(remote_models, config);
        available
            .iter()
            .find(|model| model.is_default)
            .or_else(|| available.first())
            .map(|model| model.model.clone())
            .unwrap_or_default()
    }

    // todo(aibrahim): look if we can tighten it to pub(crate)
    /// Look up model metadata, applying remote overrides and config adjustments.
    pub async fn get_model_info(&self, model: &str, config: &Config) -> ModelInfo {
        let remote = self
            .get_remote_models(config)
            .await
            .into_iter()
            .find(|m| m.slug == model);
        let mut model = if let Some(remote) = remote {
            remote
        } else {
            model_info::find_model_info_for_slug(model)
        };
        // The whole precedence lives in `with_config_overrides`, so that a
        // model looked up without the registry gets the same answer: an
        // explicit `model_context_window`, then a `[[models]]` declaration,
        // then a learned window, then the built-in guess.
        model_info::with_config_overrides(model, config)
    }

    /// Refresh models if the provided ETag differs from the cached ETag.
    ///
    /// Uses `Online` strategy to fetch latest models when ETags differ.
    pub(crate) async fn refresh_if_new_etag(&self, etag: String, config: &Config) {
        let current_etag = self.get_etag().await;
        if current_etag.clone().is_some() && current_etag.as_deref() == Some(etag.as_str()) {
            if let Err(err) = self.cache_manager.renew_cache_ttl().await {
                error!("failed to renew cache TTL: {err}");
            }
            return;
        }
        if let Err(err) = self
            .refresh_available_models(config, RefreshStrategy::Online)
            .await
        {
            error!("failed to refresh available models: {err}");
        }
    }

    /// Refresh available models according to the specified strategy.
    async fn refresh_available_models(
        &self,
        config: &Config,
        refresh_strategy: RefreshStrategy,
    ) -> CoreResult<()> {
        if !config.features.enabled(Feature::RemoteModels) {
            return Ok(());
        }

        // The remote catalog is an OpenAI-specific endpoint: third-party
        // gateways do not serve it, and querying it with their credentials only
        // produces a spurious 401 on every startup.
        //
        // That restriction is about the *network call*. The cache is a local
        // file and costs nothing to read, so gating it too would deny everyone
        // on another provider the model metadata they already have on disk.
        let may_fetch = self.auth_manager.get_internal_auth_mode() != Some(AuthMode::ApiKey)
            && config.model_provider.is_openai();

        match refresh_strategy {
            RefreshStrategy::Offline => {
                self.try_load_cache().await;
                Ok(())
            }
            RefreshStrategy::OnlineIfUncached => {
                if self.try_load_cache().await || !may_fetch {
                    return Ok(());
                }
                self.fetch_and_update_models().await
            }
            RefreshStrategy::Online => {
                if !may_fetch {
                    // Fall back to whatever is cached rather than doing nothing.
                    self.try_load_cache().await;
                    return Ok(());
                }
                self.fetch_and_update_models().await
            }
        }
    }

    async fn fetch_and_update_models(&self) -> CoreResult<()> {
        let _timer =
            opencli_otel::start_global_timer("opencli.remote_models.fetch_update.duration_ms", &[]);
        let auth = self.auth_manager.auth().await;
        let auth_mode = self.auth_manager.get_internal_auth_mode();
        let api_provider = self.provider.to_api_provider(auth_mode)?;
        let api_auth = auth_provider_from_auth(auth.clone(), &self.provider)?;
        let transport = ReqwestTransport::new(build_reqwest_client());
        let client = ModelsClient::new(transport, api_provider, api_auth);

        let client_version = format_client_version_to_whole();
        let (models, etag) = timeout(
            MODELS_REFRESH_TIMEOUT,
            client.list_models(&client_version, HeaderMap::new()),
        )
        .await
        .map_err(|_| OpenCLIErr::Timeout)?
        .map_err(map_api_error)?;

        self.apply_remote_models(models.clone()).await;
        *self.etag.write().await = etag.clone();
        self.cache_manager.persist_cache(&models, etag).await;
        Ok(())
    }

    async fn get_etag(&self) -> Option<String> {
        self.etag.read().await.clone()
    }

    /// Replace the cached remote models and rebuild the derived presets list.
    async fn apply_remote_models(&self, models: Vec<ModelInfo>) {
        let mut existing_models = Self::load_remote_models_from_file().unwrap_or_default();
        for model in models {
            if let Some(existing_index) = existing_models
                .iter()
                .position(|existing| existing.slug == model.slug)
            {
                existing_models[existing_index] = model;
            } else {
                existing_models.push(model);
            }
        }
        *self.remote_models.write().await = existing_models;
    }

    fn load_remote_models_from_file() -> Result<Vec<ModelInfo>, std::io::Error> {
        let file_contents = include_str!("../../models.json");
        let response: ModelsResponse = serde_json::from_str(file_contents)?;
        Ok(response.models)
    }

    /// Attempt to satisfy the refresh from the cache when it matches the provider and TTL.
    async fn try_load_cache(&self) -> bool {
        let _timer =
            opencli_otel::start_global_timer("opencli.remote_models.load_cache.duration_ms", &[]);
        let cache = match self.cache_manager.load_fresh().await {
            Some(cache) => cache,
            None => return false,
        };
        let models = cache.models.clone();
        *self.etag.write().await = cache.etag.clone();
        self.apply_remote_models(models.clone()).await;
        true
    }

    /// Merge remote model metadata into picker-ready presets, preserving existing entries.
    fn build_available_models(
        &self,
        mut remote_models: Vec<ModelInfo>,
        config: &Config,
    ) -> Vec<ModelPreset> {
        remote_models.sort_by_key(|model| model.priority);

        let remote_presets: Vec<ModelPreset> = remote_models.into_iter().map(Into::into).collect();
        // Fold in `[[models]]` from config.toml so adding a model does not
        // require a rebuild. A user entry shadows the built-in preset with the
        // same slug, making config.toml the last word on how a slug is routed.
        let existing_presets = merge_custom_models(&config.models, self.local_models.clone());
        let mut merged_presets = ModelPreset::merge(remote_presets, existing_presets);
        let chatgpt_mode = matches!(
            self.auth_manager.get_internal_auth_mode(),
            Some(AuthMode::Chatgpt)
        );
        merged_presets = ModelPreset::filter_by_auth(merged_presets, chatgpt_mode);

        for preset in &mut merged_presets {
            preset.is_default = false;
        }
        if let Some(default) = merged_presets
            .iter_mut()
            .find(|preset| preset.show_in_picker)
        {
            default.is_default = true;
        } else if let Some(default) = merged_presets.first_mut() {
            default.is_default = true;
        }

        // Surface user-declared models first. The picker shows only 8 rows at a
        // time, and appending these left them below the fold behind catalog
        // entries the user may not even have a key for — indistinguishable from
        // the model not being configured at all. Done after `is_default` is
        // assigned so display order does not change which model is the default.
        promote_custom_models(&config.models, &mut merged_presets);

        merged_presets
    }

    async fn get_remote_models(&self, config: &Config) -> Vec<ModelInfo> {
        if config.features.enabled(Feature::RemoteModels) {
            self.remote_models.read().await.clone()
        } else {
            Vec::new()
        }
    }

    fn try_get_remote_models(&self, config: &Config) -> Result<Vec<ModelInfo>, TryLockError> {
        if config.features.enabled(Feature::RemoteModels) {
            Ok(self.remote_models.try_read()?.clone())
        } else {
            Ok(Vec::new())
        }
    }

    #[cfg(any(test, feature = "test-support"))]
    /// Construct a manager with a specific provider for testing.
    pub fn with_provider(
        opencli_home: PathBuf,
        auth_manager: Arc<AuthManager>,
        provider: ModelProviderInfo,
    ) -> Self {
        let cache_path = opencli_home.join(MODEL_CACHE_FILE);
        let cache_manager = ModelsCacheManager::new(cache_path, DEFAULT_MODEL_CACHE_TTL);
        Self {
            local_models: builtin_model_presets(auth_manager.get_internal_auth_mode()),
            remote_models: RwLock::new(Self::load_remote_models_from_file().unwrap_or_default()),
            auth_manager,
            etag: RwLock::new(None),
            cache_manager,
            provider,
        }
    }

    #[cfg(any(test, feature = "test-support"))]
    /// Get model identifier without consulting remote state or cache.
    pub fn get_model_offline(model: Option<&str>) -> String {
        if let Some(model) = model {
            return model.to_string();
        }
        let presets = builtin_model_presets(None);
        presets
            .iter()
            .find(|preset| preset.show_in_picker)
            .or_else(|| presets.first())
            .map(|preset| preset.model.clone())
            .unwrap_or_default()
    }

    #[cfg(any(test, feature = "test-support"))]
    /// Build `ModelInfo` without consulting remote state or cache.
    pub fn construct_model_info_offline(model: &str, config: &Config) -> ModelInfo {
        model_info::with_config_overrides(model_info::find_model_info_for_slug(model), config)
    }
}

/// Fold user-declared models into `presets`.
///
/// An entry replaces a built-in preset with the same slug in place, and is
/// otherwise appended. Replacing in place keeps the built-in ordering — and so
/// the default-model choice — stable when a user adds models.
///
/// Unlike built-in presets, user entries are never hidden for a missing API
/// key: the user asked for them explicitly, and a key error names the variable
/// to set, whereas a silently absent model looks like the config was ignored.
fn merge_custom_models(
    custom_models: &[CustomModel],
    mut presets: Vec<ModelPreset>,
) -> Vec<ModelPreset> {
    for custom in custom_models {
        let preset = ModelPreset {
            id: custom.model.clone(),
            model: custom.model.clone(),
            provider: Some(custom.provider.clone()),
            display_name: custom.display_name(),
            description: custom.description(),
            default_reasoning_effort: custom
                .reasoning_efforts
                .iter()
                .copied()
                .find(|effort| *effort == ReasoningEffort::Medium)
                .or_else(|| custom.reasoning_efforts.first().copied())
                .unwrap_or(ReasoningEffort::Medium),
            supported_reasoning_efforts: reasoning_effort_presets(&custom.reasoning_efforts),
            supports_personality: custom.supports_personality,
            is_default: false,
            upgrade: None,
            show_in_picker: custom.show_in_picker,
            supported_in_api: true,
        };
        match presets
            .iter()
            .position(|existing| existing.model == custom.model)
        {
            Some(index) => presets[index] = preset,
            None => presets.push(preset),
        }
    }
    presets
}

/// Build picker entries for the reasoning efforts a user declared.
///
/// Falls back to a single "medium" entry, which is what a provider with no
/// reasoning knob can honor — offering more would let the user pick a level the
/// gateway silently ignores.
fn reasoning_effort_presets(efforts: &[ReasoningEffort]) -> Vec<ReasoningEffortPreset> {
    if efforts.is_empty() {
        return vec![ReasoningEffortPreset {
            effort: ReasoningEffort::Medium,
            description: "Standard".to_string(),
        }];
    }
    efforts
        .iter()
        .map(|effort| ReasoningEffortPreset {
            effort: *effort,
            description: match effort {
                ReasoningEffort::Minimal => "Fastest, minimal reasoning".to_string(),
                ReasoningEffort::Low => "Faster, lighter reasoning".to_string(),
                ReasoningEffort::Medium => "Balanced".to_string(),
                ReasoningEffort::High => "Deeper reasoning".to_string(),
                ReasoningEffort::XHigh => "Deepest reasoning".to_string(),
                ReasoningEffort::None => "No reasoning".to_string(),
            },
        })
        .collect()
}

/// Move user-declared models to the front of `presets`, keeping the relative
/// order of both the promoted entries and everything else.
fn promote_custom_models(custom_models: &[CustomModel], presets: &mut Vec<ModelPreset>) {
    if custom_models.is_empty() {
        return;
    }
    let is_custom = |preset: &ModelPreset| {
        custom_models
            .iter()
            .any(|custom| custom.matches(&preset.model))
    };
    let (mut promoted, rest): (Vec<_>, Vec<_>) =
        std::mem::take(presets).into_iter().partition(is_custom);
    promoted.extend(rest);
    *presets = promoted;
}

/// Convert a client version string to a whole version string (e.g. "1.2.3-alpha.4" -> "1.2.3")
fn format_client_version_to_whole() -> String {
    format!(
        "{}.{}.{}",
        env!("CARGO_PKG_VERSION_MAJOR"),
        env!("CARGO_PKG_VERSION_MINOR"),
        env!("CARGO_PKG_VERSION_PATCH")
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::OpenCLIAuth;
    use crate::auth::AuthCredentialsStoreMode;
    use crate::config::ConfigBuilder;
    use crate::features::Feature;
    use crate::model_provider_info::WireApi;
    use chrono::Utc;
    use core_test_support::responses::mount_models_once;
    use opencli_protocol::openai_models::ModelsResponse;
    use pretty_assertions::assert_eq;
    use serde_json::json;
    use tempfile::tempdir;
    use wiremock::MockServer;

    fn remote_model(slug: &str, display: &str, priority: i32) -> ModelInfo {
        remote_model_with_visibility(slug, display, priority, "list")
    }

    fn remote_model_with_visibility(
        slug: &str,
        display: &str,
        priority: i32,
        visibility: &str,
    ) -> ModelInfo {
        serde_json::from_value(json!({
            "slug": slug,
            "display_name": display,
            "description": format!("{display} desc"),
            "default_reasoning_level": "medium",
            "supported_reasoning_levels": [{"effort": "low", "description": "low"}, {"effort": "medium", "description": "medium"}],
            "shell_type": "shell_command",
            "visibility": visibility,
            "minimal_client_version": [0, 1, 0],
            "supported_in_api": true,
            "priority": priority,
            "upgrade": null,
            "base_instructions": "base instructions",
            "supports_reasoning_summaries": false,
            "support_verbosity": false,
            "default_verbosity": null,
            "apply_patch_tool_type": null,
            "truncation_policy": {"mode": "bytes", "limit": 10_000},
            "supports_parallel_tool_calls": false,
            "context_window": 272_000,
            "experimental_supported_tools": [],
        }))
        .expect("valid model")
    }

    fn assert_models_contain(actual: &[ModelInfo], expected: &[ModelInfo]) {
        for model in expected {
            assert!(
                actual.iter().any(|candidate| candidate.slug == model.slug),
                "expected model {} in cached list",
                model.slug
            );
        }
    }

    fn provider_for(base_url: String) -> ModelProviderInfo {
        ModelProviderInfo {
            name: "mock".into(),
            base_url: Some(base_url),
            env_key: None,
            env_key_instructions: None,
            experimental_bearer_token: None,
            wire_api: WireApi::Responses,
            query_params: None,
            http_headers: None,
            env_http_headers: None,
            request_max_retries: Some(0),
            stream_max_retries: Some(0),
            stream_idle_timeout_ms: Some(5_000),
            requires_openai_auth: false,
            supports_websockets: false,
        }
    }

    #[tokio::test]
    async fn refresh_available_models_sorts_by_priority() {
        let server = MockServer::start().await;
        let remote_models = vec![
            remote_model("priority-low", "Low", 1),
            remote_model("priority-high", "High", 0),
        ];
        let models_mock = mount_models_once(
            &server,
            ModelsResponse {
                models: remote_models.clone(),
            },
        )
        .await;

        let opencli_home = tempdir().expect("temp dir");
        let mut config = ConfigBuilder::default()
            .opencli_home(opencli_home.path().to_path_buf())
            .build()
            .await
            .expect("load default test config");
        config.features.enable(Feature::RemoteModels);
        let auth_manager = AuthManager::from_auth_for_testing(
            OpenCLIAuth::create_dummy_chatgpt_auth_for_testing(),
        );
        let provider = provider_for(server.uri());
        let manager =
            ModelsManager::with_provider(opencli_home.path().to_path_buf(), auth_manager, provider);

        manager
            .refresh_available_models(&config, RefreshStrategy::OnlineIfUncached)
            .await
            .expect("refresh succeeds");
        let cached_remote = manager.get_remote_models(&config).await;
        assert_models_contain(&cached_remote, &remote_models);

        let available = manager
            .list_models(&config, RefreshStrategy::OnlineIfUncached)
            .await;
        let high_idx = available
            .iter()
            .position(|model| model.model == "priority-high")
            .expect("priority-high should be listed");
        let low_idx = available
            .iter()
            .position(|model| model.model == "priority-low")
            .expect("priority-low should be listed");
        assert!(
            high_idx < low_idx,
            "higher priority should be listed before lower priority"
        );
        assert_eq!(
            models_mock.requests().len(),
            1,
            "expected a single /models request"
        );
    }

    #[tokio::test]
    async fn refresh_available_models_uses_cache_when_fresh() {
        let server = MockServer::start().await;
        let remote_models = vec![remote_model("cached", "Cached", 5)];
        let models_mock = mount_models_once(
            &server,
            ModelsResponse {
                models: remote_models.clone(),
            },
        )
        .await;

        let opencli_home = tempdir().expect("temp dir");
        let mut config = ConfigBuilder::default()
            .opencli_home(opencli_home.path().to_path_buf())
            .build()
            .await
            .expect("load default test config");
        config.features.enable(Feature::RemoteModels);
        let auth_manager = Arc::new(AuthManager::new(
            opencli_home.path().to_path_buf(),
            false,
            AuthCredentialsStoreMode::File,
        ));
        let provider = provider_for(server.uri());
        let manager =
            ModelsManager::with_provider(opencli_home.path().to_path_buf(), auth_manager, provider);

        manager
            .refresh_available_models(&config, RefreshStrategy::OnlineIfUncached)
            .await
            .expect("first refresh succeeds");
        assert_models_contain(&manager.get_remote_models(&config).await, &remote_models);

        // Second call should read from cache and avoid the network.
        manager
            .refresh_available_models(&config, RefreshStrategy::OnlineIfUncached)
            .await
            .expect("cached refresh succeeds");
        assert_models_contain(&manager.get_remote_models(&config).await, &remote_models);
        assert_eq!(
            models_mock.requests().len(),
            1,
            "cache hit should avoid a second /models request"
        );
    }

    #[tokio::test]
    async fn refresh_available_models_refetches_when_cache_stale() {
        let server = MockServer::start().await;
        let initial_models = vec![remote_model("stale", "Stale", 1)];
        let initial_mock = mount_models_once(
            &server,
            ModelsResponse {
                models: initial_models.clone(),
            },
        )
        .await;

        let opencli_home = tempdir().expect("temp dir");
        let mut config = ConfigBuilder::default()
            .opencli_home(opencli_home.path().to_path_buf())
            .build()
            .await
            .expect("load default test config");
        config.features.enable(Feature::RemoteModels);
        let auth_manager = Arc::new(AuthManager::new(
            opencli_home.path().to_path_buf(),
            false,
            AuthCredentialsStoreMode::File,
        ));
        let provider = provider_for(server.uri());
        let manager =
            ModelsManager::with_provider(opencli_home.path().to_path_buf(), auth_manager, provider);

        manager
            .refresh_available_models(&config, RefreshStrategy::OnlineIfUncached)
            .await
            .expect("initial refresh succeeds");

        // Rewrite cache with an old timestamp so it is treated as stale.
        manager
            .cache_manager
            .manipulate_cache_for_test(|fetched_at| {
                *fetched_at = Utc::now() - chrono::Duration::hours(1);
            })
            .await
            .expect("cache manipulation succeeds");

        let updated_models = vec![remote_model("fresh", "Fresh", 9)];
        server.reset().await;
        let refreshed_mock = mount_models_once(
            &server,
            ModelsResponse {
                models: updated_models.clone(),
            },
        )
        .await;

        manager
            .refresh_available_models(&config, RefreshStrategy::OnlineIfUncached)
            .await
            .expect("second refresh succeeds");
        assert_models_contain(&manager.get_remote_models(&config).await, &updated_models);
        assert_eq!(
            initial_mock.requests().len(),
            1,
            "initial refresh should only hit /models once"
        );
        assert_eq!(
            refreshed_mock.requests().len(),
            1,
            "stale cache refresh should fetch /models once"
        );
    }

    #[tokio::test]
    async fn refresh_available_models_drops_removed_remote_models() {
        let server = MockServer::start().await;
        let initial_models = vec![remote_model("remote-old", "Remote Old", 1)];
        let initial_mock = mount_models_once(
            &server,
            ModelsResponse {
                models: initial_models,
            },
        )
        .await;

        let opencli_home = tempdir().expect("temp dir");
        let mut config = ConfigBuilder::default()
            .opencli_home(opencli_home.path().to_path_buf())
            .build()
            .await
            .expect("load default test config");
        config.features.enable(Feature::RemoteModels);
        let auth_manager = AuthManager::from_auth_for_testing(
            OpenCLIAuth::create_dummy_chatgpt_auth_for_testing(),
        );
        let provider = provider_for(server.uri());
        let mut manager =
            ModelsManager::with_provider(opencli_home.path().to_path_buf(), auth_manager, provider);
        manager.cache_manager.set_ttl(Duration::ZERO);

        manager
            .refresh_available_models(&config, RefreshStrategy::OnlineIfUncached)
            .await
            .expect("initial refresh succeeds");

        server.reset().await;
        let refreshed_models = vec![remote_model("remote-new", "Remote New", 1)];
        let refreshed_mock = mount_models_once(
            &server,
            ModelsResponse {
                models: refreshed_models,
            },
        )
        .await;

        manager
            .refresh_available_models(&config, RefreshStrategy::OnlineIfUncached)
            .await
            .expect("second refresh succeeds");

        let available = manager
            .try_list_models(&config)
            .expect("models should be available");
        assert!(
            available.iter().any(|preset| preset.model == "remote-new"),
            "new remote model should be listed"
        );
        assert!(
            !available.iter().any(|preset| preset.model == "remote-old"),
            "removed remote model should not be listed"
        );
        assert_eq!(
            initial_mock.requests().len(),
            1,
            "initial refresh should only hit /models once"
        );
        assert_eq!(
            refreshed_mock.requests().len(),
            1,
            "second refresh should only hit /models once"
        );
    }

    #[tokio::test]
    async fn build_available_models_picks_default_after_hiding_hidden_models() {
        let opencli_home = tempdir().expect("temp dir");
        let config = ConfigBuilder::default()
            .opencli_home(opencli_home.path().to_path_buf())
            .build()
            .await
            .expect("load default test config");
        let auth_manager =
            AuthManager::from_auth_for_testing(OpenCLIAuth::from_api_key("Test API Key"));
        let provider = provider_for("http://example.test".to_string());
        let mut manager =
            ModelsManager::with_provider(opencli_home.path().to_path_buf(), auth_manager, provider);
        manager.local_models = Vec::new();

        let hidden_model = remote_model_with_visibility("hidden", "Hidden", 0, "hide");
        let visible_model = remote_model_with_visibility("visible", "Visible", 1, "list");

        let expected_hidden = ModelPreset::from(hidden_model.clone());
        let mut expected_visible = ModelPreset::from(visible_model.clone());
        expected_visible.is_default = true;

        let available = manager.build_available_models(vec![hidden_model, visible_model], &config);

        assert_eq!(available, vec![expected_hidden, expected_visible]);
    }

    fn custom_model(model: &str, provider: &str) -> CustomModel {
        CustomModel {
            model: model.to_string(),
            provider: provider.to_string(),
            display_name: None,
            description: None,
            context_window: None,
            reasoning_efforts: Vec::new(),
            supports_personality: false,
            show_in_picker: true,
        }
    }

    #[test]
    fn should_append_a_user_declared_model_that_is_not_built_in() {
        let presets = merge_custom_models(
            &[custom_model("qwen3-max", "my-gateway")],
            builtin_model_presets(None),
        );

        let added = presets
            .iter()
            .find(|preset| preset.model == "qwen3-max")
            .expect("user-declared model should be listed");
        assert_eq!(added.provider.as_deref(), Some("my-gateway"));
        assert_eq!(added.display_name, "qwen3-max");
    }

    #[test]
    fn should_let_a_user_entry_shadow_an_existing_preset_without_reordering() {
        // This build ships no presets, so stand in for the remote catalog (or a
        // downstream build's defaults) to exercise the shadowing rule.
        let existing = merge_custom_models(
            &[
                custom_model("first", "catalog"),
                custom_model("shadow-me", "catalog"),
                custom_model("last", "catalog"),
            ],
            Vec::new(),
        );

        let presets =
            merge_custom_models(&[custom_model("shadow-me", "my-gateway")], existing.clone());

        assert_eq!(
            presets.len(),
            existing.len(),
            "shadowing must not add a row"
        );
        assert_eq!(
            presets.iter().map(|p| p.model.as_str()).collect::<Vec<_>>(),
            vec!["first", "shadow-me", "last"],
            "shadowing must not reorder the list"
        );
        assert_eq!(
            presets[1].provider.as_deref(),
            Some("my-gateway"),
            "the user entry should win at the original position"
        );
    }

    #[test]
    fn should_use_the_declared_display_name_and_description() {
        let custom = CustomModel {
            model: "qwen3-max".to_string(),
            provider: "my-gateway".to_string(),
            display_name: Some("Qwen3 Max".to_string()),
            description: Some("Self-hosted.".to_string()),
            context_window: None,
            reasoning_efforts: Vec::new(),
            supports_personality: false,
            show_in_picker: true,
        };

        let presets = merge_custom_models(&[custom], Vec::new());

        assert_eq!(presets[0].display_name, "Qwen3 Max");
        assert_eq!(presets[0].description, "Self-hosted.");
    }

    #[test]
    fn should_list_a_user_declared_model_ahead_of_catalog_models() {
        let mut presets = vec![
            ModelPreset {
                is_default: true,
                ..merge_custom_models(&[custom_model("catalog-a", "openai")], Vec::new())[0].clone()
            },
            merge_custom_models(&[custom_model("catalog-b", "openai")], Vec::new())[0].clone(),
            merge_custom_models(&[custom_model("mine", "my-gateway")], Vec::new())[0].clone(),
        ];

        promote_custom_models(&[custom_model("mine", "my-gateway")], &mut presets);

        assert_eq!(
            presets.iter().map(|p| p.model.as_str()).collect::<Vec<_>>(),
            vec!["mine", "catalog-a", "catalog-b"],
            "a declared model must be reachable without scrolling past the catalog"
        );
        assert!(
            presets[1].is_default,
            "promotion must not move the default onto a different model"
        );
    }

    #[test]
    fn should_leave_order_untouched_when_no_models_are_declared() {
        let mut presets = builtin_model_presets(None);
        let before: Vec<String> = presets.iter().map(|p| p.model.clone()).collect();

        promote_custom_models(&[], &mut presets);

        let after: Vec<String> = presets.iter().map(|p| p.model.clone()).collect();
        assert_eq!(before, after);
    }

    #[tokio::test]
    async fn should_apply_the_declared_context_window_to_an_unknown_model() {
        let opencli_home = tempdir().expect("temp dir");
        let mut config = ConfigBuilder::default()
            .opencli_home(opencli_home.path().to_path_buf())
            .build()
            .await
            .expect("load default test config");
        let mut declared = custom_model("huihui-qwen3.8-27b", "my-gateway");
        declared.context_window = Some(32_768);
        config.models = vec![declared];

        let auth_manager =
            AuthManager::from_auth_for_testing(OpenCLIAuth::from_api_key("Test API Key"));
        let provider = provider_for("http://example.test".to_string());
        let manager =
            ModelsManager::with_provider(opencli_home.path().to_path_buf(), auth_manager, provider);

        let info = manager.get_model_info("huihui-qwen3.8-27b", &config).await;

        assert_eq!(
            info.context_window,
            Some(32_768),
            "a declared window should replace the generic default for an unknown model"
        );
    }

    #[tokio::test]
    async fn should_let_a_declared_context_window_beat_a_learned_one() {
        // A learned window is recorded from a rejection, and when the gateway
        // names no limit it falls back to the session's total token usage — a
        // number that is not a window at all. One learned against an endpoint
        // that has since changed silently replaced a correct declaration, so
        // the agent planned for 96K against a server serving 32K and every
        // long conversation failed after eight invisible retries.
        let opencli_home = tempdir().expect("temp dir");
        let mut config = ConfigBuilder::default()
            .opencli_home(opencli_home.path().to_path_buf())
            .build()
            .await
            .expect("load default test config");
        let mut declared = custom_model("huihui-qwen3.8-27b", "my-gateway");
        declared.context_window = Some(32_768);
        config.models = vec![declared];
        crate::models_manager::learned_windows::record_window(
            opencli_home.path(),
            "huihui-qwen3.8-27b",
            101_420,
        );

        let auth_manager =
            AuthManager::from_auth_for_testing(OpenCLIAuth::from_api_key("Test API Key"));
        let provider = provider_for("http://example.test".to_string());
        let manager =
            ModelsManager::with_provider(opencli_home.path().to_path_buf(), auth_manager, provider);

        let info = manager.get_model_info("huihui-qwen3.8-27b", &config).await;

        assert_eq!(
            info.context_window,
            Some(32_768),
            "what the config says beats what a stale rejection taught"
        );
    }

    #[tokio::test]
    async fn should_still_use_a_learned_window_when_nothing_was_declared() {
        // Learning exists for the models nobody wrote down; this must keep
        // working, or every undeclared model falls back to a generic guess.
        let opencli_home = tempdir().expect("temp dir");
        let config = ConfigBuilder::default()
            .opencli_home(opencli_home.path().to_path_buf())
            .build()
            .await
            .expect("load default test config");
        crate::models_manager::learned_windows::record_window(
            opencli_home.path(),
            "some-undeclared-model",
            48_000,
        );

        let auth_manager =
            AuthManager::from_auth_for_testing(OpenCLIAuth::from_api_key("Test API Key"));
        let provider = provider_for("http://example.test".to_string());
        let manager =
            ModelsManager::with_provider(opencli_home.path().to_path_buf(), auth_manager, provider);

        let info = manager
            .get_model_info("some-undeclared-model", &config)
            .await;

        assert_eq!(info.context_window, Some(48_000));
    }

    #[tokio::test]
    async fn should_let_an_explicit_override_beat_the_declared_context_window() {
        let opencli_home = tempdir().expect("temp dir");
        let mut config = ConfigBuilder::default()
            .opencli_home(opencli_home.path().to_path_buf())
            .build()
            .await
            .expect("load default test config");
        let mut declared = custom_model("huihui-qwen3.8-27b", "my-gateway");
        declared.context_window = Some(32_768);
        config.models = vec![declared];
        config.model_context_window = Some(8_192);

        let auth_manager =
            AuthManager::from_auth_for_testing(OpenCLIAuth::from_api_key("Test API Key"));
        let provider = provider_for("http://example.test".to_string());
        let manager =
            ModelsManager::with_provider(opencli_home.path().to_path_buf(), auth_manager, provider);

        let info = manager.get_model_info("huihui-qwen3.8-27b", &config).await;

        assert_eq!(info.context_window, Some(8_192));
    }

    #[test]
    fn bundled_models_json_roundtrips() {
        let file_contents = include_str!("../../models.json");
        let response: ModelsResponse =
            serde_json::from_str(file_contents).expect("bundled models.json should deserialize");

        let serialized =
            serde_json::to_string(&response).expect("bundled models.json should serialize");
        let roundtripped: ModelsResponse =
            serde_json::from_str(&serialized).expect("serialized models.json should deserialize");

        assert_eq!(
            response, roundtripped,
            "bundled models.json should round trip through serde"
        );
        // Intentionally empty in this provider-neutral build; the assertion is
        // that the file still parses and round-trips, not that it has entries.
        assert!(response.models.is_empty());
    }
}
