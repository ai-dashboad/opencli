---
title: Skills
sidebar_position: 4
---

# Skills

A skill is a set of instructions the agent draws on when a task calls for it —
a procedure written down once, rather than pasted into a prompt every time.

## What ships

Six workflows come with the product and work in any directory:

| Skill | What it does |
| --- | --- |
| `spreadsheet-review` | Checks a file of rows against its stated rules, and reports the rows that break them with their row numbers |
| `weekly-report` | What actually changed here over a period — done, in progress, and what needs a decision |
| `inbox-triage` | Sorts messages by what they are asking for, and flags the ones a person must answer |
| `document-compare` | What changed in substance between two drafts, separately from what only changed in wording |
| `meeting-notes` | A transcript into decisions, actions with owners, and open questions |
| `records-review` | Raises what is worth checking in a set of records, citing the note each came from |

Two more, inherited, are about writing and installing skills themselves:
`skill-creator` and `skill-installer`.

## Where they come from

| Scope | Directory |
| --- | --- |
| Shipped | `~/.opencli/skills/.system` — rewritten when the app updates |
| Yours | `~/.opencli/skills` |
| This project's | `.opencli/skills` in the working directory |

## Writing one

A directory with a `SKILL.md`, whose front matter says what it is and **when
to use it**:

```markdown
---
name: invoice-check
description: Check invoices against our payment rules and report what breaks
  them. Use when asked to review, check or audit a file of invoices.
metadata:
  short-description: Find invoices that break the rules
---

# Invoice check

## Find the rules before reading the rows
...
```

The `description` is what the agent matches a request against. A description
that only says what the skill *is* leaves the model to guess when it applies —
every shipped skill names its occasions, and yours should too.

## What makes one work

Reading the six that ship is the fastest way to see the shape, but three
things recur:

- **Say what to read, and in what order.** "Oldest first" is a real
  instruction; "review the records" is not.
- **Say what to produce.** A named file, or a stated structure. Not "a
  summary".
- **Say what it must never do.** The shipped clinical skill spends a third of
  its length on this, and that is why it can exist.

One found the hard way: if a number matters, **say where the number must come
from**. The spreadsheet skill asks for a row count, and the first run stated
it from memory and got it wrong by one. It now requires that the count come
from the script that did the checking.

## Turning one off

Each skill has a switch in **Abilities → Skills**. A change applies to the
next chat you open, not the one already running.
