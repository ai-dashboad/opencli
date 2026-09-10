---
title: Contributing
sidebar_position: 3
---

# Contributing

**Pull requests are welcome, and there is no invitation to wait for.** This is
a small project; the useful thing is usually not a large feature but a row in a
table, a sentence in a translation, or a bug report detailed enough to act on.

## The most useful contributions

**A row in the model table.** [Checking a model](/reference/checking-a-model)
is a fixed five-minute task. The table is short because it only holds models
somebody ran, and **a negative result is worth as much as a positive one** —
nobody posts about the model that did not work, so everybody rediscovers it.

**A translation, or one line of a correction to one.** Ten ship. Any of them
can be corrected one sentence at a time without touching the rest — see
[Languages](/configuration/languages). A new language is a single JSON file.

**A bug report with the four things.** The model and provider written exactly
(`qwen3-coder:30b` on Ollama, not "a local model"), what you asked, what
happened, and fifty lines of `~/.opencli/log` from around the failure.
**Check those log lines for keys before you paste them.**

**Telling us what you actually wanted to do.** The built-in departments and
skills were written from guesses about what people need. The thing you reached
for and did not find is the most useful thing you can say.

## Before you write code

**Open an issue first for anything larger than a fix.** Not as a gate — so the
approach can be agreed before you spend an evening on it. A PR that arrives
with no issue behind it still gets read.

## Setting up

Rust and pnpm; the workspace is `opencli-rs/`, the web interface is `web/`, and
the desktop shell is `desktop/`.

```shell
git clone https://github.com/ai-dashboad/opencli
cd opencli
pnpm install
cargo build -p opencli-cli
```

`just` from the repo root runs the workspace helpers; `just help` lists them.

## Before you open the PR

```shell
just fmt
just fix -p <crate>          # clippy, on the crate you touched
cargo test -p <crate>
```

**Do not run a bare `cargo fmt`.** The tree is formatted with
`imports_granularity=Item`, which is nightly-only. On stable that option is
**silently ignored**, so `cargo fmt` rewrites the import block of nearly every
file in the workspace and buries your change in hundreds of unrelated diffs.
`just fmt` invokes nightly for exactly this reason. Without a nightly toolchain
(`rustup toolchain install nightly`), format only the files you touched and let
CI confirm the rest.

If you touched the web interface, `python3 scripts/i18n-check.py` finds English
that was never wrapped for translation — including the cases that are easy to
miss, like text split by an inline tag and labels built at import time.

## What makes a PR easy to merge

- **One thing.** Unrelated fixes are separate PRs.
- **A test that fails before your change and passes after.** Not full coverage —
  one assertion that would have caught the bug.
- **Commits that each build.** It makes review and rollback possible.
- **Documentation, if behaviour changed.** The README, `opencli --help`, or the
  page here that is now wrong.
- **What, why, how** in the description. The *why* is the part that cannot be
  read off the diff.

## No CLA

**There is nothing to sign.** Contributions are under
[Apache-2.0](https://github.com/ai-dashboad/opencli/blob/main/LICENSE), like the
rest of the tree.

## Reporting a vulnerability

**Do not open a public issue for a security bug.** Use GitHub's
[private advisory form](https://github.com/ai-dashboad/opencli/security/advisories/new),
which reaches the maintainers without publishing anything.

The parts most worth looking at: the sandbox policy, the approval path, and
anything that decides what a tool call is allowed to touch. **An agent that
reads your files and runs commands on your machine has a large surface, and it
is better for you to find it than for somebody else to.**

## Being decent about it

Treat people with respect; we follow the
[Contributor Covenant](https://www.contributor-covenant.org/). Assume good
intent — **written communication is hard, so err on the side of generosity.**
If something is confusing, that is worth an issue on its own: confusing
documentation is a bug in the documentation.
