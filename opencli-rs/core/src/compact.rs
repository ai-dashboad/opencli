use std::sync::Arc;

use crate::ModelProviderInfo;
use crate::Prompt;
use crate::client_common::ResponseEvent;
use crate::context_manager::ContextManager;
use crate::error::OpenCLIErr;
use crate::error::Result as OpenCLIResult;
use crate::features::Feature;
use crate::opencli::Session;
use crate::opencli::TurnContext;
use crate::opencli::get_last_assistant_message_from_turn;
use crate::protocol::CompactedItem;
use crate::protocol::EventMsg;
use crate::protocol::TurnContextItem;
use crate::protocol::TurnStartedEvent;
use crate::protocol::WarningEvent;
use crate::session_prefix::TURN_ABORTED_OPEN_TAG;
use crate::truncate::TruncationPolicy;
use crate::truncate::approx_token_count;
use crate::truncate::truncate_text;
use crate::util::backoff;
use futures::prelude::*;
use opencli_protocol::items::ContextCompactionItem;
use opencli_protocol::items::TurnItem;
use opencli_protocol::models::ContentItem;
use opencli_protocol::models::FunctionCallOutputContentItem;
use opencli_protocol::models::ResponseInputItem;
use opencli_protocol::models::ResponseItem;
use opencli_protocol::protocol::RolloutItem;
use opencli_protocol::user_input::UserInput;
use tracing::error;
use tracing::warn;

pub const SUMMARIZATION_PROMPT: &str = include_str!("../templates/compact/prompt.md");
pub const SUMMARY_PREFIX: &str = include_str!("../templates/compact/summary_prefix.md");
const COMPACT_USER_MESSAGE_MAX_TOKENS: usize = 20_000;

pub(crate) fn should_use_remote_compact_task(
    session: &Session,
    provider: &ModelProviderInfo,
) -> bool {
    provider.is_openai() && session.enabled(Feature::RemoteCompaction)
}

/// Shorter than this and it is not a summary of anything.
///
/// Deliberately a low bar. The job here is to tell a summary from an empty
/// answer or a stray bracket, not to judge how good it is — a terse summary of
/// a short exchange is still a summary, and refusing it would leave the
/// conversation growing with no way to shorten it.
const SHORTEST_USABLE_SUMMARY: usize = 40;

fn is_usable_summary(summary: &str) -> bool {
    let trimmed = summary.trim();
    trimmed.chars().count() >= SHORTEST_USABLE_SUMMARY && trimmed.chars().any(char::is_alphanumeric)
}

/// How much of the window one summarising request may use.
///
/// Half, not all: the request carries the conversation *and* the instruction
/// to summarise it, and the model still has to write the summary into what is
/// left.
fn summarising_budget(window: i64) -> i64 {
    window / 2
}

/// Summarise these items, without touching the session's own history.
///
/// `drain_to_completed` records what the model says into the conversation,
/// which is right for the final compaction and wrong for this: the summary of
/// an old chunk replaces that chunk, it does not get appended to the thread.
async fn summarise_items(
    turn_context: &TurnContext,
    base_instructions: opencli_protocol::models::BaseInstructions,
    items: Vec<ResponseItem>,
) -> OpenCLIResult<String> {
    let prompt = Prompt {
        input: items,
        base_instructions,
        personality: turn_context.personality,
        ..Default::default()
    };
    let mut client_session = turn_context.client.new_session();
    let mut stream = client_session.stream(&prompt).await?;
    let mut said = String::new();
    loop {
        let Some(event) = stream.next().await else {
            return Err(OpenCLIErr::Stream(
                "stream closed before response.completed".into(),
                None,
            ));
        };
        match event {
            Ok(ResponseEvent::OutputItemDone(ResponseItem::Message { content, .. })) => {
                if let Some(text) = content_items_to_text(&content) {
                    said.push_str(&text);
                }
            }
            Ok(ResponseEvent::Completed { .. }) => return Ok(said),
            Ok(_) => continue,
            Err(e) => return Err(e),
        }
    }
}

/// Bring an over-long conversation down to a size that can be summarised,
/// without discarding any of it.
///
/// A conversation larger than the window cannot be summarised in one request:
/// summarising it means sending it. Dropping the oldest messages would make it
/// fit, and an earlier attempt did exactly that — but a compaction that
/// discards is a failure wearing the right label; the model simply forgot what
/// was thrown away.
///
/// So it is cut into pieces that each fit on their own, every piece is
/// summarised once, and the pieces are replaced by their summaries. Nothing is
/// discarded: everything is either present or represented.
///
/// One pass, not a fold. Summarising the front repeatedly re-reads the summary
/// it just wrote, which on a real conversation took twenty-one model calls and
/// climbing where ten would do.
///
/// Returns how many pieces were summarised.
async fn condense_until_it_fits(
    sess: &Session,
    turn_context: &TurnContext,
    history: &mut ContextManager,
    budget: i64,
) -> OpenCLIResult<usize> {
    // The instruction to summarise is already the last thing in the history,
    // and it has to stay there. Summarising it along with everything else left
    // a request that was nothing but assistant messages, which the provider
    // refused outright: "Cannot have 2 or more assistant messages at the end
    // of the list."
    let mut items = history.raw_items().to_vec();
    let tail = match items.last() {
        Some(ResponseItem::Message { role, .. }) if role == "user" => items.pop(),
        _ => None,
    };

    let pieces = split_into_pieces(&items, budget, turn_context.truncation_policy);
    if pieces.len() < 2 {
        return Ok(0);
    }

    let base_instructions = sess.get_base_instructions().await;
    let mut summarised = Vec::with_capacity(pieces.len());
    for (at, piece) in pieces.iter().enumerate() {
        sess.notify_background_event(
            turn_context,
            // Short and structured: the interface puts this under a line of
            // its own that already says what is happening, and a sentence
            // crammed in beside that read as an alarm.
            format!(
                "part {} of {} · nothing is being lost",
                at + 1,
                pieces.len()
            ),
        )
        .await;

        // Through a history rather than sent as raw items.
        //
        // Cutting a conversation at an arbitrary point can put a tool call in
        // one piece and its output in the next, and a conversation with a call
        // that is never answered is not a conversation a model will accept —
        // the request failed, was retried eight times, and a compaction that
        // should have taken ten seconds a piece sat there for five minutes.
        // `for_prompt` restores the invariant, and drops the snapshots that
        // have no business being summarised.
        let mut to_summarise = prepare_piece(piece, turn_context.truncation_policy);
        to_summarise.push(ResponseItem::Message {
            id: None,
            role: "user".to_string(),
            content: vec![ContentItem::InputText {
                text: turn_context.compact_prompt().to_string(),
            }],
            end_turn: None,
        });
        let summary =
            summarise_items(turn_context, base_instructions.clone(), to_summarise).await?;
        summarised.push(ResponseItem::Message {
            id: None,
            role: "assistant".to_string(),
            content: vec![ContentItem::OutputText {
                text: format!("{SUMMARY_PREFIX}\n{summary}"),
            }],
            end_turn: None,
        });
    }

    summarised.extend(tail);
    history.replace(summarised);
    Ok(pieces.len())
}

/// Make a piece of a conversation into something a model will accept.
///
/// Cutting at an arbitrary point can put a tool call in one piece and its
/// output in the next, and a call that is never answered is not a
/// conversation — the request failed, was retried eight times, and a
/// compaction that should have taken ten seconds a piece sat for five
/// minutes. Going through a history restores the invariant and drops the
/// snapshots that have no business being summarised.
fn prepare_piece(
    piece: &[ResponseItem],
    policy: crate::truncate::TruncationPolicy,
) -> Vec<ResponseItem> {
    let without_images: Vec<ResponseItem> = piece.iter().cloned().map(drop_images).collect();
    let mut history = ContextManager::new();
    history.record_items(without_images.iter(), policy);
    history.for_prompt()
}

/// Replace pictures with a word saying one was there.
///
/// An image is carried as base64, and in a real conversation each one came to
/// 286,772 characters — on its own more than twice a 32K window. Nothing can
/// summarise a piece like that, so the request failed after minutes and was
/// retried eight times, and the compaction never finished.
///
/// There is nothing in a picture to summarise anyway. What matters for a
/// summary is that one was sent, which is what stays.
fn drop_images(item: ResponseItem) -> ResponseItem {
    const PLACEHOLDER: &str = "[an image was shared here]";
    match item {
        ResponseItem::Message {
            id,
            role,
            content,
            end_turn,
        } => ResponseItem::Message {
            id,
            role,
            content: content
                .into_iter()
                .map(|part| match part {
                    ContentItem::InputImage { .. } => ContentItem::InputText {
                        text: PLACEHOLDER.to_string(),
                    },
                    kept => kept,
                })
                .collect(),
            end_turn,
        },
        ResponseItem::FunctionCallOutput {
            call_id,
            mut output,
        } => {
            if let Some(items) = output.content_items.take() {
                output.content_items = Some(
                    items
                        .into_iter()
                        .map(|part| match part {
                            FunctionCallOutputContentItem::InputImage { .. } => {
                                FunctionCallOutputContentItem::InputText {
                                    text: PLACEHOLDER.to_string(),
                                }
                            }
                            kept => kept,
                        })
                        .collect(),
                );
            }
            ResponseItem::FunctionCallOutput { call_id, output }
        }
        kept => kept,
    }
}

/// The model's own scratch work, which a summary does not need.
///
/// Reasoning is the largest thing in a long conversation by a wide margin: in
/// the one this was measured on, the four biggest items were all reasoning, at
/// 101, 87, 85 and 75 thousand characters, and reasoning was most of the 693
/// thousand tokens the conversation had grown to. Summarising it costs the
/// bulk of the time compaction takes.
///
/// It is also the part with least to summarise. What happened is in the
/// messages and the tool calls — what was asked, what was run, what came back.
/// Reasoning is how the model got from one to the next, and it has already
/// got there.
///
/// Dropped only from what is *summarised*. The conversation on disk keeps
/// everything, and a reopened one still shows the thinking.
fn worth_summarising(item: &ResponseItem) -> bool {
    !matches!(item, ResponseItem::Reasoning { .. })
}

/// Cut down an item that on its own is larger than a whole piece.
///
/// Splitting between items is not enough: a single reasoning block or command
/// output can be bigger than the model's entire window, and a piece containing
/// it fails however it is arranged. The request then comes back "context
/// exceeded", is retried, and fails the same way — compaction that cannot
/// finish, which is what a conversation of 693 thousand tokens against a 30
/// thousand window ran into.
///
/// The head and the tail are kept because that is where a piece of text says
/// what it is and how it ended; the middle is replaced by a line saying how
/// much went.
fn cut_to_fit(
    item: ResponseItem,
    budget: i64,
    policy: crate::truncate::TruncationPolicy,
) -> ResponseItem {
    // Measured the way the rest of the system measures, so the two agree.
    let mut measured = ContextManager::new();
    measured.record_items(std::slice::from_ref(&item), policy);
    if measured.estimated_token_usage() <= budget {
        return item;
    }

    // Three bytes to a token, matching the estimate, and a margin for the
    // envelope around the text.
    let room = ((budget as usize).saturating_mul(3)).saturating_sub(512);
    map_text(item, |text| shorten(&text, room))
}

/// Keep both ends of a long string and say what was removed.
fn shorten(text: &str, room: usize) -> String {
    if text.len() <= room || room < 200 {
        return text.to_string();
    }
    let half = room / 2;
    let head = floor_char_boundary(text, half);
    let tail = ceil_char_boundary(text, text.len() - half);
    let removed = tail - head;
    format!(
        "{}\n\n[… {removed} characters removed to fit this for summarising …]\n\n{}",
        &text[..head],
        &text[tail..]
    )
}

fn floor_char_boundary(text: &str, mut at: usize) -> usize {
    while at > 0 && !text.is_char_boundary(at) {
        at -= 1;
    }
    at
}

fn ceil_char_boundary(text: &str, mut at: usize) -> usize {
    while at < text.len() && !text.is_char_boundary(at) {
        at += 1;
    }
    at
}

/// Apply `change` to every piece of text an item carries.
fn map_text(item: ResponseItem, change: impl Fn(String) -> String + Copy) -> ResponseItem {
    match item {
        ResponseItem::Message {
            id,
            role,
            content,
            end_turn,
        } => ResponseItem::Message {
            id,
            role,
            content: content
                .into_iter()
                .map(|part| match part {
                    ContentItem::InputText { text } => {
                        ContentItem::InputText { text: change(text) }
                    }
                    ContentItem::OutputText { text } => {
                        ContentItem::OutputText { text: change(text) }
                    }
                    kept => kept,
                })
                .collect(),
            end_turn,
        },
        ResponseItem::FunctionCall {
            id,
            name,
            arguments,
            call_id,
        } => ResponseItem::FunctionCall {
            id,
            name,
            arguments: change(arguments),
            call_id,
        },
        ResponseItem::FunctionCallOutput {
            call_id,
            mut output,
        } => {
            output.content = change(output.content);
            ResponseItem::FunctionCallOutput { call_id, output }
        }
        kept => kept,
    }
}

/// Cut a conversation into consecutive pieces that each fit `budget`.
fn split_into_pieces(
    items: &[ResponseItem],
    budget: i64,
    policy: crate::truncate::TruncationPolicy,
) -> Vec<Vec<ResponseItem>> {
    let mut pieces: Vec<Vec<ResponseItem>> = Vec::new();
    let mut piece: Vec<ResponseItem> = Vec::new();
    let mut measured = ContextManager::new();

    for item in items.iter().filter(|item| worth_summarising(item)) {
        // Cut first, so what is measured is what will be sent. An item bigger
        // than a whole piece cannot be placed by splitting alone.
        let item = cut_to_fit(item.clone(), budget, policy);
        measured.record_items(std::slice::from_ref(&item), policy);
        if measured.estimated_token_usage() > budget && !piece.is_empty() {
            pieces.push(std::mem::take(&mut piece));
            measured = ContextManager::new();
            measured.record_items(std::slice::from_ref(&item), policy);
        }
        piece.push(item);
    }
    if !piece.is_empty() {
        pieces.push(piece);
    }
    pieces
}

pub(crate) async fn run_inline_auto_compact_task(
    sess: Arc<Session>,
    turn_context: Arc<TurnContext>,
) {
    let prompt = turn_context.compact_prompt().to_string();
    let input = vec![UserInput::Text {
        text: prompt,
        // Compaction prompt is synthesized; no UI element ranges to preserve.
        text_elements: Vec::new(),
    }];

    run_compact_task_inner(sess, turn_context, input).await;
}

pub(crate) async fn run_compact_task(
    sess: Arc<Session>,
    turn_context: Arc<TurnContext>,
    input: Vec<UserInput>,
) {
    let start_event = EventMsg::TurnStarted(TurnStartedEvent {
        model_context_window: turn_context.client.get_model_context_window(),
        collaboration_mode_kind: turn_context.collaboration_mode.mode,
    });
    sess.send_event(&turn_context, start_event).await;
    run_compact_task_inner(sess.clone(), turn_context, input).await;
}

async fn run_compact_task_inner(
    sess: Arc<Session>,
    turn_context: Arc<TurnContext>,
    input: Vec<UserInput>,
) {
    let compaction_item = TurnItem::ContextCompaction(ContextCompactionItem::new());
    sess.emit_turn_item_started(&turn_context, &compaction_item)
        .await;
    let initial_input_for_turn: ResponseInputItem = ResponseInputItem::from(input);

    let mut history = sess.clone_history().await;
    history.record_items(
        &[initial_input_for_turn.into()],
        turn_context.truncation_policy,
    );

    let mut truncated_count = 0usize;

    let max_retries = turn_context.client.get_provider().stream_max_retries();
    let mut retries = 0;

    // TODO: If we need to guarantee the persisted mode always matches the prompt used for this
    // turn, capture it in TurnContext at creation time. Using SessionConfiguration here avoids
    // duplicating model settings on TurnContext, but an Op after turn start could update the
    // session config before this write occurs.
    let collaboration_mode = sess.current_collaboration_mode().await;
    let rollout_item = RolloutItem::TurnContext(TurnContextItem {
        cwd: turn_context.cwd.clone(),
        approval_policy: turn_context.approval_policy,
        sandbox_policy: turn_context.sandbox_policy.clone(),
        model: turn_context.client.get_model(),
        personality: turn_context.personality,
        collaboration_mode: Some(collaboration_mode),
        effort: turn_context.client.get_reasoning_effort(),
        summary: turn_context.client.get_reasoning_summary(),
        user_instructions: turn_context.user_instructions.clone(),
        developer_instructions: turn_context.developer_instructions.clone(),
        final_output_json_schema: turn_context.final_output_json_schema.clone(),
        truncation_policy: Some(turn_context.truncation_policy.into()),
    });
    sess.persist_rollout_items(&[rollout_item]).await;

    // Compaction re-sends the whole thread to the model to summarize it, which
    // on a slow gateway or a small context window can take a while and may trim
    // in several passes. Announce it so the turn does not look frozen; the
    // header updates again on each trim below.
    sess.notify_background_event(turn_context.as_ref(), "reading the conversation")
        .await;

    // A conversation too large to summarise in one request is folded down
    // first, oldest part by oldest part, until what remains can be. Nothing is
    // discarded on the way: each part is replaced by a summary of itself.
    if let Some(window) = turn_context.client.get_model_context_window() {
        let budget = summarising_budget(window);
        if history.estimated_token_usage() > budget {
            match condense_until_it_fits(&sess, turn_context.as_ref(), &mut history, budget).await {
                Ok(rounds) if rounds > 0 => {
                    sess.notify_background_event(
                        turn_context.as_ref(),
                        format!("summarised {rounds} part(s); writing the summary"),
                    )
                    .await;
                }
                Ok(_) => {}
                Err(OpenCLIErr::Interrupted) => return,
                Err(e) => {
                    // Fall through to the loop below, which retries and — if
                    // the provider refuses even that — trims as a last resort.
                    warn!("could not fold the oldest part of the conversation: {e:#}");
                }
            }
        }
    }

    // Nothing is dropped here.
    //
    // An earlier attempt trimmed the oldest messages before summarising, to
    // guarantee the request fit. It did fit, and the conversation continued —
    // but the messages it dropped were never summarised, so the model simply
    // forgot them, and the reader was told eighty messages had been dropped.
    // Compaction exists to *keep* a conversation, condensed; a compaction that
    // discards is a failure wearing the right label.
    //
    // Fitting is handled instead by summarising early enough that the whole
    // conversation still fits — `auto_compact_token_limit` is seven tenths of
    // the window, not nine — and by the loop below, which trims only if the
    // provider refuses even that, which is the last resort it always was.

    loop {
        // Clone is required because of the loop
        let turn_input = history.clone().for_prompt();
        let turn_input_len = turn_input.len();
        let prompt = Prompt {
            input: turn_input,
            base_instructions: sess.get_base_instructions().await,
            personality: turn_context.personality,
            ..Default::default()
        };
        let attempt_result = drain_to_completed(&sess, turn_context.as_ref(), &prompt).await;

        match attempt_result {
            Ok(()) => {
                if truncated_count > 0 {
                    sess.notify_background_event(
                        turn_context.as_ref(),
                        format!("trimmed {truncated_count} old message(s) to fit"),
                    )
                    .await;
                }
                break;
            }
            Err(OpenCLIErr::Interrupted) => {
                return;
            }
            Err(e @ OpenCLIErr::ContextWindowExceeded { .. }) => {
                if turn_input_len > 1 {
                    // Trim from the beginning to preserve cache (prefix-based) and keep recent messages intact.
                    error!(
                        "Context window exceeded while compacting; removing oldest history item. Error: {e}"
                    );
                    history.remove_first_item();
                    truncated_count += 1;
                    retries = 0;
                    // Show the trim so a multi-pass compaction reads as progress
                    // rather than a hang.
                    sess.notify_background_event(
                        turn_context.as_ref(),
                        format!("trimmed {truncated_count} old message(s) to fit"),
                    )
                    .await;
                    continue;
                }
                sess.set_total_tokens_full(turn_context.as_ref()).await;
                let event = EventMsg::Error(e.to_error_event(None));
                sess.send_event(&turn_context, event).await;
                return;
            }
            Err(e) => {
                if retries < max_retries {
                    retries += 1;
                    let delay = backoff(retries);
                    sess.notify_stream_error(
                        turn_context.as_ref(),
                        format!("Reconnecting... {retries}/{max_retries}"),
                        e,
                    )
                    .await;
                    tokio::time::sleep(delay).await;
                    continue;
                } else {
                    let event = EventMsg::Error(e.to_error_event(None));
                    sess.send_event(&turn_context, event).await;
                    return;
                }
            }
        }
    }

    let history_snapshot = sess.clone_history().await;
    let history_items = history_snapshot.raw_items();
    let summary_suffix = get_last_assistant_message_from_turn(history_items).unwrap_or_default();

    // A model that answered but said nothing has not summarised anything, and
    // replacing the conversation with what it said would destroy the
    // conversation to no purpose. This is not a corner case: a local model
    // asked to summarise a thread that had just been compacted returned the
    // single character `)`, nine times running, and each time the thread was
    // replaced by it.
    if !is_usable_summary(&summary_suffix) {
        warn!("compaction produced no usable summary; keeping the conversation as it stands");
        sess.emit_turn_item_completed(&turn_context, compaction_item)
            .await;
        sess.send_event(
            &turn_context,
            EventMsg::Warning(WarningEvent {
                message: "The model did not produce a summary, so the conversation was left as \
                          it is."
                    .to_string(),
            }),
        )
        .await;
        return;
    }

    let summary_text = format!("{SUMMARY_PREFIX}\n{summary_suffix}");
    let user_messages = collect_user_messages(history_items);

    let initial_context = sess.build_initial_context(turn_context.as_ref()).await;
    let mut new_history = build_compacted_history(initial_context, &user_messages, &summary_text);
    let ghost_snapshots: Vec<ResponseItem> = history_items
        .iter()
        .filter(|item| matches!(item, ResponseItem::GhostSnapshot { .. }))
        .cloned()
        .collect();
    new_history.extend(ghost_snapshots);
    sess.replace_history(new_history).await;
    sess.recompute_token_usage(&turn_context).await;

    let rollout_item = RolloutItem::Compacted(CompactedItem {
        message: summary_text.clone(),
        replacement_history: None,
    });
    sess.persist_rollout_items(&[rollout_item]).await;

    sess.emit_turn_item_completed(&turn_context, compaction_item)
        .await;
    let warning = EventMsg::Warning(WarningEvent {
        message: "Heads up: Long threads and multiple compactions can cause the model to be less accurate. Start a new thread when possible to keep threads small and targeted.".to_string(),
    });
    sess.send_event(&turn_context, warning).await;
}

pub fn content_items_to_text(content: &[ContentItem]) -> Option<String> {
    let mut pieces = Vec::new();
    for item in content {
        match item {
            ContentItem::InputText { text } | ContentItem::OutputText { text } => {
                if !text.is_empty() {
                    pieces.push(text.as_str());
                }
            }
            ContentItem::InputImage { .. } => {}
        }
    }
    if pieces.is_empty() {
        None
    } else {
        Some(pieces.join("\n"))
    }
}

pub(crate) fn collect_user_messages(items: &[ResponseItem]) -> Vec<String> {
    items
        .iter()
        .filter_map(|item| match crate::event_mapping::parse_turn_item(item) {
            Some(TurnItem::UserMessage(user)) => {
                if is_summary_message(&user.message()) {
                    None
                } else {
                    Some(user.message())
                }
            }
            _ => collect_turn_aborted_marker(item),
        })
        .collect()
}

fn collect_turn_aborted_marker(item: &ResponseItem) -> Option<String> {
    let ResponseItem::Message { role, content, .. } = item else {
        return None;
    };
    if role != "user" {
        return None;
    }

    let text = content_items_to_text(content)?;
    if text
        .trim_start()
        .to_ascii_lowercase()
        .starts_with(TURN_ABORTED_OPEN_TAG)
    {
        Some(text)
    } else {
        None
    }
}

pub(crate) fn is_summary_message(message: &str) -> bool {
    message.starts_with(format!("{SUMMARY_PREFIX}\n").as_str())
}

pub(crate) fn build_compacted_history(
    initial_context: Vec<ResponseItem>,
    user_messages: &[String],
    summary_text: &str,
) -> Vec<ResponseItem> {
    build_compacted_history_with_limit(
        initial_context,
        user_messages,
        summary_text,
        COMPACT_USER_MESSAGE_MAX_TOKENS,
    )
}

fn build_compacted_history_with_limit(
    mut history: Vec<ResponseItem>,
    user_messages: &[String],
    summary_text: &str,
    max_tokens: usize,
) -> Vec<ResponseItem> {
    let mut selected_messages: Vec<String> = Vec::new();
    if max_tokens > 0 {
        let mut remaining = max_tokens;
        for message in user_messages.iter().rev() {
            if remaining == 0 {
                break;
            }
            let tokens = approx_token_count(message);
            if tokens <= remaining {
                selected_messages.push(message.clone());
                remaining = remaining.saturating_sub(tokens);
            } else {
                let truncated = truncate_text(message, TruncationPolicy::Tokens(remaining));
                selected_messages.push(truncated);
                break;
            }
        }
        selected_messages.reverse();
    }

    for message in &selected_messages {
        history.push(ResponseItem::Message {
            id: None,
            role: "user".to_string(),
            content: vec![ContentItem::InputText {
                text: message.clone(),
            }],
            end_turn: None,
        });
    }

    let summary_text = if summary_text.is_empty() {
        "(no summary available)".to_string()
    } else {
        summary_text.to_string()
    };

    history.push(ResponseItem::Message {
        id: None,
        role: "user".to_string(),
        content: vec![ContentItem::InputText { text: summary_text }],
        end_turn: None,
    });

    history
}

async fn drain_to_completed(
    sess: &Session,
    turn_context: &TurnContext,
    prompt: &Prompt,
) -> OpenCLIResult<()> {
    let mut client_session = turn_context.client.new_session();
    let mut stream = client_session.stream(prompt).await?;
    loop {
        let maybe_event = stream.next().await;
        let Some(event) = maybe_event else {
            return Err(OpenCLIErr::Stream(
                "stream closed before response.completed".into(),
                None,
            ));
        };
        match event {
            Ok(ResponseEvent::OutputItemDone(item)) => {
                sess.record_into_history(std::slice::from_ref(&item), turn_context)
                    .await;
            }
            Ok(ResponseEvent::ServerReasoningIncluded(included)) => {
                sess.set_server_reasoning_included(included).await;
            }
            Ok(ResponseEvent::RateLimits(snapshot)) => {
                sess.update_rate_limits(turn_context, snapshot).await;
            }
            Ok(ResponseEvent::Completed { token_usage, .. }) => {
                sess.update_token_usage_info(turn_context, token_usage.as_ref())
                    .await;
                return Ok(());
            }
            Ok(_) => continue,
            Err(e) => return Err(e),
        }
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn should_reject_a_summary_that_summarises_nothing() {
        // A local model asked to summarise a thread that had just been
        // compacted answered with a single closing bracket, nine times in a
        // row. Each answer replaced the conversation.
        assert!(!is_usable_summary(")"));
        assert!(!is_usable_summary(""));
        assert!(!is_usable_summary("   \n  "));
        assert!(!is_usable_summary("Sure!"));
    }

    #[test]
    fn should_accept_a_short_but_real_summary() {
        assert!(is_usable_summary(
            "The user asked for the build to be fixed; the icon path was wrong."
        ));
    }

    #[test]
    fn should_reject_punctuation_long_enough_to_pass_for_a_summary() {
        assert!(!is_usable_summary(&"-".repeat(200)));
    }

    use super::*;
    use crate::session_prefix::TURN_ABORTED_OPEN_TAG;
    use pretty_assertions::assert_eq;

    #[test]
    fn should_cut_an_item_that_is_bigger_than_a_whole_piece() {
        // Splitting between items cannot place one that is larger than the
        // budget by itself. The piece was sent anyway, the request came back
        // "context exceeded", and compaction retried it forever.
        let huge = said(&"x".repeat(200_000));
        let pieces = split_into_pieces(
            std::slice::from_ref(&huge),
            1_000,
            crate::truncate::TruncationPolicy::Tokens(10_000),
        );

        assert_eq!(pieces.len(), 1);
        let mut measured = ContextManager::new();
        measured.record_items(
            pieces[0].iter(),
            crate::truncate::TruncationPolicy::Tokens(10_000),
        );
        assert!(
            measured.estimated_token_usage() <= 1_000,
            "a piece must fit the budget it was cut for, got {}",
            measured.estimated_token_usage()
        );
    }

    #[test]
    fn should_keep_both_ends_of_what_it_cuts() {
        // The beginning says what the text is; the end says how it finished.
        let text = format!("BEGINNING{}ENDING", "x".repeat(50_000));
        let shortened = shorten(&text, 2_000);
        assert!(shortened.starts_with("BEGINNING"), "{}", &shortened[..40]);
        assert!(shortened.ends_with("ENDING"));
        assert!(shortened.contains("characters removed"));
        assert!(shortened.len() < text.len());
    }

    #[test]
    fn should_leave_something_that_already_fits_alone() {
        let small = said("a short answer");
        let same = cut_to_fit(
            small.clone(),
            10_000,
            crate::truncate::TruncationPolicy::Tokens(10_000),
        );
        assert_eq!(same, small);
    }

    #[test]
    fn should_not_summarise_the_models_scratch_work() {
        // Reasoning was most of the conversation this was found on — the four
        // largest items were all reasoning — and none of it is what a summary
        // of what happened is made from.
        let thinking = ResponseItem::Reasoning {
            id: String::new(),
            summary: Vec::new(),
            content: None,
            encrypted_content: None,
        };
        let pieces = split_into_pieces(
            &[thinking, said("the answer")],
            10_000,
            crate::truncate::TruncationPolicy::Tokens(10_000),
        );
        let kept: usize = pieces.iter().map(Vec::len).sum();
        assert_eq!(kept, 1, "only the answer should be summarised");
    }

    fn said(text: &str) -> ResponseItem {
        ResponseItem::Message {
            id: None,
            role: "assistant".to_string(),
            content: vec![ContentItem::OutputText {
                text: text.to_string(),
            }],
            end_turn: None,
        }
    }

    #[test]
    fn should_not_summarise_the_instruction_to_summarise() {
        // It is the last thing in the history and has to stay there. Folding
        // it in with everything else left a request that was nothing but
        // assistant messages, which the provider refused: "Cannot have 2 or
        // more assistant messages at the end of the list."
        let asked = ResponseItem::Message {
            id: None,
            role: "user".to_string(),
            content: vec![ContentItem::InputText {
                text: "Summarise the conversation.".to_string(),
            }],
            end_turn: None,
        };
        let mut items: Vec<ResponseItem> = (0..8).map(|_| said(&"word ".repeat(200))).collect();
        items.push(asked.clone());

        // What the condensing does with the tail, without a model to call.
        let tail = match items.last() {
            Some(ResponseItem::Message { role, .. }) if role == "user" => items.pop(),
            _ => None,
        };

        assert_eq!(tail.as_ref(), Some(&asked), "the instruction is held back");
        assert!(
            !items.iter().any(|item| item == &asked),
            "and is not among the messages being summarised"
        );
    }

    #[test]
    fn should_not_carry_a_picture_through_a_compaction() {
        // What makes pricing an image honestly safe: once compaction runs, the
        // encoding is gone, so the estimate falls and it does not fire again.
        // If a picture survived, every compaction would be followed by another.
        let huge = "A".repeat(280_000);
        let asked = ResponseItem::Message {
            id: None,
            role: "user".to_string(),
            content: vec![
                ContentItem::InputText {
                    text: "what is in this".to_string(),
                },
                ContentItem::InputImage {
                    image_url: format!("data:image/png;base64,{huge}"),
                },
            ],
            end_turn: None,
        };

        let kept = collect_user_messages(std::slice::from_ref(&asked));
        let rebuilt = build_compacted_history(Vec::new(), &kept, "a summary");

        let sent = serde_json::to_string(&rebuilt).expect("serialise");
        assert!(!sent.contains(&huge), "the encoding must not survive");
        assert!(sent.contains("what is in this"), "the words around it must");
    }

    #[test]
    fn should_not_try_to_summarise_a_picture() {
        // Measured on a real conversation: one image came to 286,772
        // characters of base64 — on its own more than twice a 32K window, so
        // the piece holding it could never be summarised. The request failed
        // after minutes and was retried eight times.
        let huge = "A".repeat(280_000);
        let piece = vec![ResponseItem::Message {
            id: None,
            role: "user".to_string(),
            content: vec![
                ContentItem::InputText {
                    text: "look at this".to_string(),
                },
                ContentItem::InputImage {
                    image_url: format!("data:image/png;base64,{huge}"),
                },
            ],
            end_turn: None,
        }];

        let prepared = prepare_piece(&piece, TruncationPolicy::Tokens(100_000));

        let sent = serde_json::to_string(&prepared).expect("serialise");
        assert!(
            !sent.contains(&huge),
            "the base64 must not be sent to be summarised"
        );
        assert!(
            sent.contains("an image was shared here"),
            "but say one was there"
        );
        assert!(
            sent.contains("look at this"),
            "and keep the words around it"
        );
    }

    #[test]
    fn should_not_send_a_call_whose_answer_is_in_another_piece() {
        // The cut falls where the budget runs out, which is not where a tool
        // call ends. A call with no answer is not a conversation a model will
        // take, and the request failed and was retried eight times.
        let call = ResponseItem::FunctionCall {
            name: "run".to_string(),
            arguments: r#"{"command":["ls"]}"#.to_string(),
            call_id: "c1".to_string(),
            id: None,
        };
        let piece = vec![said("before the call"), call];

        let prepared = prepare_piece(&piece, TruncationPolicy::Tokens(100_000));

        let calls = prepared
            .iter()
            .filter(|item| matches!(item, ResponseItem::FunctionCall { .. }))
            .count();
        let answers = prepared
            .iter()
            .filter(|item| matches!(item, ResponseItem::FunctionCallOutput { .. }))
            .count();
        assert_eq!(
            calls, answers,
            "every call in a piece must have an answer in it"
        );
    }

    #[test]
    fn should_cut_a_long_conversation_into_pieces_that_each_fit() {
        // Every piece has to be readable on its own, or summarising it fails
        // for the same reason summarising the whole thing did.
        let items: Vec<ResponseItem> = (0..60).map(|_| said(&"word ".repeat(300))).collect();
        let budget = 2_000;

        let pieces = split_into_pieces(&items, budget, TruncationPolicy::Tokens(100_000));

        assert!(
            pieces.len() > 1,
            "a conversation this long has to be cut up"
        );
        for piece in &pieces {
            let mut measured = ContextManager::new();
            measured.record_items(piece.iter(), TruncationPolicy::Tokens(100_000));
            assert!(
                measured.estimated_token_usage() <= budget || piece.len() == 1,
                "a piece must fit, unless it is a single item that cannot be split"
            );
        }
    }

    #[test]
    fn should_keep_every_message_across_the_pieces() {
        // The whole point: cutting up is not throwing away.
        let items: Vec<ResponseItem> = (0..30).map(|at| said(&format!("message {at} "))).collect();

        let pieces = split_into_pieces(&items, 50, TruncationPolicy::Tokens(100_000));
        let kept: usize = pieces.iter().map(Vec::len).sum();

        assert_eq!(
            kept,
            items.len(),
            "every message must land in exactly one piece"
        );
    }

    #[test]
    fn should_leave_a_short_conversation_in_one_piece() {
        let items = vec![said("hello"), said("there")];
        let pieces = split_into_pieces(&items, 100_000, TruncationPolicy::Tokens(100_000));
        assert_eq!(pieces.len(), 1);
    }

    #[test]
    fn content_items_to_text_joins_non_empty_segments() {
        let items = vec![
            ContentItem::InputText {
                text: "hello".to_string(),
            },
            ContentItem::OutputText {
                text: String::new(),
            },
            ContentItem::OutputText {
                text: "world".to_string(),
            },
        ];

        let joined = content_items_to_text(&items);

        assert_eq!(Some("hello\nworld".to_string()), joined);
    }

    #[test]
    fn content_items_to_text_ignores_image_only_content() {
        let items = vec![ContentItem::InputImage {
            image_url: "file://image.png".to_string(),
        }];

        let joined = content_items_to_text(&items);

        assert_eq!(None, joined);
    }

    #[test]
    fn collect_user_messages_extracts_user_text_only() {
        let items = vec![
            ResponseItem::Message {
                id: Some("assistant".to_string()),
                role: "assistant".to_string(),
                content: vec![ContentItem::OutputText {
                    text: "ignored".to_string(),
                }],
                end_turn: None,
            },
            ResponseItem::Message {
                id: Some("user".to_string()),
                role: "user".to_string(),
                content: vec![ContentItem::InputText {
                    text: "first".to_string(),
                }],
                end_turn: None,
            },
            ResponseItem::Other,
        ];

        let collected = collect_user_messages(&items);

        assert_eq!(vec!["first".to_string()], collected);
    }

    #[test]
    fn collect_user_messages_filters_session_prefix_entries() {
        let items = vec![
            ResponseItem::Message {
                id: None,
                role: "user".to_string(),
                content: vec![ContentItem::InputText {
                    text: "# AGENTS.md instructions for project\n\n<INSTRUCTIONS>\ndo things\n</INSTRUCTIONS>"
                        .to_string(),
                }],
                end_turn: None,
            },
            ResponseItem::Message {
                id: None,
                role: "user".to_string(),
                content: vec![ContentItem::InputText {
                    text: "<ENVIRONMENT_CONTEXT>cwd=/tmp</ENVIRONMENT_CONTEXT>".to_string(),
                }],
                end_turn: None,
            },
            ResponseItem::Message {
                id: None,
                role: "user".to_string(),
                content: vec![ContentItem::InputText {
                    text: "real user message".to_string(),
                }],
                end_turn: None,
            },
        ];

        let collected = collect_user_messages(&items);

        assert_eq!(vec!["real user message".to_string()], collected);
    }

    #[test]
    fn build_token_limited_compacted_history_truncates_overlong_user_messages() {
        // Use a small truncation limit so the test remains fast while still validating
        // that oversized user content is truncated.
        let max_tokens = 16;
        let big = "word ".repeat(200);
        let history = super::build_compacted_history_with_limit(
            Vec::new(),
            std::slice::from_ref(&big),
            "SUMMARY",
            max_tokens,
        );
        assert_eq!(history.len(), 2);

        let truncated_message = &history[0];
        let summary_message = &history[1];

        let truncated_text = match truncated_message {
            ResponseItem::Message { role, content, .. } if role == "user" => {
                content_items_to_text(content).unwrap_or_default()
            }
            other => panic!("unexpected item in history: {other:?}"),
        };

        assert!(
            truncated_text.contains("tokens truncated"),
            "expected truncation marker in truncated user message"
        );
        assert!(
            !truncated_text.contains(&big),
            "truncated user message should not include the full oversized user text"
        );

        let summary_text = match summary_message {
            ResponseItem::Message { role, content, .. } if role == "user" => {
                content_items_to_text(content).unwrap_or_default()
            }
            other => panic!("unexpected item in history: {other:?}"),
        };
        assert_eq!(summary_text, "SUMMARY");
    }

    #[test]
    fn build_token_limited_compacted_history_appends_summary_message() {
        let initial_context: Vec<ResponseItem> = Vec::new();
        let user_messages = vec!["first user message".to_string()];
        let summary_text = "summary text";

        let history = build_compacted_history(initial_context, &user_messages, summary_text);
        assert!(
            !history.is_empty(),
            "expected compacted history to include summary"
        );

        let last = history.last().expect("history should have a summary entry");
        let summary = match last {
            ResponseItem::Message { role, content, .. } if role == "user" => {
                content_items_to_text(content).unwrap_or_default()
            }
            other => panic!("expected summary message, found {other:?}"),
        };
        assert_eq!(summary, summary_text);
    }

    #[test]
    fn build_compacted_history_preserves_turn_aborted_markers() {
        let marker = format!(
            "{TURN_ABORTED_OPEN_TAG}\n  <turn_id>turn-1</turn_id>\n  <reason>interrupted</reason>\n</turn_aborted>"
        );
        let items = vec![
            ResponseItem::Message {
                id: None,
                role: "user".to_string(),
                content: vec![ContentItem::InputText {
                    text: marker.clone(),
                }],
                end_turn: None,
            },
            ResponseItem::Message {
                id: None,
                role: "user".to_string(),
                content: vec![ContentItem::InputText {
                    text: "real user message".to_string(),
                }],
                end_turn: None,
            },
        ];

        let user_messages = collect_user_messages(&items);
        let history = build_compacted_history(Vec::new(), &user_messages, "SUMMARY");

        let found_marker = history.iter().any(|item| match item {
            ResponseItem::Message { role, content, .. } if role == "user" => {
                content_items_to_text(content).is_some_and(|text| text == marker)
            }
            _ => false,
        });
        assert!(
            found_marker,
            "expected compacted history to retain <turn_aborted> marker"
        );
    }
}
