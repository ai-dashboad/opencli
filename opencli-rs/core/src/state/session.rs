//! Session-wide mutable state.

use opencli_protocol::models::ResponseItem;
use std::collections::HashMap;
use std::collections::HashSet;

use crate::context_manager::ContextManager;
use crate::opencli::SessionConfiguration;
use crate::protocol::RateLimitSnapshot;
use crate::protocol::TokenUsage;
use crate::protocol::TokenUsageInfo;
use crate::truncate::TruncationPolicy;

/// What to do about a conversation that has reached its compaction limit.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum CompactionVerdict {
    /// Still inside the limit.
    NotNeeded,
    /// Over it, with a conversation long enough that summarising will shorten
    /// the request.
    Compact,
    /// Over it, but not because of the conversation. `overhead` is what every
    /// request carries regardless — the tool schemas above all.
    WontHelp { overhead: i64 },
}

/// Persistent, session-scoped state previously stored directly on `Session`.
pub(crate) struct SessionState {
    pub(crate) session_configuration: SessionConfiguration,
    pub(crate) history: ContextManager,
    pub(crate) latest_rate_limits: Option<RateLimitSnapshot>,
    pub(crate) server_reasoning_included: bool,
    pub(crate) dependency_env: HashMap<String, String>,
    pub(crate) mcp_dependency_prompted: HashSet<String>,
    /// Whether the session's initial context has been seeded into history.
    ///
    /// TODO(owen): This is a temporary solution to avoid updating a thread's updated_at
    /// timestamp when resuming a session. Remove this once SQLite is in place.
    pub(crate) initial_context_seeded: bool,
    /// Where the last compaction left the count, and whether the reader has
    /// been told that compacting is not what stands between them and a working
    /// conversation. See `SessionState::compaction_verdict`.
    compaction_floor: Option<i64>,
    compaction_futility_reported: bool,
}

impl SessionState {
    /// Create a new session state mirroring previous `State::default()` semantics.
    pub(crate) fn new(session_configuration: SessionConfiguration) -> Self {
        let history = ContextManager::new();
        Self {
            session_configuration,
            history,
            latest_rate_limits: None,
            server_reasoning_included: false,
            dependency_env: HashMap::new(),
            mcp_dependency_prompted: HashSet::new(),
            initial_context_seeded: false,
            compaction_floor: None,
            compaction_futility_reported: false,
        }
    }

    // History helpers
    pub(crate) fn record_items<I>(&mut self, items: I, policy: TruncationPolicy)
    where
        I: IntoIterator,
        I::Item: std::ops::Deref<Target = ResponseItem>,
    {
        self.history.record_items(items, policy);
    }

    pub(crate) fn clone_history(&self) -> ContextManager {
        self.history.clone()
    }

    pub(crate) fn replace_history(&mut self, items: Vec<ResponseItem>) {
        self.history.replace(items);
    }

    pub(crate) fn set_token_info(&mut self, info: Option<TokenUsageInfo>) {
        self.history.set_token_info(info);
    }

    // Token/rate limit helpers
    pub(crate) fn update_token_info_from_usage(
        &mut self,
        usage: &TokenUsage,
        model_context_window: Option<i64>,
    ) {
        self.history.update_token_info(usage, model_context_window);
    }

    pub(crate) fn token_info(&self) -> Option<TokenUsageInfo> {
        self.history.token_info()
    }

    pub(crate) fn set_rate_limits(&mut self, snapshot: RateLimitSnapshot) {
        self.latest_rate_limits = Some(merge_rate_limit_fields(
            self.latest_rate_limits.as_ref(),
            snapshot,
        ));
    }

    pub(crate) fn token_info_and_rate_limits(
        &self,
    ) -> (Option<TokenUsageInfo>, Option<RateLimitSnapshot>) {
        (self.token_info(), self.latest_rate_limits.clone())
    }

    pub(crate) fn set_token_usage_full(&mut self, context_window: i64) {
        self.history.set_token_usage_full(context_window);
    }

    pub(crate) fn get_total_token_usage(&self, server_reasoning_included: bool) -> i64 {
        self.history
            .get_total_token_usage(server_reasoning_included)
    }

    pub(crate) fn learn_request_overhead(&mut self, billed_input: i64, estimated_history: i64) {
        self.history
            .learn_request_overhead(billed_input, estimated_history);
    }

    pub(crate) fn request_overhead(&self) -> i64 {
        self.history.request_overhead()
    }

    /// Remember where a compaction left the count, so the next one can be
    /// judged on whether it has anything left to do.
    pub(crate) fn record_compaction_floor(&mut self, total_tokens: i64) {
        self.compaction_floor = Some(total_tokens);
    }

    /// Whether summarising the conversation now would accomplish anything.
    ///
    /// Being over the limit is not sufficient. A request carries the tool
    /// schemas and the instructions as well as the conversation, and
    /// compaction can only shorten the conversation — so when the fixed part
    /// alone is near the limit, every compaction ends over the limit too, and
    /// the next turn asks for another. That is not hypothetical: it summarised
    /// once a turn for eleven turns straight, each one throwing away the
    /// thread and telling the reader it had helped.
    ///
    /// So the question asked here is not "is it too long" but "has it grown
    /// since the last time this was tried". If it has not, the length is not
    /// coming from the conversation and no amount of summarising will reach
    /// it.
    pub(crate) fn compaction_verdict(&self, total_tokens: i64, limit: i64) -> CompactionVerdict {
        compaction_verdict_for(
            total_tokens,
            limit,
            self.compaction_floor,
            self.request_overhead(),
        )
    }

    /// True the first time, so the explanation is given once rather than every
    /// turn for the rest of a conversation that will keep hitting this.
    pub(crate) fn should_report_compaction_futility(&mut self) -> bool {
        if self.compaction_futility_reported {
            return false;
        }
        self.compaction_futility_reported = true;
        true
    }

    pub(crate) fn set_server_reasoning_included(&mut self, included: bool) {
        self.server_reasoning_included = included;
    }

    pub(crate) fn server_reasoning_included(&self) -> bool {
        self.server_reasoning_included
    }

    pub(crate) fn record_mcp_dependency_prompted<I>(&mut self, names: I)
    where
        I: IntoIterator<Item = String>,
    {
        self.mcp_dependency_prompted.extend(names);
    }

    pub(crate) fn mcp_dependency_prompted(&self) -> HashSet<String> {
        self.mcp_dependency_prompted.clone()
    }

    pub(crate) fn set_dependency_env(&mut self, values: HashMap<String, String>) {
        for (key, value) in values {
            self.dependency_env.insert(key, value);
        }
    }

    pub(crate) fn dependency_env(&self) -> HashMap<String, String> {
        self.dependency_env.clone()
    }
}

fn compaction_verdict_for(
    total_tokens: i64,
    limit: i64,
    compaction_floor: Option<i64>,
    overhead: i64,
) -> CompactionVerdict {
    if total_tokens < limit {
        return CompactionVerdict::NotNeeded;
    }
    let Some(floor) = compaction_floor else {
        return CompactionVerdict::Compact;
    };
    // A tenth of the limit: enough that a compaction earns back more than the
    // request it costs, small enough that a conversation genuinely growing is
    // still summarised well before it stops fitting.
    let minimum_gain = (limit / 10).max(1);
    if total_tokens > floor.saturating_add(minimum_gain) {
        CompactionVerdict::Compact
    } else {
        CompactionVerdict::WontHelp { overhead }
    }
}

// Sometimes new snapshots don't include credits or plan information.
fn merge_rate_limit_fields(
    previous: Option<&RateLimitSnapshot>,
    mut snapshot: RateLimitSnapshot,
) -> RateLimitSnapshot {
    if snapshot.credits.is_none() {
        snapshot.credits = previous.and_then(|prior| prior.credits.clone());
    }
    if snapshot.plan_type.is_none() {
        snapshot.plan_type = previous.and_then(|prior| prior.plan_type);
    }
    snapshot
}

#[cfg(test)]
mod tests {
    use super::CompactionVerdict;
    use super::compaction_verdict_for;

    /// The numbers are the ones from the session that produced this code: a
    /// 31,129-token window, so a 21,790-token compaction limit, and requests
    /// arriving at around 25,000 because the tool schemas of four connectors
    /// travel with each one.
    const LIMIT: i64 = 21_790;

    #[test]
    fn should_not_compact_when_the_conversation_is_within_the_limit() {
        assert_eq!(
            compaction_verdict_for(14_986, LIMIT, None, 10_000),
            CompactionVerdict::NotNeeded
        );
    }

    #[test]
    fn should_compact_when_over_the_limit_and_nothing_has_been_tried_yet() {
        assert_eq!(
            compaction_verdict_for(25_000, LIMIT, None, 0),
            CompactionVerdict::Compact
        );
    }

    #[test]
    fn should_not_compact_again_when_the_last_one_left_it_here() {
        // What happened: compaction ran, the request came back at 25,000 all
        // the same, and the next turn asked for another compaction.
        assert_eq!(
            compaction_verdict_for(25_000, LIMIT, Some(24_800), 10_000),
            CompactionVerdict::WontHelp { overhead: 10_000 }
        );
    }

    #[test]
    fn should_compact_when_the_conversation_has_grown_since_the_last_one() {
        // A tenth of the limit past the floor is a real conversation getting
        // longer, not accounting noise.
        assert_eq!(
            compaction_verdict_for(28_000, LIMIT, Some(24_800), 10_000),
            CompactionVerdict::Compact
        );
    }

    #[test]
    fn should_report_the_overhead_that_compaction_cannot_reach() {
        let CompactionVerdict::WontHelp { overhead } =
            compaction_verdict_for(25_000, LIMIT, Some(24_900), 19_500)
        else {
            panic!("expected the verdict to be that compaction cannot help");
        };
        assert_eq!(overhead, 19_500);
    }
}
