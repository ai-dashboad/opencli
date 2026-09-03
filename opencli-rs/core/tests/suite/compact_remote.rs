#![allow(clippy::expect_used)]

use std::fs;

use anyhow::Result;
use core_test_support::responses;
use core_test_support::responses::mount_sse_once;
use core_test_support::responses::sse;
use core_test_support::skip_if_no_network;
use core_test_support::test_opencli::TestOpenCLIHarness;
use core_test_support::test_opencli::test_opencli;
use core_test_support::wait_for_event;
use core_test_support::wait_for_event_match;
use opencli_core::OpenCLIAuth;
use opencli_core::features::Feature;
use opencli_core::protocol::EventMsg;
use opencli_core::protocol::ItemCompletedEvent;
use opencli_core::protocol::ItemStartedEvent;
use opencli_core::protocol::Op;
use opencli_core::protocol::RolloutItem;
use opencli_core::protocol::RolloutLine;
use opencli_protocol::items::TurnItem;
use opencli_protocol::models::ContentItem;
use opencli_protocol::models::ResponseItem;
use opencli_protocol::user_input::UserInput;
use pretty_assertions::assert_eq;

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn remote_compact_replaces_history_for_followups() -> Result<()> {
    skip_if_no_network!(Ok(()));

    let harness = TestOpenCLIHarness::with_builder(
        test_opencli()
            .with_auth(OpenCLIAuth::create_dummy_chatgpt_auth_for_testing())
            .with_config(|config| {
                config.features.enable(Feature::RemoteCompaction);
            }),
    )
    .await?;
    let opencli = harness.test().opencli.clone();

    let responses_mock = responses::mount_sse_sequence(
        harness.server(),
        vec![
            responses::sse(vec![
                responses::ev_assistant_message("m1", "FIRST_REMOTE_REPLY"),
                responses::ev_completed("resp-1"),
            ]),
            responses::sse(vec![
                responses::ev_assistant_message("m2", "AFTER_COMPACT_REPLY"),
                responses::ev_completed("resp-2"),
            ]),
        ],
    )
    .await;

    let compacted_history = vec![
        ResponseItem::Message {
            id: None,
            role: "user".to_string(),
            content: vec![ContentItem::InputText {
                text: "REMOTE_COMPACTED_SUMMARY".to_string(),
            }],
            end_turn: None,
        },
        ResponseItem::Compaction {
            encrypted_content: "ENCRYPTED_COMPACTION_SUMMARY".to_string(),
        },
    ];
    let compact_mock = responses::mount_compact_json_once(
        harness.server(),
        serde_json::json!({ "output": compacted_history.clone() }),
    )
    .await;

    opencli
        .submit(Op::UserInput {
            items: vec![UserInput::Text {
                text: "hello remote compact".into(),
                text_elements: Vec::new(),
            }],
            final_output_json_schema: None,
        })
        .await?;
    wait_for_event(&opencli, |ev| matches!(ev, EventMsg::TurnComplete(_))).await;

    opencli.submit(Op::Compact).await?;
    wait_for_event(&opencli, |ev| matches!(ev, EventMsg::TurnComplete(_))).await;

    opencli
        .submit(Op::UserInput {
            items: vec![UserInput::Text {
                text: "after compact".into(),
                text_elements: Vec::new(),
            }],
            final_output_json_schema: None,
        })
        .await?;
    wait_for_event(&opencli, |ev| matches!(ev, EventMsg::TurnComplete(_))).await;

    let compact_request = compact_mock.single_request();
    assert_eq!(compact_request.path(), "/v1/responses/compact");
    assert_eq!(
        compact_request.header("chatgpt-account-id").as_deref(),
        Some("account_id")
    );
    assert_eq!(
        compact_request.header("authorization").as_deref(),
        Some("Bearer Access Token")
    );
    let compact_body = compact_request.body_json();
    assert_eq!(
        compact_body.get("model").and_then(|v| v.as_str()),
        Some(harness.test().session_configured.model.as_str())
    );
    let compact_body_text = compact_body.to_string();
    assert!(
        compact_body_text.contains("hello remote compact"),
        "expected compact request to include user history"
    );
    assert!(
        compact_body_text.contains("FIRST_REMOTE_REPLY"),
        "expected compact request to include assistant history"
    );

    let follow_up_body = responses_mock
        .requests()
        .last()
        .expect("follow-up request missing")
        .body_json()
        .to_string();
    assert!(
        follow_up_body.contains("REMOTE_COMPACTED_SUMMARY"),
        "expected follow-up request to use compacted history"
    );
    assert!(
        follow_up_body.contains("ENCRYPTED_COMPACTION_SUMMARY"),
        "expected follow-up request to include compaction summary item"
    );
    assert!(
        !follow_up_body.contains("FIRST_REMOTE_REPLY"),
        "expected follow-up request to drop pre-compaction assistant messages"
    );

    Ok(())
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn remote_compact_runs_automatically() -> Result<()> {
    skip_if_no_network!(Ok(()));

    let harness = TestOpenCLIHarness::with_builder(
        test_opencli()
            .with_auth(OpenCLIAuth::create_dummy_chatgpt_auth_for_testing())
            .with_config(|config| {
                config.features.enable(Feature::RemoteCompaction);
            }),
    )
    .await?;
    let opencli = harness.test().opencli.clone();

    mount_sse_once(
        harness.server(),
        sse(vec![
            responses::ev_shell_command_call("m1", "echo 'hi'"),
            responses::ev_completed_with_tokens("resp-1", 100000000), // over token limit
        ]),
    )
    .await;
    let responses_mock = mount_sse_once(
        harness.server(),
        responses::sse(vec![
            responses::ev_assistant_message("m2", "AFTER_COMPACT_REPLY"),
            responses::ev_completed("resp-2"),
        ]),
    )
    .await;

    let compacted_history = vec![
        ResponseItem::Message {
            id: None,
            role: "user".to_string(),
            content: vec![ContentItem::InputText {
                text: "REMOTE_COMPACTED_SUMMARY".to_string(),
            }],
            end_turn: None,
        },
        ResponseItem::Compaction {
            encrypted_content: "ENCRYPTED_COMPACTION_SUMMARY".to_string(),
        },
    ];
    let compact_mock = responses::mount_compact_json_once(
        harness.server(),
        serde_json::json!({ "output": compacted_history.clone() }),
    )
    .await;

    opencli
        .submit(Op::UserInput {
            items: vec![UserInput::Text {
                text: "hello remote compact".into(),
                text_elements: Vec::new(),
            }],
            final_output_json_schema: None,
        })
        .await?;

    let message = wait_for_event_match(&opencli, |event| match event {
        EventMsg::ContextCompacted(_) => Some(true),
        _ => None,
    })
    .await;
    wait_for_event(&opencli, |event| matches!(event, EventMsg::TurnComplete(_))).await;
    assert!(message);
    assert_eq!(compact_mock.requests().len(), 1);
    let follow_up_body = responses_mock.single_request().body_json().to_string();
    assert!(follow_up_body.contains("REMOTE_COMPACTED_SUMMARY"));
    assert!(follow_up_body.contains("ENCRYPTED_COMPACTION_SUMMARY"));

    Ok(())
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn remote_manual_compact_emits_context_compaction_items() -> Result<()> {
    skip_if_no_network!(Ok(()));

    let harness = TestOpenCLIHarness::with_builder(
        test_opencli()
            .with_auth(OpenCLIAuth::create_dummy_chatgpt_auth_for_testing())
            .with_config(|config| {
                config.features.enable(Feature::RemoteCompaction);
            }),
    )
    .await?;
    let opencli = harness.test().opencli.clone();

    mount_sse_once(
        harness.server(),
        sse(vec![
            responses::ev_assistant_message("m1", "REMOTE_REPLY"),
            responses::ev_completed("resp-1"),
        ]),
    )
    .await;

    let compacted_history = vec![
        ResponseItem::Message {
            id: None,
            role: "user".to_string(),
            content: vec![ContentItem::InputText {
                text: "REMOTE_COMPACTED_SUMMARY".to_string(),
            }],
            end_turn: None,
        },
        ResponseItem::Compaction {
            encrypted_content: "ENCRYPTED_COMPACTION_SUMMARY".to_string(),
        },
    ];
    let compact_mock = responses::mount_compact_json_once(
        harness.server(),
        serde_json::json!({ "output": compacted_history.clone() }),
    )
    .await;

    opencli
        .submit(Op::UserInput {
            items: vec![UserInput::Text {
                text: "manual remote compact".into(),
                text_elements: Vec::new(),
            }],
            final_output_json_schema: None,
        })
        .await?;
    wait_for_event(&opencli, |event| matches!(event, EventMsg::TurnComplete(_))).await;

    opencli.submit(Op::Compact).await?;

    let mut started_item = None;
    let mut completed_item = None;
    let mut legacy_event = false;
    let mut saw_turn_complete = false;

    while !saw_turn_complete || started_item.is_none() || completed_item.is_none() || !legacy_event
    {
        let event = opencli.next_event().await.unwrap();
        match event.msg {
            EventMsg::ItemStarted(ItemStartedEvent {
                item: TurnItem::ContextCompaction(item),
                ..
            }) => {
                started_item = Some(item);
            }
            EventMsg::ItemCompleted(ItemCompletedEvent {
                item: TurnItem::ContextCompaction(item),
                ..
            }) => {
                completed_item = Some(item);
            }
            EventMsg::ContextCompacted(_) => {
                legacy_event = true;
            }
            EventMsg::TurnComplete(_) => {
                saw_turn_complete = true;
            }
            _ => {}
        }
    }

    let started_item = started_item.expect("context compaction item started");
    let completed_item = completed_item.expect("context compaction item completed");
    assert_eq!(started_item.id, completed_item.id);
    assert!(legacy_event);
    assert_eq!(compact_mock.requests().len(), 1);

    Ok(())
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn remote_compact_persists_replacement_history_in_rollout() -> Result<()> {
    skip_if_no_network!(Ok(()));

    let harness = TestOpenCLIHarness::with_builder(
        test_opencli()
            .with_auth(OpenCLIAuth::create_dummy_chatgpt_auth_for_testing())
            .with_config(|config| {
                config.features.enable(Feature::RemoteCompaction);
            }),
    )
    .await?;
    let opencli = harness.test().opencli.clone();
    let rollout_path = harness
        .test()
        .session_configured
        .rollout_path
        .clone()
        .expect("rollout path");

    let responses_mock = responses::mount_sse_once(
        harness.server(),
        responses::sse(vec![
            responses::ev_assistant_message("m1", "COMPACT_BASELINE_REPLY"),
            responses::ev_completed("resp-1"),
        ]),
    )
    .await;

    let compacted_history = vec![
        ResponseItem::Message {
            id: None,
            role: "user".to_string(),
            content: vec![ContentItem::InputText {
                text: "COMPACTED_USER_SUMMARY".to_string(),
            }],
            end_turn: None,
        },
        ResponseItem::Compaction {
            encrypted_content: "ENCRYPTED_COMPACTION_SUMMARY".to_string(),
        },
        ResponseItem::Message {
            id: None,
            role: "assistant".to_string(),
            content: vec![ContentItem::OutputText {
                text: "COMPACTED_ASSISTANT_NOTE".to_string(),
            }],
            end_turn: None,
        },
    ];
    let compact_mock = responses::mount_compact_json_once(
        harness.server(),
        serde_json::json!({ "output": compacted_history.clone() }),
    )
    .await;

    opencli
        .submit(Op::UserInput {
            items: vec![UserInput::Text {
                text: "needs compaction".into(),
                text_elements: Vec::new(),
            }],
            final_output_json_schema: None,
        })
        .await?;
    wait_for_event(&opencli, |ev| matches!(ev, EventMsg::TurnComplete(_))).await;

    opencli.submit(Op::Compact).await?;
    wait_for_event(&opencli, |ev| matches!(ev, EventMsg::TurnComplete(_))).await;

    opencli.submit(Op::Shutdown).await?;
    wait_for_event(&opencli, |ev| matches!(ev, EventMsg::ShutdownComplete)).await;

    assert_eq!(responses_mock.requests().len(), 1);
    assert_eq!(compact_mock.requests().len(), 1);

    let rollout_text = fs::read_to_string(&rollout_path)?;
    let mut saw_compacted_history = false;
    for line in rollout_text
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
    {
        let Ok(entry) = serde_json::from_str::<RolloutLine>(line) else {
            continue;
        };
        if let RolloutItem::Compacted(compacted) = entry.item
            && compacted.message.is_empty()
            && compacted.replacement_history.as_ref() == Some(&compacted_history)
        {
            saw_compacted_history = true;
            break;
        }
    }

    assert!(
        saw_compacted_history,
        "expected rollout to persist remote compaction history"
    );

    Ok(())
}
