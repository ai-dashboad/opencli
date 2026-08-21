use crate::agent::AgentStatus;
use crate::opencli::OpenCLI;
use crate::error::Result as OpenCLIResult;
use crate::protocol::Event;
use crate::protocol::Op;
use crate::protocol::Submission;
use opencli_protocol::config_types::Personality;
use opencli_protocol::openai_models::ReasoningEffort;
use opencli_protocol::protocol::AskForApproval;
use opencli_protocol::protocol::SandboxPolicy;
use opencli_protocol::protocol::SessionSource;
use std::path::PathBuf;
use tokio::sync::watch;

use crate::state_db::StateDbHandle;

#[derive(Clone, Debug)]
pub struct ThreadConfigSnapshot {
    pub model: String,
    pub model_provider_id: String,
    pub approval_policy: AskForApproval,
    pub sandbox_policy: SandboxPolicy,
    pub cwd: PathBuf,
    pub reasoning_effort: Option<ReasoningEffort>,
    pub personality: Option<Personality>,
    pub session_source: SessionSource,
}

pub struct OpenCLIThread {
    opencli: OpenCLI,
    rollout_path: Option<PathBuf>,
}

/// Conduit for the bidirectional stream of messages that compose a thread
/// (formerly called a conversation) in OpenCLI.
impl OpenCLIThread {
    pub(crate) fn new(opencli: OpenCLI, rollout_path: Option<PathBuf>) -> Self {
        Self {
            opencli,
            rollout_path,
        }
    }

    pub async fn submit(&self, op: Op) -> OpenCLIResult<String> {
        self.opencli.submit(op).await
    }

    /// Use sparingly: this is intended to be removed soon.
    pub async fn submit_with_id(&self, sub: Submission) -> OpenCLIResult<()> {
        self.opencli.submit_with_id(sub).await
    }

    pub async fn next_event(&self) -> OpenCLIResult<Event> {
        self.opencli.next_event().await
    }

    pub async fn agent_status(&self) -> AgentStatus {
        self.opencli.agent_status().await
    }

    pub(crate) fn subscribe_status(&self) -> watch::Receiver<AgentStatus> {
        self.opencli.agent_status.clone()
    }

    pub fn rollout_path(&self) -> Option<PathBuf> {
        self.rollout_path.clone()
    }

    pub fn state_db(&self) -> Option<StateDbHandle> {
        self.opencli.state_db()
    }

    pub async fn config_snapshot(&self) -> ThreadConfigSnapshot {
        self.opencli.thread_config_snapshot().await
    }
}
