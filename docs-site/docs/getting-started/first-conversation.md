---
title: First conversation
sidebar_position: 3
---

# First conversation

## Where it starts

A new chat opens in `~/.opencli/workspace` unless it belongs to a department,
in which case it opens in that department's directory.

**That matters more than it looks.** The agent's sandbox can write anywhere
inside its working directory, so the directory a conversation is open in is
the whole of what it may change. It used to default to your home directory;
it does not any more, and the reason is
[Sandbox and approvals](/configuration/sandbox-and-approvals).

Change it with the folder button above the composer.

## Asking for something

Ordinary sentences. It has your files, a shell, and whatever
[connectors](/doing-work/connectors) you have added:

```
Read invoices.csv and list every row that breaks the rules in rules.md
```

```
What changed in this repository over the last week?
```

```
Compare their-draft.md against our-terms.md and list every clause that differs
```

## What happens before anything is changed

By default the agent shows you a command that is not known to be safe before
running it, and shows a file write before making it. Approve or deny each one.

Three settings, in **Customize**:

| | |
| --- | --- |
| **Ask before anything unfamiliar** | every command that is not known-safe is shown first |
| **Ask only after something fails** | commands run unattended; you are asked when one needs more access |
| **Never ask** | nothing is shown before it runs |

The last one is for a directory you would let a script loose in. It is
explained properly in
[Sandbox and approvals](/configuration/sandbox-and-approvals).

## Seeing what it did

**Artifacts** lists the files the agent edited in this conversation, with
their diffs. One honest limit: only edits made with the agent's file-editing
tool are listed. Files written by a shell command it ran — a heredoc, a
script, `git checkout` — are not tracked and will not appear.

## When it stops making sense

A conversation that has grown long is summarised so it keeps fitting. You will
see **Summarising the conversation…**, and afterwards the thread continues
with a summary in place of the older turns.

If summarising cannot help — because the length is coming from tool schemas
rather than from the conversation — it says so once rather than doing it again
every turn.

## Next

One conversation is one conversation. To have work happen without you being
there, [set up a department](/doing-work/departments-and-bots).
