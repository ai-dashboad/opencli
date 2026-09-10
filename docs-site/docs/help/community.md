---
title: Getting help
sidebar_position: 4
---

# Getting help, and where to say something

## Before asking

Most of what goes wrong the first week is in
[Troubleshooting](/help/troubleshooting), and the answer to *is my provider
supported* is in [Providers](/getting-started/providers).

If the agent talks but never touches your files, that is almost always the
model rather than the setup — [check it](/reference/checking-a-model) before
spending an evening on configuration.

## Where to ask

**[GitHub Issues](https://github.com/ai-dashboad/opencli/issues)** — bugs, and
anything that behaved differently from what the documentation says.

**[GitHub Discussions](https://github.com/ai-dashboad/opencli/discussions)** —
questions, ideas, and "is this supposed to work like this".

There is no chat server yet. When there are enough people for one to be worth
sitting in, there will be; an empty room helps nobody.

## What makes a report easy to act on

Four lines, and most reports do not have them:

1. **The model and provider**, exactly as named — `qwen3-coder:30b` on Ollama,
   not "a local model".
2. **What you asked it to do**, verbatim.
3. **What happened**, and what you expected instead.
4. **The last fifty lines of `~/.opencli/log`** around the failure.

Check those log lines for keys before pasting them.

## What helps most

**A row in the model table.** [Checking a model](/reference/checking-a-model)
is one fixed task and about five minutes. The table is short because it only
holds what has been run, and **a negative result is worth as much as a
positive one** — nobody posts about the model that did not work, so everybody
re-discovers it.

**A translation, or a correction to one.** Ten ship. Any of them can be
corrected one line at a time, without touching the rest — see
[Languages](/configuration/languages).

**Telling us what you actually tried to do.** The departments and workflows
that ship were written from guesses about what people need. What you reached
for and did not find is the most useful thing you can say.

## Contributing code

[Contributing](/reference/contributing) has the setup and the pull request
process.
