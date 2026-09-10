---
title: Limits
sidebar_position: 2
---

# Limits

Said here rather than discovered later.

## The models

**A small local model is not as good at this as a frontier one.** The
interface is the same; the reasoning is not.

**General open models reach for `grep` when they have a file tool.** Given a
structured way to read a file, a model not trained towards agentic work will
still shell out. That is a gap in the models, and no interface closes it. What
this project can change is reach, not intelligence.

**A model that will not call tools cannot do this work at all.** It will chat.
[Check yours](/reference/checking-a-model) before committing to it — five
minutes, one fixed task.

## The counting

**Token counts are estimated, never counted.** The tokenizer belongs to the
model, and this runs models it has never seen. Four ASCII bytes to a token,
one token per character otherwise: close for English and Chinese alike, erring
towards over-counting elsewhere.

Everything downstream is therefore approximate — when a conversation is
summarised, when a tool's output is cut, and what the usage line says.

## The scheduling

**Scheduled tasks and duties run only while OpenCLI is open.** This is a local
agent, not a server. Anything that must fire while the machine sleeps belongs
in the operating system's scheduler.

## The sandbox

**A background run may write anything inside the directory it runs in.** The
writable root *is* that directory. Runs outside a department's directory are
held until you allow the place by name — unless approvals are set to never,
in which case nothing is held.

**Reads are never restricted**, in any sandbox mode.

## The record of what changed

**Artifacts lists only edits made with the agent's file-editing tool.** Files
written by a shell command it ran — a heredoc, a script, `git checkout` — are
not tracked and will not appear. The change is real; the list is incomplete.

## The desktop builds

**They are not signed** with an Apple or Microsoft certificate. Your operating
system will warn you, and it is right to: it cannot tell who built them.
[Install](/getting-started/install) says what to do.

## The interface

**Right-to-left languages are not supported.** Arabic, Hebrew and Persian can
be added as translation files, and the page will still be laid out left to
right. That is a change to the stylesheet, not to a translation.

## Escalation is an instruction, not a guarantee

A duty's *escalate when* is given to the model as an obligation. It is not
evaluated by this product, which means it is exactly as reliable as the model
reading it. Write it as something checkable — *any single line over 10,000* —
rather than *anything unusual*.
