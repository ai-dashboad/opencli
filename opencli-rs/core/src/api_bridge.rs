use chrono::DateTime;
use chrono::Utc;
use http::HeaderMap;
use opencli_api::AuthProvider as ApiAuthProvider;
use opencli_api::TransportError;
use opencli_api::error::ApiError;
use opencli_api::rate_limits::parse_promo_message;
use opencli_api::rate_limits::parse_rate_limit;
use serde::Deserialize;

use crate::auth::OpenCLIAuth;
use crate::error::ModelCapError;
use crate::error::OpenCLIErr;
use crate::error::RetryLimitReachedError;
use crate::error::UnexpectedResponseError;
use crate::error::UsageLimitReachedError;
use crate::model_provider_info::ModelProviderInfo;
use crate::token_data::PlanType;

pub(crate) fn map_api_error(err: ApiError) -> OpenCLIErr {
    match err {
        ApiError::ContextWindowExceeded { context_limit } => {
            OpenCLIErr::ContextWindowExceeded { context_limit }
        }
        ApiError::QuotaExceeded => OpenCLIErr::QuotaExceeded,
        ApiError::UsageNotIncluded => OpenCLIErr::UsageNotIncluded,
        ApiError::Retryable { message, delay } => OpenCLIErr::Stream(message, delay),
        ApiError::Stream(msg) => OpenCLIErr::Stream(msg, None),
        ApiError::Api { status, message } => {
            OpenCLIErr::UnexpectedStatus(UnexpectedResponseError {
                status,
                body: message,
                url: None,
                request_id: None,
            })
        }
        ApiError::InvalidRequest { message } => OpenCLIErr::InvalidRequest(message),
        ApiError::Transport(transport) => match transport {
            TransportError::Http {
                status,
                url,
                headers,
                body,
            } => {
                let body_text = body.unwrap_or_default();

                if status == http::StatusCode::BAD_REQUEST {
                    if body_text
                        .contains("The image data you provided does not represent a valid image")
                    {
                        OpenCLIErr::InvalidImageRequest()
                    } else {
                        OpenCLIErr::InvalidRequest(body_text)
                    }
                } else if status == http::StatusCode::INTERNAL_SERVER_ERROR {
                    OpenCLIErr::InternalServerError
                } else if status == http::StatusCode::TOO_MANY_REQUESTS {
                    if let Some(model) = headers
                        .as_ref()
                        .and_then(|map| map.get(MODEL_CAP_MODEL_HEADER))
                        .and_then(|value| value.to_str().ok())
                        .map(str::to_string)
                    {
                        let reset_after_seconds = headers
                            .as_ref()
                            .and_then(|map| map.get(MODEL_CAP_RESET_AFTER_HEADER))
                            .and_then(|value| value.to_str().ok())
                            .and_then(|value| value.parse::<u64>().ok());
                        return OpenCLIErr::ModelCap(ModelCapError {
                            model,
                            reset_after_seconds,
                        });
                    }

                    if let Ok(err) = serde_json::from_str::<UsageErrorResponse>(&body_text) {
                        if err.error.error_type.as_deref() == Some("usage_limit_reached") {
                            let rate_limits = headers.as_ref().and_then(parse_rate_limit);
                            let promo_message = headers.as_ref().and_then(parse_promo_message);
                            let resets_at = err
                                .error
                                .resets_at
                                .and_then(|seconds| DateTime::<Utc>::from_timestamp(seconds, 0));
                            return OpenCLIErr::UsageLimitReached(UsageLimitReachedError {
                                plan_type: err.error.plan_type,
                                resets_at,
                                rate_limits,
                                promo_message,
                            });
                        } else if err.error.error_type.as_deref() == Some("usage_not_included") {
                            return OpenCLIErr::UsageNotIncluded;
                        }
                    }

                    OpenCLIErr::RetryLimit(RetryLimitReachedError {
                        status,
                        request_id: extract_request_id(headers.as_ref()),
                    })
                } else {
                    OpenCLIErr::UnexpectedStatus(UnexpectedResponseError {
                        status,
                        body: body_text,
                        url,
                        request_id: extract_request_id(headers.as_ref()),
                    })
                }
            }
            TransportError::RetryLimit => OpenCLIErr::RetryLimit(RetryLimitReachedError {
                status: http::StatusCode::INTERNAL_SERVER_ERROR,
                request_id: None,
            }),
            TransportError::Timeout => OpenCLIErr::Timeout,
            TransportError::Network(msg) | TransportError::Build(msg) => {
                OpenCLIErr::Stream(msg, None)
            }
        },
        ApiError::RateLimit(msg) => OpenCLIErr::Stream(msg, None),
    }
}

const MODEL_CAP_MODEL_HEADER: &str = "x-opencli-model-cap-model";
const MODEL_CAP_RESET_AFTER_HEADER: &str = "x-opencli-model-cap-reset-after-seconds";

#[cfg(test)]
mod tests {
    use super::*;
    use http::HeaderMap;
    use http::StatusCode;
    use opencli_api::TransportError;

    #[test]
    fn map_api_error_maps_model_cap_headers() {
        let mut headers = HeaderMap::new();
        headers.insert(
            MODEL_CAP_MODEL_HEADER,
            http::HeaderValue::from_static("test-model-alt"),
        );
        headers.insert(
            MODEL_CAP_RESET_AFTER_HEADER,
            http::HeaderValue::from_static("120"),
        );
        let err = map_api_error(ApiError::Transport(TransportError::Http {
            status: StatusCode::TOO_MANY_REQUESTS,
            url: Some("http://example.com/v1/responses".to_string()),
            headers: Some(headers),
            body: Some(String::new()),
        }));

        let OpenCLIErr::ModelCap(model_cap) = err else {
            panic!("expected OpenCLIErr::ModelCap, got {err:?}");
        };
        assert_eq!(model_cap.model, "test-model-alt");
        assert_eq!(model_cap.reset_after_seconds, Some(120));
    }
}

fn extract_request_id(headers: Option<&HeaderMap>) -> Option<String> {
    headers.and_then(|map| {
        ["cf-ray", "x-request-id", "x-oai-request-id"]
            .iter()
            .find_map(|name| {
                map.get(*name)
                    .and_then(|v| v.to_str().ok())
                    .map(str::to_string)
            })
    })
}

pub(crate) fn auth_provider_from_auth(
    auth: Option<OpenCLIAuth>,
    provider: &ModelProviderInfo,
) -> crate::error::Result<CoreAuthProvider> {
    if let Some(api_key) = provider.api_key()? {
        return Ok(CoreAuthProvider {
            token: Some(api_key),
            account_id: None,
        });
    }

    if let Some(token) = provider.experimental_bearer_token.clone() {
        return Ok(CoreAuthProvider {
            token: Some(token),
            account_id: None,
        });
    }

    if let Some(auth) = auth {
        let token = auth.get_token()?;
        Ok(CoreAuthProvider {
            token: Some(token),
            account_id: auth.get_account_id(),
        })
    } else {
        Ok(CoreAuthProvider {
            token: None,
            account_id: None,
        })
    }
}

#[derive(Debug, Deserialize)]
struct UsageErrorResponse {
    error: UsageErrorBody,
}

#[derive(Debug, Deserialize)]
struct UsageErrorBody {
    #[serde(rename = "type")]
    error_type: Option<String>,
    plan_type: Option<PlanType>,
    resets_at: Option<i64>,
}

#[derive(Clone, Default)]
pub(crate) struct CoreAuthProvider {
    token: Option<String>,
    account_id: Option<String>,
}

impl ApiAuthProvider for CoreAuthProvider {
    fn bearer_token(&self) -> Option<String> {
        self.token.clone()
    }

    fn account_id(&self) -> Option<String> {
        self.account_id.clone()
    }
}
