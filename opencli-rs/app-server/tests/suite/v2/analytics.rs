use anyhow::Result;
use opencli_core::config::ConfigBuilder;
use opencli_core::config::types::OtelExporterKind;
use opencli_core::config::types::OtelHttpProtocol;
use pretty_assertions::assert_eq;
use std::collections::HashMap;
use tempfile::TempDir;

const SERVICE_VERSION: &str = "0.0.0-test";

fn set_metrics_exporter(config: &mut opencli_core::config::Config) {
    config.otel.metrics_exporter = OtelExporterKind::OtlpHttp {
        endpoint: "http://localhost:4318".to_string(),
        headers: HashMap::new(),
        protocol: OtelHttpProtocol::Json,
        tls: None,
    };
}

#[tokio::test]
async fn app_server_default_analytics_disabled_without_flag() -> Result<()> {
    let opencli_home = TempDir::new()?;
    let mut config = ConfigBuilder::default()
        .opencli_home(opencli_home.path().to_path_buf())
        .build()
        .await?;
    set_metrics_exporter(&mut config);
    config.analytics_enabled = None;

    let provider = opencli_core::otel_init::build_provider(
        &config,
        SERVICE_VERSION,
        Some("opencli_app_server"),
        false,
    )
    .map_err(|err| anyhow::anyhow!(err.to_string()))?;

    // With analytics unset in the config and the default flag is false, metrics are disabled.
    // No provider is built.
    assert_eq!(provider.is_none(), true);
    Ok(())
}

#[tokio::test]
async fn should_not_export_metrics_even_when_analytics_are_requested() -> Result<()> {
    // This build never exports telemetry over the network, whatever the config
    // or the caller asks for. The test used to assert the opposite, from before
    // that was decided; a passing assertion that metrics *are* exported would
    // mean the guarantee had been quietly lost.
    let opencli_home = TempDir::new()?;
    let mut config = ConfigBuilder::default()
        .opencli_home(opencli_home.path().to_path_buf())
        .build()
        .await?;
    set_metrics_exporter(&mut config);
    config.analytics_enabled = Some(true);

    let provider = opencli_core::otel_init::build_provider(
        &config,
        SERVICE_VERSION,
        Some("opencli_app_server"),
        true,
    )
    .map_err(|err| anyhow::anyhow!(err.to_string()))?;

    let has_metrics = provider.as_ref().and_then(|otel| otel.metrics()).is_some();
    assert_eq!(has_metrics, false);
    Ok(())
}
