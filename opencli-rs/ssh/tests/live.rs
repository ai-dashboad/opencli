//! Live checks against a real server.
//!
//! Skipped unless `OPENCLI_SSH_TEST_ALIAS` names a host in `~/.ssh/config`.
//! A client for reaching servers that has only ever been run against a mock is
//! a client nobody should trust with a server.

use opencli_ssh::client;
use opencli_ssh::config;

fn alias() -> Option<String> {
    std::env::var("OPENCLI_SSH_TEST_ALIAS")
        .ok()
        .filter(|a| !a.is_empty())
}

#[tokio::test]
async fn should_run_a_command_on_a_real_server() {
    let Some(alias) = alias() else { return };
    let settings = config::resolve(&alias).expect("the alias is in ~/.ssh/config");
    let user = settings.user.clone().expect("the config names a user");

    let session = client::connect(&settings, &user, client::TrustPolicy::Ask)
        .await
        .expect("connects with a recorded host key and an available key");

    let output = session.exec("echo hello-from-opencli").await.expect("runs");
    assert!(
        output.succeeded(),
        "exit {} / {}",
        output.exit_code,
        output.stderr
    );
    assert_eq!(output.stdout.trim(), "hello-from-opencli");

    // A failing command must report its status, not be mistaken for success.
    let failed = session.exec("exit 7").await.expect("runs");
    assert_eq!(failed.exit_code, 7);
    assert!(!failed.succeeded());

    // stderr must not be mixed into stdout; a caller parsing output would
    // otherwise read a warning as data.
    let mixed = session.exec("echo out; echo err >&2").await.expect("runs");
    assert_eq!(mixed.stdout.trim(), "out");
    assert_eq!(mixed.stderr.trim(), "err");

    session.close().await;
}

#[tokio::test]
async fn should_refuse_a_host_it_has_no_record_of() {
    // Trusting an unrecorded key silently is the failure this whole module
    // exists to prevent, so it is checked against a real handshake.
    let Some(alias) = alias() else { return };
    let mut settings = config::resolve(&alias).expect("the alias is in ~/.ssh/config");
    // Same machine, an address no known_hosts entry names.
    settings.hostname = format!("{}.", settings.hostname);

    let user = settings.user.clone().unwrap_or_else(|| "root".into());
    match client::connect(&settings, &user, client::TrustPolicy::Ask).await {
        Err(client::Failure::UnknownHost { fingerprint }) => {
            assert!(
                !fingerprint.is_empty(),
                "the user must see what they are trusting"
            );
        }
        Err(client::Failure::Unreachable(_)) => {
            // The trailing dot may not resolve everywhere; that is not a
            // failure of the check being tested.
        }
        Err(other) => panic!("unexpected failure: {other}"),
        Ok(_) => panic!("an unrecorded host key must not be accepted silently"),
    }
}
