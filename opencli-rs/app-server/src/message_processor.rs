use std::path::PathBuf;
use std::sync::Arc;

use crate::config_api::ConfigApi;
use crate::error_code::INVALID_REQUEST_ERROR_CODE;
use crate::opencli_message_processor::OpenCLIMessageProcessor;
use crate::opencli_message_processor::OpenCLIMessageProcessorArgs;
use crate::outgoing_message::OutgoingMessageSender;
use async_trait::async_trait;
use opencli_app_server_protocol::ChatgptAuthTokensRefreshParams;
use opencli_app_server_protocol::ChatgptAuthTokensRefreshReason;
use opencli_app_server_protocol::ChatgptAuthTokensRefreshResponse;
use opencli_app_server_protocol::ClientInfo;
use opencli_app_server_protocol::ClientRequest;
use opencli_app_server_protocol::ConfigBatchWriteParams;
use opencli_app_server_protocol::ConfigReadParams;
use opencli_app_server_protocol::ConfigValueWriteParams;
use opencli_app_server_protocol::ConfigWarningNotification;
use opencli_app_server_protocol::InitializeResponse;
use opencli_app_server_protocol::JSONRPCError;
use opencli_app_server_protocol::JSONRPCErrorError;
use opencli_app_server_protocol::JSONRPCNotification;
use opencli_app_server_protocol::JSONRPCRequest;
use opencli_app_server_protocol::JSONRPCResponse;
use opencli_app_server_protocol::RequestId;
use opencli_app_server_protocol::ServerNotification;
use opencli_app_server_protocol::ServerRequestPayload;
use opencli_core::AuthManager;
use opencli_core::ThreadManager;
use opencli_core::auth::ExternalAuthRefreshContext;
use opencli_core::auth::ExternalAuthRefreshReason;
use opencli_core::auth::ExternalAuthRefresher;
use opencli_core::auth::ExternalAuthTokens;
use opencli_core::config::Config;
use opencli_core::config_loader::CloudRequirementsLoader;
use opencli_core::config_loader::LoaderOverrides;
use opencli_core::default_client::SetOriginatorError;
use opencli_core::default_client::USER_AGENT_SUFFIX;
use opencli_core::default_client::get_opencli_user_agent;
use opencli_core::default_client::set_default_client_residency_requirement;
use opencli_core::default_client::set_default_originator;
use opencli_feedback::OpenCLIFeedback;
use opencli_protocol::ThreadId;
use opencli_protocol::protocol::SessionSource;
use tokio::sync::broadcast;
use tokio::time::Duration;
use tokio::time::timeout;
use toml::Value as TomlValue;

const EXTERNAL_AUTH_REFRESH_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Clone)]
struct ExternalAuthRefreshBridge {
    outgoing: Arc<OutgoingMessageSender>,
}

impl ExternalAuthRefreshBridge {
    fn map_reason(reason: ExternalAuthRefreshReason) -> ChatgptAuthTokensRefreshReason {
        match reason {
            ExternalAuthRefreshReason::Unauthorized => ChatgptAuthTokensRefreshReason::Unauthorized,
        }
    }
}

#[async_trait]
impl ExternalAuthRefresher for ExternalAuthRefreshBridge {
    async fn refresh(
        &self,
        context: ExternalAuthRefreshContext,
    ) -> std::io::Result<ExternalAuthTokens> {
        let params = ChatgptAuthTokensRefreshParams {
            reason: Self::map_reason(context.reason),
            previous_account_id: context.previous_account_id,
        };

        let (request_id, rx) = self
            .outgoing
            .send_request_with_id(ServerRequestPayload::ChatgptAuthTokensRefresh(params))
            .await;

        let result = match timeout(EXTERNAL_AUTH_REFRESH_TIMEOUT, rx).await {
            Ok(result) => result.map_err(|err| {
                std::io::Error::other(format!("auth refresh request canceled: {err}"))
            })?,
            Err(_) => {
                let _canceled = self.outgoing.cancel_request(&request_id).await;
                return Err(std::io::Error::other(format!(
                    "auth refresh request timed out after {}s",
                    EXTERNAL_AUTH_REFRESH_TIMEOUT.as_secs()
                )));
            }
        };

        let response: ChatgptAuthTokensRefreshResponse =
            serde_json::from_value(result).map_err(std::io::Error::other)?;

        Ok(ExternalAuthTokens {
            access_token: response.access_token,
            id_token: response.id_token,
        })
    }
}

pub(crate) struct MessageProcessor {
    outgoing: Arc<OutgoingMessageSender>,
    opencli_message_processor: OpenCLIMessageProcessor,
    config_api: ConfigApi,
    config: Arc<Config>,
    initialized: bool,
    config_warnings: Vec<ConfigWarningNotification>,
}

pub(crate) struct MessageProcessorArgs {
    pub(crate) outgoing: OutgoingMessageSender,
    pub(crate) opencli_linux_sandbox_exe: Option<PathBuf>,
    pub(crate) config: Arc<Config>,
    pub(crate) cli_overrides: Vec<(String, TomlValue)>,
    pub(crate) loader_overrides: LoaderOverrides,
    pub(crate) cloud_requirements: CloudRequirementsLoader,
    pub(crate) feedback: OpenCLIFeedback,
    pub(crate) config_warnings: Vec<ConfigWarningNotification>,
}

impl MessageProcessor {
    /// Create a new `MessageProcessor`, retaining a handle to the outgoing
    /// `Sender` so handlers can enqueue messages to be written to stdout.
    pub(crate) fn new(args: MessageProcessorArgs) -> Self {
        let MessageProcessorArgs {
            outgoing,
            opencli_linux_sandbox_exe,
            config,
            cli_overrides,
            loader_overrides,
            cloud_requirements,
            feedback,
            config_warnings,
        } = args;
        let outgoing = Arc::new(outgoing);
        let auth_manager = AuthManager::shared(
            config.opencli_home.clone(),
            false,
            config.cli_auth_credentials_store_mode,
        );
        auth_manager.set_forced_chatgpt_workspace_id(config.forced_chatgpt_workspace_id.clone());
        auth_manager.set_external_auth_refresher(Arc::new(ExternalAuthRefreshBridge {
            outgoing: outgoing.clone(),
        }));
        let thread_manager = Arc::new(ThreadManager::new(
            config.opencli_home.clone(),
            auth_manager.clone(),
            SessionSource::VSCode,
        ));
        let opencli_message_processor = OpenCLIMessageProcessor::new(OpenCLIMessageProcessorArgs {
            auth_manager,
            thread_manager,
            outgoing: outgoing.clone(),
            opencli_linux_sandbox_exe,
            config: Arc::clone(&config),
            cli_overrides: cli_overrides.clone(),
            cloud_requirements: cloud_requirements.clone(),
            feedback,
        });
        let config_api = ConfigApi::new(
            config.opencli_home.clone(),
            cli_overrides,
            loader_overrides,
            cloud_requirements,
        );

        Self {
            outgoing,
            opencli_message_processor,
            config_api,
            config,
            initialized: false,
            config_warnings,
        }
    }

    pub(crate) async fn process_request(&mut self, request: JSONRPCRequest) {
        let request_id = request.id.clone();
        let request_json = match serde_json::to_value(&request) {
            Ok(request_json) => request_json,
            Err(err) => {
                let error = JSONRPCErrorError {
                    code: INVALID_REQUEST_ERROR_CODE,
                    message: format!("Invalid request: {err}"),
                    data: None,
                };
                self.outgoing.send_error(request_id, error).await;
                return;
            }
        };

        let opencli_request = match serde_json::from_value::<ClientRequest>(request_json) {
            Ok(opencli_request) => opencli_request,
            Err(err) => {
                let error = JSONRPCErrorError {
                    code: INVALID_REQUEST_ERROR_CODE,
                    message: format!("Invalid request: {err}"),
                    data: None,
                };
                self.outgoing.send_error(request_id, error).await;
                return;
            }
        };

        match opencli_request {
            // Handle Initialize internally so OpenCLIMessageProcessor does not have to concern
            // itself with the `initialized` bool.
            ClientRequest::Initialize { request_id, params } => {
                if self.initialized {
                    let error = JSONRPCErrorError {
                        code: INVALID_REQUEST_ERROR_CODE,
                        message: "Already initialized".to_string(),
                        data: None,
                    };
                    self.outgoing.send_error(request_id, error).await;
                    return;
                } else {
                    let ClientInfo {
                        name,
                        title: _title,
                        version,
                    } = params.client_info;
                    if let Err(error) = set_default_originator(name.clone()) {
                        match error {
                            SetOriginatorError::InvalidHeaderValue => {
                                let error = JSONRPCErrorError {
                                    code: INVALID_REQUEST_ERROR_CODE,
                                    message: format!(
                                        "Invalid clientInfo.name: '{name}'. Must be a valid HTTP header value."
                                    ),
                                    data: None,
                                };
                                self.outgoing.send_error(request_id, error).await;
                                return;
                            }
                            SetOriginatorError::AlreadyInitialized => {
                                // No-op. This is expected to happen if the originator is already set via env var.
                                // TODO(owen): Once we remove support for OPENCLI_INTERNAL_ORIGINATOR_OVERRIDE,
                                // this will be an unexpected state and we can return a JSON-RPC error indicating
                                // internal server error.
                            }
                        }
                    }
                    set_default_client_residency_requirement(self.config.enforce_residency.value());
                    let user_agent_suffix = format!("{name}; {version}");
                    if let Ok(mut suffix) = USER_AGENT_SUFFIX.lock() {
                        *suffix = Some(user_agent_suffix);
                    }

                    let user_agent = get_opencli_user_agent();
                    let response = InitializeResponse { user_agent };
                    self.outgoing.send_response(request_id, response).await;

                    self.initialized = true;
                    if !self.config_warnings.is_empty() {
                        for notification in self.config_warnings.drain(..) {
                            self.outgoing
                                .send_server_notification(ServerNotification::ConfigWarning(
                                    notification,
                                ))
                                .await;
                        }
                    }

                    return;
                }
            }
            _ => {
                if !self.initialized {
                    let error = JSONRPCErrorError {
                        code: INVALID_REQUEST_ERROR_CODE,
                        message: "Not initialized".to_string(),
                        data: None,
                    };
                    self.outgoing.send_error(request_id, error).await;
                    return;
                }
            }
        }

        match opencli_request {
            ClientRequest::ConfigRead { request_id, params } => {
                self.handle_config_read(request_id, params).await;
            }
            ClientRequest::ConfigValueWrite { request_id, params } => {
                self.handle_config_value_write(request_id, params).await;
            }
            ClientRequest::ConfigBatchWrite { request_id, params } => {
                self.handle_config_batch_write(request_id, params).await;
            }
            ClientRequest::ConfigRequirementsRead {
                request_id,
                params: _,
            } => {
                self.handle_config_requirements_read(request_id).await;
            }
            other => {
                self.opencli_message_processor.process_request(other).await;
            }
        }
    }

    pub(crate) async fn process_notification(&self, notification: JSONRPCNotification) {
        // Currently, we do not expect to receive any notifications from the
        // client, so we just log them.
        tracing::info!("<- notification: {:?}", notification);
    }

    pub(crate) fn thread_created_receiver(&self) -> broadcast::Receiver<ThreadId> {
        self.opencli_message_processor.thread_created_receiver()
    }

    pub(crate) async fn try_attach_thread_listener(&mut self, thread_id: ThreadId) {
        if !self.initialized {
            return;
        }
        self.opencli_message_processor
            .try_attach_thread_listener(thread_id)
            .await;
    }

    /// Handle a standalone JSON-RPC response originating from the peer.
    pub(crate) async fn process_response(&mut self, response: JSONRPCResponse) {
        tracing::info!("<- response: {:?}", response);
        let JSONRPCResponse { id, result, .. } = response;
        self.outgoing.notify_client_response(id, result).await
    }

    /// Handle an error object received from the peer.
    pub(crate) async fn process_error(&mut self, err: JSONRPCError) {
        tracing::error!("<- error: {:?}", err);
        self.outgoing.notify_client_error(err.id, err.error).await;
    }

    async fn handle_config_read(&self, request_id: RequestId, params: ConfigReadParams) {
        match self.config_api.read(params).await {
            Ok(response) => self.outgoing.send_response(request_id, response).await,
            Err(error) => self.outgoing.send_error(request_id, error).await,
        }
    }

    async fn handle_config_value_write(
        &self,
        request_id: RequestId,
        params: ConfigValueWriteParams,
    ) {
        match self.config_api.write_value(params).await {
            Ok(response) => self.outgoing.send_response(request_id, response).await,
            Err(error) => self.outgoing.send_error(request_id, error).await,
        }
    }

    async fn handle_config_batch_write(
        &self,
        request_id: RequestId,
        params: ConfigBatchWriteParams,
    ) {
        match self.config_api.batch_write(params).await {
            Ok(response) => self.outgoing.send_response(request_id, response).await,
            Err(error) => self.outgoing.send_error(request_id, error).await,
        }
    }

    async fn handle_config_requirements_read(&self, request_id: RequestId) {
        match self.config_api.config_requirements_read().await {
            Ok(response) => self.outgoing.send_response(request_id, response).await,
            Err(error) => self.outgoing.send_error(request_id, error).await,
        }
    }
}
