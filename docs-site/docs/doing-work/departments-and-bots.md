---
title: Departments and bots
sidebar_position: 1
---

# Departments and bots

A chat is one conversation. Work that comes round again needs something that
outlives it.

| | Is | Lives in |
| --- | --- | --- |
| **Department** | a directory plus standing instructions | `~/.opencli/workspace/<name>` by default |
| **Bot** | a chat inside a department, with a job | that department |
| **Duty** | a job that comes round on its own | a bot |

The words are borrowed from an office on purpose. A department is not a
folder-with-a-nice-name: it is the boundary of what the work inside it may
touch.

## Starting from one that already works

Nine departments ship with sample data — files with problems already planted
in them — so the first run does something rather than explaining that there is
nothing to do.

| Department | What comes with it |
| --- | --- |
| Finance | Reconcile `ledger.csv` against `statement.csv`; chase what is overdue |
| Support | Answer what came in; group questions by what they are really about |
| Operations | List every order still unshipped, and how long it has waited |
| Marketing | Turn notes into a week of posts; group contacts by what they bought |
| People & admin | Read applicants against a role; pull decisions and owners out of notes |
| Legal | Compare their draft against our terms, clause by clause, quoting both |
| Research | Where studies agree, where they conflict, and why |
| Clinical records | What is recorded, and what a clinician should look at, quoted |
| Engineering | Read a service and report what would give a wrong answer |

**Projects → or start with one that already works.** It creates the directory,
writes the sample files, and hires the bots.

## Making your own

**Projects → New**, then:

- **Name** — what it is called
- **Folder** — created if it does not exist
- **Standing instructions** — given to the agent in *every* chat opened here

Standing instructions are where the things you would otherwise retype go: how
to build it, what not to touch, which numbers are policy. They are separate
from the description, which only you read.

## Bots

A bot is a chat with a job. The job goes back in every time the bot is woken,
so it does not have to be told again what it is for.

Four states, in the **Bots** panel:

| | |
| --- | --- |
| **Idle** | nothing to do |
| **Working** | a run is going |
| **Waiting for you** | it stopped and asked — see [Duties](/doing-work/duties) |
| **Errored** | the last run failed |

## Bots handing work to each other

A bot can pass work to another bot **by name**, with what it did and the files
it produced. The receiver starts from those rather than from nothing.

Three refusals keep that from running away, and they are the substance of it:

- **Depth.** A chain is capped at eight hops.
- **Repetition.** No bot may appear more than three times in one chain.
- **Direction.** A bot may only be handed work by a department that has been
  allowed to. Within one department it is always allowed.

The **Bots** panel shows every chain, and marks the ones that stopped because
they ran out of rope rather than because they finished.

## Next

[Duties](/doing-work/duties) — work that comes round without you starting it.
