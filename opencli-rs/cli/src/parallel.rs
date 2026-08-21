//! `opencli parallel` — run several agent tasks concurrently, each on its own
//! branch in its own git worktree, then report so the results can be reviewed
//! and merged.
//!
//! Each task runs as an isolated `opencli exec` subprocess against a fresh
//! `git worktree`, so parallel tasks never share a working tree and cannot
//! corrupt each other's edits.

use std::path::PathBuf;
use std::process::Stdio;

use anyhow::Context;
use anyhow::Result;
use anyhow::bail;
use clap::Args;
use tokio::process::Command;

#[derive(Debug, Args)]
pub struct ParallelArgs {
    /// A task to run, as `branch=prompt`. Repeatable. Each task gets its own
    /// branch and worktree. Example: `--task fix-auth="fix the login bug"`.
    #[arg(long = "task", value_name = "BRANCH=PROMPT", required = true)]
    pub tasks: Vec<String>,

    /// Base branch or commit the worktrees fork from. Defaults to the current
    /// checkout's HEAD.
    #[arg(long, value_name = "REF")]
    pub base: Option<String>,

    /// Directory that holds the created worktrees.
    #[arg(long, value_name = "DIR", default_value = ".opencli-worktrees")]
    pub dir: PathBuf,

    /// After all tasks succeed, merge each branch back into the base branch.
    /// Off by default: branches are left for review.
    #[arg(long)]
    pub merge: bool,

    /// Keep the worktrees after finishing. By default worktrees are removed
    /// (the branches remain), leaving a clean tree.
    #[arg(long)]
    pub keep: bool,

    /// Maximum number of tasks to run at once. Cheap gateways often rate-limit
    /// concurrent requests (HTTP 429), so this defaults to a modest value;
    /// raise it when the target provider allows more concurrency.
    #[arg(long, value_name = "N", default_value_t = 3)]
    pub jobs: usize,
}

struct Task {
    branch: String,
    prompt: String,
    worktree: PathBuf,
}

struct TaskResult {
    branch: String,
    worktree: PathBuf,
    success: bool,
}

/// Entry point for the `parallel` subcommand.
pub async fn run_main(args: ParallelArgs) -> Result<()> {
    let repo_root = git_repo_root().await?;
    let base = match args.base {
        Some(base) => base,
        None => current_branch(&repo_root).await?,
    };

    let tasks = parse_tasks(&args.tasks, &args.dir)?;

    // Create one worktree+branch per task up front so a bad spec fails before
    // any agent runs.
    for task in &tasks {
        create_worktree(&repo_root, &task.branch, &task.worktree, &base).await?;
    }

    println!(
        "Running {} task(s), up to {} at a time, from base `{base}`...",
        tasks.len(),
        args.jobs.max(1)
    );

    let permits = std::sync::Arc::new(tokio::sync::Semaphore::new(args.jobs.max(1)));
    let handles: Vec<_> = tasks
        .into_iter()
        .map(|task| {
            let permits = std::sync::Arc::clone(&permits);
            tokio::spawn(async move {
                let _permit = permits.acquire().await.expect("semaphore not closed");
                run_task(task).await
            })
        })
        .collect();

    let mut results = Vec::new();
    for handle in handles {
        match handle.await {
            Ok(Ok(result)) => results.push(result),
            Ok(Err(err)) => eprintln!("task error: {err:#}"),
            Err(err) => eprintln!("task panicked: {err}"),
        }
    }

    report(&results);

    if args.merge {
        merge_successful(&repo_root, &base, &results).await?;
    }

    if !args.keep {
        for result in &results {
            remove_worktree(&repo_root, &result.worktree).await;
        }
    }

    if results.iter().any(|result| !result.success) {
        bail!("one or more tasks failed");
    }
    Ok(())
}

fn parse_tasks(specs: &[String], dir: &PathBuf) -> Result<Vec<Task>> {
    let mut tasks = Vec::new();
    for spec in specs {
        let Some((branch, prompt)) = spec.split_once('=') else {
            bail!("invalid --task `{spec}`: expected `branch=prompt`");
        };
        let branch = branch.trim();
        let prompt = prompt.trim();
        if branch.is_empty() || prompt.is_empty() {
            bail!("invalid --task `{spec}`: branch and prompt must both be non-empty");
        }
        tasks.push(Task {
            branch: branch.to_string(),
            prompt: prompt.to_string(),
            worktree: dir.join(branch),
        });
    }
    Ok(tasks)
}

async fn run_task(task: Task) -> Result<TaskResult> {
    // One retry absorbs a transient gateway failure (e.g. a 429 from a
    // concurrency-limited cheap pool) without failing the whole task.
    let mut success = exec_once(&task).await?;
    if !success {
        tokio::time::sleep(std::time::Duration::from_secs(3)).await;
        success = exec_once(&task).await?;
    }

    // Commit the task's edits onto its branch so there is something to merge.
    // The agent is not asked to commit; the orchestrator captures whatever it
    // left in the working tree. An empty tree simply produces no commit.
    if success {
        commit_worktree(&task.worktree, &format!("{}: {}", task.branch, task.prompt)).await;
    }

    Ok(TaskResult {
        branch: task.branch,
        worktree: task.worktree,
        success,
    })
}

async fn exec_once(task: &Task) -> Result<bool> {
    let exe = std::env::current_exe().context("resolve opencli executable path")?;
    let status = Command::new(exe)
        .arg("exec")
        .arg("--cd")
        .arg(&task.worktree)
        .arg(&task.prompt)
        .stdin(Stdio::null())
        .status()
        .await
        .with_context(|| format!("run task on branch `{}`", task.branch))?;
    Ok(status.success())
}

/// Stage and commit everything in `worktree`. Best-effort: a clean tree (no
/// changes) leaves no commit, which is fine.
async fn commit_worktree(worktree: &PathBuf, message: &str) {
    let _ = Command::new("git")
        .current_dir(worktree)
        .args(["add", "-A"])
        .status()
        .await;
    let _ = Command::new("git")
        .current_dir(worktree)
        .args(["commit", "-m", message])
        .status()
        .await;
}

fn report(results: &[TaskResult]) {
    println!("\nResults:");
    for result in results {
        let mark = if result.success { "ok" } else { "FAILED" };
        println!("  [{mark}] {}  ({})", result.branch, result.worktree.display());
    }
    println!("\nReview a branch with `git diff {}..<branch>`.", "HEAD");
}

async fn merge_successful(repo_root: &PathBuf, base: &str, results: &[TaskResult]) -> Result<()> {
    // Merge only cleanly-finished branches, and only after switching the main
    // checkout to the base branch.
    run_git(repo_root, &["checkout", base]).await?;
    for result in results.iter().filter(|result| result.success) {
        println!("Merging `{}` into `{base}`...", result.branch);
        let merged = run_git(repo_root, &["merge", "--no-ff", &result.branch]).await;
        if merged.is_err() {
            eprintln!(
                "merge of `{}` hit conflicts; resolve manually, the branch is preserved",
                result.branch
            );
            let _ = run_git(repo_root, &["merge", "--abort"]).await;
        }
    }
    Ok(())
}

async fn create_worktree(
    repo_root: &PathBuf,
    branch: &str,
    worktree: &PathBuf,
    base: &str,
) -> Result<()> {
    let worktree = worktree.to_string_lossy().to_string();
    run_git(
        repo_root,
        &["worktree", "add", "-b", branch, &worktree, base],
    )
    .await
    .with_context(|| format!("create worktree for branch `{branch}`"))
}

async fn remove_worktree(repo_root: &PathBuf, worktree: &PathBuf) {
    let worktree = worktree.to_string_lossy().to_string();
    let _ = run_git(repo_root, &["worktree", "remove", "--force", &worktree]).await;
}

async fn git_repo_root() -> Result<PathBuf> {
    let output = Command::new("git")
        .args(["rev-parse", "--show-toplevel"])
        .output()
        .await
        .context("run git rev-parse")?;
    if !output.status.success() {
        bail!("not inside a git repository");
    }
    let root = String::from_utf8(output.stdout)?.trim().to_string();
    Ok(PathBuf::from(root))
}

async fn current_branch(repo_root: &PathBuf) -> Result<String> {
    let output = Command::new("git")
        .current_dir(repo_root)
        .args(["rev-parse", "--abbrev-ref", "HEAD"])
        .output()
        .await
        .context("resolve current branch")?;
    if !output.status.success() {
        bail!("could not resolve current branch");
    }
    Ok(String::from_utf8(output.stdout)?.trim().to_string())
}

async fn run_git(repo_root: &PathBuf, args: &[&str]) -> Result<()> {
    let status = Command::new("git")
        .current_dir(repo_root)
        .args(args)
        .status()
        .await
        .with_context(|| format!("run git {}", args.join(" ")))?;
    if !status.success() {
        bail!("git {} failed", args.join(" "));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_parse_valid_task_specs() {
        let dir = PathBuf::from("/tmp/wt");
        let tasks = parse_tasks(
            &["fix-auth=fix the login bug".to_string(), "docs=write docs".to_string()],
            &dir,
        )
        .expect("parse");
        assert_eq!(tasks.len(), 2);
        assert_eq!(tasks[0].branch, "fix-auth");
        assert_eq!(tasks[0].prompt, "fix the login bug");
        assert_eq!(tasks[0].worktree, dir.join("fix-auth"));
    }

    #[test]
    fn should_reject_task_without_equals() {
        let dir = PathBuf::from("/tmp/wt");
        assert!(parse_tasks(&["no-equals-here".to_string()], &dir).is_err());
    }

    #[test]
    fn should_reject_task_with_empty_branch_or_prompt() {
        let dir = PathBuf::from("/tmp/wt");
        assert!(parse_tasks(&["=prompt".to_string()], &dir).is_err());
        assert!(parse_tasks(&["branch=".to_string()], &dir).is_err());
    }
}
