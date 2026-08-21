use std::sync::Arc;

use opencli_app_server_protocol::AuthMode;
use opencli_core::AuthManager;
use opencli_core::OpenCLIAuth;
use opencli_core::ContentItem;
use opencli_core::ModelClient;
use opencli_core::ModelProviderInfo;
use opencli_core::Prompt;
use opencli_core::ResponseEvent;
use opencli_core::ResponseItem;
use opencli_core::TransportManager;
use opencli_core::WEB_SEARCH_ELIGIBLE_HEADER;
use opencli_core::WireApi;
use opencli_core::models_manager::manager::ModelsManager;
use opencli_otel::OtelManager;
use opencli_protocol::ThreadId;
use opencli_protocol::config_types::ReasoningSummary;
use opencli_protocol::config_types::WebSearchMode;
use opencli_protocol::protocol::SessionSource;
use opencli_protocol::protocol::SubAgentSource;
use core_test_support::load_default_config_for_test;
use core_test_support::responses;
use core_test_support::test_opencli::test_opencli;
use futures::StreamExt;
use tempfile::TempDir;
use wiremock::matchers::header;

#[tokio::test]
async fn responses_stream_includes_subagent_header_on_review() {
    core_test_support::skip_if_no_network!();

    let server = responses::start_mock_server().await;
    let response_body = responses::sse(vec![
        responses::ev_response_created("resp-1"),
        responses::ev_completed("resp-1"),
    ]);

    let request_recorder = responses::mount_sse_once_match(
        &server,
        header("x-openai-subagent", "review"),
        response_body,
    )
    .await;

    let provider = ModelProviderInfo {
        name: "mock".into(),
        base_url: Some(format!("{}/v1", server.uri())),
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
    };

    let opencli_home = TempDir::new().expect("failed to create TempDir");
    let mut config = load_default_config_for_test(&opencli_home).await;
    config.model_provider_id = provider.name.clone();
    config.model_provider = provider.clone();
    let effort = config.model_reasoning_effort;
    let summary = config.model_reasoning_summary;
    let model = ModelsManager::get_model_offline(config.model.as_deref());
    config.model = Some(model.clone());
    let config = Arc::new(config);

    let conversation_id = ThreadId::new();
    let auth_mode = AuthMode::Chatgpt;
    let session_source = SessionSource::SubAgent(SubAgentSource::Review);
    let model_info = ModelsManager::construct_model_info_offline(model.as_str(), &config);
    let otel_manager = OtelManager::new(
        conversation_id,
        model.as_str(),
        model_info.slug.as_str(),
        None,
        Some("test@test.com".to_string()),
        Some(auth_mode),
        false,
        "test".to_string(),
        session_source.clone(),
    );

    let mut client_session = ModelClient::new(
        Arc::clone(&config),
        None,
        model_info,
        otel_manager,
        provider,
        effort,
        summary,
        conversation_id,
        session_source,
        TransportManager::new(),
    )
    .new_session();

    let mut prompt = Prompt::default();
    prompt.input = vec![ResponseItem::Message {
        id: None,
        role: "user".into(),
        content: vec![ContentItem::InputText {
            text: "hello".into(),
        }],
        end_turn: None,
    }];

    let mut stream = client_session.stream(&prompt).await.expect("stream failed");
    while let Some(event) = stream.next().await {
        if matches!(event, Ok(ResponseEvent::Completed { .. })) {
            break;
        }
    }

    let request = request_recorder.single_request();
    assert_eq!(
        request.header("x-openai-subagent").as_deref(),
        Some("review")
    );
}

#[tokio::test]
async fn responses_stream_includes_subagent_header_on_other() {
    core_test_support::skip_if_no_network!();

    let server = responses::start_mock_server().await;
    let response_body = responses::sse(vec![
        responses::ev_response_created("resp-1"),
        responses::ev_completed("resp-1"),
    ]);

    let request_recorder = responses::mount_sse_once_match(
        &server,
        header("x-openai-subagent", "my-task"),
        response_body,
    )
    .await;

    let provider = ModelProviderInfo {
        name: "mock".into(),
        base_url: Some(format!("{}/v1", server.uri())),
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
    };

    let opencli_home = TempDir::new().expect("failed to create TempDir");
    let mut config = load_default_config_for_test(&opencli_home).await;
    config.model_provider_id = provider.name.clone();
    config.model_provider = provider.clone();
    let effort = config.model_reasoning_effort;
    let summary = config.model_reasoning_summary;
    let model = ModelsManager::get_model_offline(config.model.as_deref());
    config.model = Some(model.clone());
    let config = Arc::new(config);

    let conversation_id = ThreadId::new();
    let auth_mode = AuthMode::Chatgpt;
    let session_source = SessionSource::SubAgent(SubAgentSource::Other("my-task".to_string()));
    let model_info = ModelsManager::construct_model_info_offline(model.as_str(), &config);

    let otel_manager = OtelManager::new(
        conversation_id,
        model.as_str(),
        model_info.slug.as_str(),
        None,
        Some("test@test.com".to_string()),
        Some(auth_mode),
        false,
        "test".to_string(),
        session_source.clone(),
    );

    let mut client_session = ModelClient::new(
        Arc::clone(&config),
        None,
        model_info,
        otel_manager,
        provider,
        effort,
        summary,
        conversation_id,
        session_source,
        TransportManager::new(),
    )
    .new_session();

    let mut prompt = Prompt::default();
    prompt.input = vec![ResponseItem::Message {
        id: None,
        role: "user".into(),
        content: vec![ContentItem::InputText {
            text: "hello".into(),
        }],
        end_turn: None,
    }];

    let mut stream = client_session.stream(&prompt).await.expect("stream failed");
    while let Some(event) = stream.next().await {
        if matches!(event, Ok(ResponseEvent::Completed { .. })) {
            break;
        }
    }

    let request = request_recorder.single_request();
    assert_eq!(
        request.header("x-openai-subagent").as_deref(),
        Some("my-task")
    );
}

#[tokio::test]
async fn responses_stream_includes_web_search_eligible_header_true_by_default() {
    core_test_support::skip_if_no_network!();

    let server = responses::start_mock_server().await;
    let response_body = responses::sse(vec![
        responses::ev_response_created("resp-1"),
        responses::ev_completed("resp-1"),
    ]);

    let request_recorder = responses::mount_sse_once_match(
        &server,
        header(WEB_SEARCH_ELIGIBLE_HEADER, "true"),
        response_body,
    )
    .await;

    let test = test_opencli().build(&server).await.expect("build test opencli");
    test.submit_turn("hello").await.expect("submit test prompt");

    let request = request_recorder.single_request();
    assert_eq!(
        request.header(WEB_SEARCH_ELIGIBLE_HEADER).as_deref(),
        Some("true")
    );
}

#[tokio::test]
async fn responses_stream_includes_web_search_eligible_header_false_when_disabled() {
    core_test_support::skip_if_no_network!();

    let server = responses::start_mock_server().await;
    let response_body = responses::sse(vec![
        responses::ev_response_created("resp-1"),
        responses::ev_completed("resp-1"),
    ]);

    let request_recorder = responses::mount_sse_once_match(
        &server,
        header(WEB_SEARCH_ELIGIBLE_HEADER, "false"),
        response_body,
    )
    .await;

    let test = test_opencli()
        .with_config(|config| {
            config.web_search_mode = Some(WebSearchMode::Disabled);
        })
        .build(&server)
        .await
        .expect("build test opencli");
    test.submit_turn("hello").await.expect("submit test prompt");

    let request = request_recorder.single_request();
    assert_eq!(
        request.header(WEB_SEARCH_ELIGIBLE_HEADER).as_deref(),
        Some("false")
    );
}

#[tokio::test]
async fn responses_respects_model_info_overrides_from_config() {
    core_test_support::skip_if_no_network!();

    let server = responses::start_mock_server().await;
    let response_body = responses::sse(vec![
        responses::ev_response_created("resp-1"),
        responses::ev_completed("resp-1"),
    ]);

    let request_recorder = responses::mount_sse_once(&server, response_body).await;

    let provider = ModelProviderInfo {
        name: "mock".into(),
        base_url: Some(format!("{}/v1", server.uri())),
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
    };

    let opencli_home = TempDir::new().expect("failed to create TempDir");
    let mut config = load_default_config_for_test(&opencli_home).await;
    config.model = Some("gpt-3.5-turbo".to_string());
    config.model_provider_id = provider.name.clone();
    config.model_provider = provider.clone();
    config.model_supports_reasoning_summaries = Some(true);
    config.model_reasoning_summary = ReasoningSummary::Detailed;
    let effort = config.model_reasoning_effort;
    let summary = config.model_reasoning_summary;
    let model = config.model.clone().expect("model configured");
    let config = Arc::new(config);

    let conversation_id = ThreadId::new();
    let auth_mode =
        AuthManager::from_auth_for_testing(OpenCLIAuth::from_api_key("Test API Key")).get_auth_mode();
    let session_source =
        SessionSource::SubAgent(SubAgentSource::Other("override-check".to_string()));
    let model_info = ModelsManager::construct_model_info_offline(model.as_str(), &config);
    let otel_manager = OtelManager::new(
        conversation_id,
        model.as_str(),
        model_info.slug.as_str(),
        None,
        Some("test@test.com".to_string()),
        auth_mode,
        false,
        "test".to_string(),
        session_source.clone(),
    );

    let mut client = ModelClient::new(
        Arc::clone(&config),
        None,
        model_info,
        otel_manager,
        provider,
        effort,
        summary,
        conversation_id,
        session_source,
        TransportManager::new(),
    )
    .new_session();

    let mut prompt = Prompt::default();
    prompt.input = vec![ResponseItem::Message {
        id: None,
        role: "user".into(),
        content: vec![ContentItem::InputText {
            text: "hello".into(),
        }],
        end_turn: None,
    }];

    let mut stream = client.stream(&prompt).await.expect("stream failed");
    while let Some(event) = stream.next().await {
        if matches!(event, Ok(ResponseEvent::Completed { .. })) {
            break;
        }
    }

    let request = request_recorder.single_request();
    let body = request.body_json();
    let reasoning = body
        .get("reasoning")
        .and_then(|value| value.as_object())
        .cloned();

    assert!(
        reasoning.is_some(),
        "reasoning should be present when config enables summaries"
    );

    assert_eq!(
        reasoning
            .as_ref()
            .and_then(|value| value.get("summary"))
            .and_then(|value| value.as_str()),
        Some("detailed")
    );
}
