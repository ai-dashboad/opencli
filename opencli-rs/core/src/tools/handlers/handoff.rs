//! Handing work to another bot.
//!
//! The structure is the point. A handoff written as prose has to be
//! interpreted before it can be acted on, and the thing most often lost in the
//! interpreting is which files the next bot is supposed to work on. So the
//! tool asks for three things separately: what you did, what you produced, and
//! what you want done.
//!
//! Refusals come back as answers rather than errors. A bot told "not allowed"
//! can say so and finish; a bot handed a failure often tries again, differently
//! worded, which is the last thing anyone wants from something that starts
//! background runs.

use crate::client_common::tools::ResponsesApiTool;
use crate::client_common::tools::ToolSpec;
use crate::dispatch;
use crate::function_tool::FunctionCallError;
use crate::handoffs;
use crate::projects;
use crate::tools::context::ToolInvocation;
use crate::tools::context::ToolOutput;
use crate::tools::context::ToolPayload;
use crate::tools::registry::ToolHandler;
use crate::tools::registry::ToolKind;
use crate::tools::spec::JsonSchema;
use async_trait::async_trait;
use serde::Deserialize;
use std::collections::BTreeMap;
use std::path::Path;
use std::sync::LazyLock;

pub static HANDOFF_TOOL: LazyLock<ToolSpec> = LazyLock::new(|| {
    let mut properties = BTreeMap::new();
    properties.insert(
        "to".to_string(),
        JsonSchema::String {
            description: Some(
                "Who to hand it to: `name` for someone in your own department, or \
                 `department/name` for someone else's."
                    .to_string(),
            ),
        },
    );
    properties.insert(
        "did".to_string(),
        JsonSchema::String {
            description: Some("What you did, so they are not guessing.".to_string()),
        },
    );
    properties.insert(
        "artifacts".to_string(),
        JsonSchema::Array {
            items: Box::new(JsonSchema::String { description: None }),
            description: Some(
                "Paths to what you produced. This is what they will work on, so name the \
                 files rather than describing them."
                    .to_string(),
            ),
        },
    );
    properties.insert(
        "next".to_string(),
        JsonSchema::String {
            description: Some("What you are asking them to do.".to_string()),
        },
    );

    ToolSpec::Function(ResponsesApiTool {
        name: "bot_handoff".to_string(),
        description: "Hand this work to another bot, who will pick it up in their own \
                      department as a background run. Use it when the rest of the job \
                      belongs to somebody else, not to get a second opinion. They start \
                      cold and see only what you send here."
            .to_string(),
        strict: false,
        parameters: JsonSchema::Object {
            properties,
            required: Some(vec![
                "to".to_string(),
                "did".to_string(),
                "next".to_string(),
            ]),
            additional_properties: Some(false.into()),
        },
    })
});

#[derive(Debug, Deserialize)]
struct HandoffArgs {
    to: String,
    did: String,
    #[serde(default)]
    artifacts: Vec<String>,
    next: String,
}

pub struct HandoffHandler;

#[async_trait]
impl ToolHandler for HandoffHandler {
    fn kind(&self) -> ToolKind {
        ToolKind::Function
    }

    async fn handle(&self, invocation: ToolInvocation) -> Result<ToolOutput, FunctionCallError> {
        let ToolInvocation {
            session, payload, ..
        } = invocation;

        let ToolPayload::Function { arguments } = payload else {
            return Err(FunctionCallError::RespondToModel(
                "bot_handoff takes function arguments".to_string(),
            ));
        };
        let home = session.opencli_home().await;
        let Some((from, chain, hop)) = standing(&home) else {
            return Err(FunctionCallError::RespondToModel(
                "you are not working as a bot, so there is nobody to hand work on from".to_string(),
            ));
        };

        Ok(ToolOutput::Function {
            content: hand_over(&home, &arguments, &from, chain.as_deref(), hop)?,
            content_items: None,
            success: Some(true),
        })
    }
}

/// Where this run stands: who it is working as, and how deep a chain it is in.
///
/// Read at the edge and passed inwards. Reading the environment further down
/// would put a process-wide global in the middle of the logic, and the tests
/// that had to set it made every other test reading it flaky — one arrived
/// that way once and passed on the next run, which is worse than failing.
fn standing(home: &Path) -> Option<(crate::bots::Bot, Option<String>, u32)> {
    let from = crate::bots::current(home)?;
    let (chain, hop) = match handoffs::current_chain() {
        Some((chain, hop)) => (Some(chain), hop),
        None => (None, 0),
    };
    Some((from, chain, hop))
}

fn hand_over(
    home: &Path,
    arguments: &str,
    from: &crate::bots::Bot,
    chain_id: Option<&str>,
    hop: u32,
) -> Result<String, FunctionCallError> {
    let args: HandoffArgs = serde_json::from_str(arguments).map_err(|err| {
        FunctionCallError::RespondToModel(format!("could not read the handoff: {err}"))
    })?;

    let to = match handoffs::may_hand_over(home, from, &args.to, chain_id, hop) {
        Ok(to) => to,
        // Answered, not raised. A bot handed a failure tries again differently
        // worded, which is the last thing wanted from something that starts
        // background runs.
        Err(refusal) => return Ok(format!("That handoff was refused: {refusal}")),
    };

    let department = projects::get(home, &to.department).ok_or_else(|| {
        FunctionCallError::RespondToModel(format!(
            "`{}` works in a department that is gone",
            to.name
        ))
    })?;

    let handoff = handoffs::record(
        home,
        chain_id,
        hop,
        from,
        &to,
        handoffs::Work {
            did: args.did,
            artifacts: args.artifacts,
            next: args.next,
        },
    )
    .map_err(|err| {
        FunctionCallError::RespondToModel(format!("could not record the handoff: {err}"))
    })?;

    let run = dispatch::create(
        home,
        format!("{} → {}", from.name, to.name),
        handoffs::briefing(from, &handoff),
        // Their department's directory, not yours. The receiving bot works
        // under its own department's boundary whoever asked it.
        department.cwd,
        None,
        dispatch::RunSource::Dispatch,
        Some(handoff.id.clone()),
    )
    .map_err(|err| FunctionCallError::RespondToModel(format!("could not queue the work: {err}")))?;
    let _ = handoffs::attach_run(home, &handoff.id, &run.id);

    Ok(format!(
        "Handed to {}. It will run in the background; you will not see the result, so \
         finish by saying what you passed on and why.",
        to.name
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    /// Two bots in one department. No environment is touched: what a run is
    /// working as is now an argument, so these can run beside every other test
    /// without changing what any of them sees.
    fn setup(home: &Path) -> (crate::bots::Bot, crate::bots::Bot) {
        let finance = projects::create(
            home,
            "Finance".to_string(),
            home.to_string_lossy().into_owned(),
            String::new(),
            String::new(),
        )
        .expect("department");
        let one = crate::bots::create(home, finance.id.clone(), "Reconciler".into(), String::new())
            .expect("hire");
        let two =
            crate::bots::create(home, finance.id, "Chaser".into(), String::new()).expect("hire");
        (one, two)
    }

    #[test]
    fn should_queue_the_work_for_the_other_bot() {
        let dir = tempdir().expect("tempdir");
        let (one, two) = setup(dir.path());

        let said = hand_over(
            dir.path(),
            r#"{"to":"chaser","did":"reconciled 142 lines","artifacts":["unmatched.csv"],
                "next":"chase the three customers"}"#,
            &one,
            None,
            0,
        )
        .expect("handed");

        assert!(said.contains("Handed to Chaser"), "got: {said}");
        let queued = dispatch::load(dir.path());
        assert_eq!(queued.len(), 1);
        assert_eq!(queued[0].title, "Reconciler → Chaser");
        assert!(
            queued[0].prompt.contains("unmatched.csv"),
            "the files are the work"
        );
        assert_eq!(handoffs::load(dir.path())[0].to_bot, two.id);
    }

    #[test]
    fn should_answer_a_refusal_rather_than_failing() {
        // A bot handed a failure tries again, differently worded. This one has
        // to be able to read the reason and stop.
        let dir = tempdir().expect("tempdir");
        let (one, _) = setup(dir.path());

        let said = hand_over(
            dir.path(),
            r#"{"to":"nobody-at-all","did":"x","next":"y"}"#,
            &one,
            None,
            0,
        )
        .expect("answered, not raised");

        assert!(said.contains("refused"), "got: {said}");
        assert!(said.contains("nobody-at-all"), "got: {said}");
        assert!(dispatch::load(dir.path()).is_empty(), "nothing was queued");
    }

    #[test]
    fn should_refuse_when_the_chain_has_gone_far_enough() {
        let dir = tempdir().expect("tempdir");
        let (one, _) = setup(dir.path());

        let said = hand_over(
            dir.path(),
            r#"{"to":"chaser","did":"x","next":"y"}"#,
            &one,
            Some("chain-1"),
            handoffs::MAX_HOPS,
        )
        .expect("answered");

        assert!(said.contains("refused"), "got: {said}");
        assert!(said.contains("Stop and report"), "got: {said}");
        assert!(dispatch::load(dir.path()).is_empty());
    }

    #[test]
    fn should_stay_in_the_chain_it_was_handed() {
        // Starting a fresh chain on every hop is how a cap is escaped without
        // ever being hit.
        let dir = tempdir().expect("tempdir");
        let (one, _) = setup(dir.path());

        hand_over(
            dir.path(),
            r#"{"to":"chaser","did":"x","next":"y"}"#,
            &one,
            Some("chain-1"),
            2,
        )
        .expect("handed");

        let recorded = &handoffs::load(dir.path())[0];
        assert_eq!(recorded.chain, "chain-1");
        assert_eq!(recorded.hop, 3);
    }
}
