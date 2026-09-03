use crate::harness::attributes_to_map;
use crate::harness::find_metric;
use opencli_app_server_protocol::AuthMode;
use opencli_otel::OtelManager;
use opencli_otel::metrics::MetricsClient;
use opencli_otel::metrics::MetricsConfig;
use opencli_otel::metrics::Result;
use opencli_protocol::ThreadId;
use opencli_protocol::protocol::SessionSource;
use opentelemetry_sdk::metrics::InMemoryMetricExporter;
use opentelemetry_sdk::metrics::data::AggregatedMetrics;
use opentelemetry_sdk::metrics::data::MetricData;
use pretty_assertions::assert_eq;
use std::collections::BTreeMap;

#[test]
fn snapshot_collects_metrics_without_shutdown() -> Result<()> {
    let exporter = InMemoryMetricExporter::default();
    let config = MetricsConfig::in_memory(
        "test",
        "opencli-cli",
        env!("CARGO_PKG_VERSION"),
        exporter.clone(),
    )
    .with_tag("service", "opencli-cli")?
    .with_runtime_reader();
    let metrics = MetricsClient::new(config)?;

    metrics.counter(
        "opencli.tool.call",
        1,
        &[("tool", "run"), ("success", "true")],
    )?;

    let snapshot = metrics.snapshot()?;

    let metric = find_metric(&snapshot, "opencli.tool.call").expect("counter metric missing");
    let attrs = match metric.data() {
        AggregatedMetrics::U64(data) => match data {
            MetricData::Sum(sum) => {
                let points: Vec<_> = sum.data_points().collect();
                assert_eq!(points.len(), 1);
                attributes_to_map(points[0].attributes())
            }
            _ => panic!("unexpected counter aggregation"),
        },
        _ => panic!("unexpected counter data type"),
    };

    let expected = BTreeMap::from([
        ("service".to_string(), "opencli-cli".to_string()),
        ("success".to_string(), "true".to_string()),
        ("tool".to_string(), "run".to_string()),
    ]);
    assert_eq!(attrs, expected);

    let finished = exporter
        .get_finished_metrics()
        .expect("finished metrics should be readable");
    assert!(finished.is_empty(), "expected no periodic exports yet");

    Ok(())
}

#[test]
fn manager_snapshot_metrics_collects_without_shutdown() -> Result<()> {
    let exporter = InMemoryMetricExporter::default();
    let config =
        MetricsConfig::in_memory("test", "opencli-cli", env!("CARGO_PKG_VERSION"), exporter)
            .with_tag("service", "opencli-cli")?
            .with_runtime_reader();
    let metrics = MetricsClient::new(config)?;
    let manager = OtelManager::new(
        ThreadId::new(),
        "gpt-5.1",
        "gpt-5.1",
        Some("account-id".to_string()),
        None,
        Some(AuthMode::ApiKey),
        true,
        "tty".to_string(),
        SessionSource::Cli,
    )
    .with_metrics(metrics);

    manager.counter(
        "opencli.tool.call",
        1,
        &[("tool", "run"), ("success", "true")],
    );

    let snapshot = manager.snapshot_metrics()?;
    let metric = find_metric(&snapshot, "opencli.tool.call").expect("counter metric missing");
    let attrs = match metric.data() {
        AggregatedMetrics::U64(data) => match data {
            MetricData::Sum(sum) => {
                let points: Vec<_> = sum.data_points().collect();
                assert_eq!(points.len(), 1);
                attributes_to_map(points[0].attributes())
            }
            _ => panic!("unexpected counter aggregation"),
        },
        _ => panic!("unexpected counter data type"),
    };

    let expected = BTreeMap::from([
        (
            "app.version".to_string(),
            env!("CARGO_PKG_VERSION").to_string(),
        ),
        ("auth_mode".to_string(), AuthMode::ApiKey.to_string()),
        ("model".to_string(), "gpt-5.1".to_string()),
        ("service".to_string(), "opencli-cli".to_string()),
        ("session_source".to_string(), "cli".to_string()),
        ("success".to_string(), "true".to_string()),
        ("tool".to_string(), "run".to_string()),
    ]);
    assert_eq!(attrs, expected);

    Ok(())
}
