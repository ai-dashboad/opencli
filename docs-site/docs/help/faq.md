---
title: FAQ
sidebar_position: 1
---

# Questions people actually ask

## Is my data sent anywhere?

To the endpoint you configured, and nowhere else. There is no gateway of ours
in the middle, no telemetry account, and no key baked into the binary.

If that endpoint is a model on your own machine, nothing leaves the machine at
all.

## Does it work offline?

Yes, with a local model. The desktop app checks for its own updates and the
Models panel fetches a list of popular models — both fail quietly without a
network and neither is needed to hold a conversation.

## Do I need an API key?

Not if you run a model locally. Ollama, LM Studio, llama.cpp and the rest need
nothing. A hosted provider needs its own key, which is stored away from the
configuration file and never shown again.

## Which model should I use?

Whichever your machine can hold, with one hard requirement: **it must call
tools.** A model that will not is limited to conversation here.

[Checking a model](/reference/checking-a-model) is a five-minute test that
answers this. The table in it is short because it only holds what has been run.

## Why is it worse than Claude Code / Codex?

Because a 27B model quantised to fit a laptop is not GPT-5. The interface is
the same; the reasoning is not.

What this project changes is reach — whether the model you have can be used
this way at all — not how clever it is.

## Can it use GPT-5 or Claude?

Yes. Configure OpenAI or Anthropic like any other provider. Nothing in the
product prefers one over another.

## Where does a conversation start?

In `~/.opencli/workspace`, unless it belongs to a department, in which case it
starts in that department's directory.

It used to be your home directory. It is not any more, because the sandbox's
writable root **is** the working directory — see
[Sandbox and approvals](/configuration/sandbox-and-approvals).

## Can several people use one installation?

No. The gateway is single-user by design and says so in its own source. Each
person runs their own copy; a shared model server behind them is the normal
arrangement.

## Will scheduled work run while my laptop is asleep?

No. Scheduled tasks and duties run only while OpenCLI is open, because this is
a local agent rather than a server. Anything that must fire on a sleeping
machine belongs in `cron`, `launchd` or Task Scheduler.

## How is this different from Open WebUI or Jan?

They are chat interfaces for local models, and good ones. This is an agent: it
reads and edits your files, runs commands, and carries on working in the
background. Different job, and there is no reason not to run both.

## How is this different from Codex, which it forked from?

Codex is built for OpenAI's models. Departments, bots, duties, background runs,
handoffs between bots, the shipped workflows and the ten interface languages
are from this side of the fork, along with a good deal of work on what breaks
when the model is small.

## Why does it say the app is damaged / unverified?

Because the builds carry no Apple or Microsoft certificate — those cost money
per year and this project has not spent it.
[Install](/getting-started/install) says exactly what to click.

## Can I change what it is called?

Not yet. Branding is compiled in.

## Something is broken. Where do I look?

[Troubleshooting](/help/troubleshooting), then the logs in `~/.opencli/log`,
then [an issue](https://github.com/ai-dashboad/opencli/issues).
