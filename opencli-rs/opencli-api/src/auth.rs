use crate::provider::WireApi;
use opencli_client::Request;

/// Provides bearer and account identity information for API requests.
///
/// Implementations should be cheap and non-blocking; any asynchronous
/// refresh or I/O should be handled by higher layers before requests
/// reach this interface.
pub trait AuthProvider: Send + Sync {
    fn bearer_token(&self) -> Option<String>;
    fn account_id(&self) -> Option<String> {
        None
    }
}

pub(crate) fn add_auth_headers<A: AuthProvider>(
    auth: &A,
    mut req: Request,
    wire: &WireApi,
) -> Request {
    // Anthropic does not accept a bearer token: the key goes in `x-api-key`,
    // and sending `Authorization` instead is rejected as unauthenticated.
    if let WireApi::Anthropic = wire {
        if let Some(token) = auth.bearer_token()
            && let Ok(header) = token.parse()
        {
            let _ = req.headers.insert("x-api-key", header);
        }
        return req;
    }
    if let Some(token) = auth.bearer_token()
        && let Ok(header) = format!("Bearer {token}").parse()
    {
        let _ = req.headers.insert(http::header::AUTHORIZATION, header);
    }
    if let Some(account_id) = auth.account_id()
        && let Ok(header) = account_id.parse()
    {
        let _ = req.headers.insert("ChatGPT-Account-ID", header);
    }
    req
}
