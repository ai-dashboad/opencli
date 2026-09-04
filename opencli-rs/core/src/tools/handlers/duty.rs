//! The two things a bot on duty has to be able to do: write down where it got
//! to, and stop to ask.
//!
//! Without these the duty store is a filing cabinet nobody can reach. The
//! notes, the rules and the stopping condition all travel out in the brief,
//! and nothing comes back — so a duty asked every morning to chase overdue
//! invoices chases the same ones every morning, and a threshold it is told to
//! stop at is a sentence it can only obey by giving up.
//!
//! **Which duty is running is not the model's to say.** It comes from the
//! environment of the process the duty was queued into, so a wrong or invented
//! id cannot write notes into another department's duty or answer a question
//! nobody asked. A model that has no duty around it simply does not get these
//! tools.

use crate::client_common::tools::ResponsesApiTool;
use crate::client_common::tools::ToolSpec;
use crate::function_tool::FunctionCallError;
use crate::tools::context::ToolInvocation;
use crate::tools::context::ToolOutput;
use crate::tools::context::ToolPayload;
use crate::tools::registry::ToolHandler;
use crate::tools::registry::ToolKind;
use crate::tools::spec::JsonSchema;
use async_trait::async_trait;
use serde::Deserialize;
use std::collections::BTreeMap;
use std::sync::LazyLock;

pub static REMEMBER_TOOL: LazyLock<ToolSpec> = LazyLock::new(|| {
    let mut properties = BTreeMap::new();
    properties.insert(
        "notes".to_string(),
        JsonSchema::Object {
            properties: BTreeMap::new(),
            required: None,
            // The keys are the duty's own, so they cannot be enumerated here.
            // What has to be carried differs for every duty, and a schema
            // would only be the wrong schema.
            additional_properties: Some(true.into()),
        },
    );

    ToolSpec::Function(ResponsesApiTool {
        name: "duty_remember".to_string(),
        description: "Write down what the next run of this duty needs to know, as short \
                      key/value notes — how far you got, what you have already handled. \
                      Merged with what is already recorded, so send only what changed; \
                      an empty value forgets a note. Call this before you finish, or the \
                      next run starts over."
            .to_string(),
        strict: false,
        parameters: JsonSchema::Object {
            properties,
            required: Some(vec!["notes".to_string()]),
            additional_properties: Some(false.into()),
        },
    })
});

pub static ASK_TOOL: LazyLock<ToolSpec> = LazyLock::new(|| {
    let mut properties = BTreeMap::new();
    properties.insert(
        "question".to_string(),
        JsonSchema::String {
            description: Some("What you need decided, in one sentence.".to_string()),
        },
    );
    properties.insert(
        "context".to_string(),
        JsonSchema::String {
            description: Some(
                "What you found, so the question can be answered without reading the \
                 whole run."
                    .to_string(),
            ),
        },
    );

    ToolSpec::Function(ResponsesApiTool {
        name: "duty_ask".to_string(),
        description: "Stop and put a question to the person who set this duty, when the \
                      rules say to escalate rather than decide. The answer may not come \
                      for hours; record what you have done with duty_remember first, then \
                      finish the run. You will be given the answer at the start of the \
                      next one."
            .to_string(),
        strict: false,
        parameters: JsonSchema::Object {
            properties,
            required: Some(vec!["question".to_string()]),
            additional_properties: Some(false.into()),
        },
    })
});

#[derive(Debug, Deserialize)]
struct RememberArgs {
    notes: BTreeMap<String, serde_json::Value>,
}

#[derive(Debug, Deserialize)]
struct AskArgs {
    question: String,
    #[serde(default)]
    context: String,
}

/// Notes may arrive as numbers or booleans; they are stored as what they read
/// as, since the next run gets them as text in its brief either way.
fn as_text(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::String(text) => text.clone(),
        serde_json::Value::Null => String::new(),
        other => other.to_string(),
    }
}

pub struct DutyHandler;

#[async_trait]
impl ToolHandler for DutyHandler {
    fn kind(&self) -> ToolKind {
        ToolKind::Function
    }

    async fn handle(&self, invocation: ToolInvocation) -> Result<ToolOutput, FunctionCallError> {
        let ToolInvocation {
            session,
            tool_name,
            payload,
            ..
        } = invocation;

        let ToolPayload::Function { arguments } = payload else {
            return Err(FunctionCallError::RespondToModel(
                "duty tools take function arguments".to_string(),
            ));
        };

        // Told rather than asked. A model that guessed an id could write into
        // a duty in another department.
        let Some(duty) = crate::duties::current() else {
            return Err(FunctionCallError::RespondToModel(
                "this is not a duty run, so there is nothing to record against".to_string(),
            ));
        };
        let home = session.opencli_home().await;

        let content = match tool_name.as_str() {
            "duty_remember" => remember(&home, &duty, &arguments)?,
            "duty_ask" => ask(&home, &duty, &arguments)?,
            other => {
                return Err(FunctionCallError::RespondToModel(format!(
                    "`{other}` is not a duty tool"
                )));
            }
        };

        Ok(ToolOutput::Function {
            content,
            content_items: None,
            success: Some(true),
        })
    }
}

fn remember(
    home: &std::path::Path,
    duty: &str,
    arguments: &str,
) -> Result<String, FunctionCallError> {
    let args: RememberArgs = serde_json::from_str(arguments).map_err(|err| {
        FunctionCallError::RespondToModel(format!("could not read the notes: {err}"))
    })?;
    let entries: BTreeMap<String, String> = args
        .notes
        .iter()
        .map(|(key, value)| (key.clone(), as_text(value)))
        .collect();
    let kept = entries.len();

    crate::duties::remember(home, duty, entries).map_err(|err| {
        FunctionCallError::RespondToModel(format!("could not write the notes down: {err}"))
    })?;
    Ok(format!(
        "Noted. {kept} entr{} will be given to the next run.",
        if kept == 1 { "y" } else { "ies" }
    ))
}

fn ask(home: &std::path::Path, duty: &str, arguments: &str) -> Result<String, FunctionCallError> {
    let args: AskArgs = serde_json::from_str(arguments).map_err(|err| {
        FunctionCallError::RespondToModel(format!("could not read the question: {err}"))
    })?;

    let stored = crate::duties::get(home, duty);
    let bot = stored.map(|duty| duty.bot).unwrap_or_default();
    let escalation = crate::duties::ask(
        home,
        duty.to_string(),
        bot,
        args.question.clone(),
        args.context,
    )
    .map_err(|err| {
        FunctionCallError::RespondToModel(format!("could not put the question on file: {err}"))
    })?;

    // Said plainly, because the next thing the model does decides whether the
    // duty stops or carries on regardless of its own rules.
    if escalation.question != args.question {
        return Ok(format!(
            "You already have a question waiting on this duty: \"{}\". It has not been \
             answered yet, so this one was not added. Finish the run.",
            escalation.question
        ));
    }
    Ok(
        "Asked. This duty will not run again until it is answered, and you will be given \
        the answer at the start of the next run. Finish the run now."
            .to_string(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    fn a_duty(home: &std::path::Path) -> String {
        crate::duties::create(
            home,
            "bot-1".to_string(),
            "Reconcile".to_string(),
            "match the ledger".to_string(),
            3600,
        )
        .expect("create")
        .id
    }

    #[test]
    fn should_write_notes_the_next_run_will_be_given() {
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());

        let said = remember(
            dir.path(),
            &duty,
            r#"{"notes":{"reconciled_to":"txn-4821"}}"#,
        )
        .expect("remember");

        assert!(said.contains('1'), "got: {said}");
        assert_eq!(
            crate::duties::state(dir.path(), &duty)
                .entries
                .get("reconciled_to"),
            Some(&"txn-4821".to_string())
        );
    }

    #[test]
    fn should_take_a_note_that_is_not_a_string() {
        // Models write numbers as numbers. Refusing would make the tool fail
        // on the most ordinary thing a duty has to remember: how many.
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());

        remember(dir.path(), &duty, r#"{"notes":{"handled":42,"done":true}}"#).expect("remember");

        let state = crate::duties::state(dir.path(), &duty);
        assert_eq!(state.entries.get("handled"), Some(&"42".to_string()));
        assert_eq!(state.entries.get("done"), Some(&"true".to_string()));
    }

    #[test]
    fn should_file_a_question_and_tell_the_bot_to_stop() {
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());

        let said = ask(
            dir.path(),
            &duty,
            r#"{"question":"Refund 3800?","context":"invoice 22"}"#,
        )
        .expect("ask");

        assert!(said.contains("Finish the run"), "got: {said}");
        assert!(crate::duties::is_blocked(dir.path(), &duty));
    }

    #[test]
    fn should_say_so_rather_than_filing_a_second_question() {
        // The store returns the question already open. Without being told, a
        // bot would believe its new question had been asked.
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        ask(dir.path(), &duty, r#"{"question":"Refund 3800?"}"#).expect("first");

        let said = ask(dir.path(), &duty, r#"{"question":"Something else?"}"#).expect("second");

        assert!(said.contains("already have a question"), "got: {said}");
        assert!(said.contains("Refund 3800?"), "got: {said}");
        assert_eq!(crate::duties::open_escalations(dir.path()).len(), 1);
    }

    #[test]
    fn should_reject_notes_that_are_not_notes() {
        let dir = tempdir().expect("tempdir");
        let duty = a_duty(dir.path());
        assert!(remember(dir.path(), &duty, r#"{"notes":"everything"}"#).is_err());
    }
}
