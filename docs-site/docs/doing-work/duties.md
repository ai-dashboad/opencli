---
title: Duties
sidebar_position: 2
---

# Duties

A duty is a job a bot performs on an interval, which stops and asks you when
it reaches something it should not decide alone.

That last part is the point. Anything can run a prompt on a timer; what makes
this useful for real work is that it is told, in advance, what it is not
allowed to settle.

## The four fields

```
What            Compare ledger.csv against statement.csv, line by line,
                and list what does not match with its reference and amount.

Rules           A difference under 1.00 is rounding. Ignore it.

Escalate when   Any single line over 10,000.

Every           24 hours
```

**What** and **Rules** are kept apart deliberately. The work is the same every
morning; the refund ceiling is a policy somebody revisits. Merged into one
prompt, changing the number means re-reading the whole instruction to find it.

**Escalate when** is written in words, not as a condition. It is given to the
model as an obligation, not evaluated by the product — which means it is only
as reliable as the model reading it. Write it as something checkable: *any
single line over 10,000*, not *anything unusual*.

## What happens when it escalates

The duty stops. It appears in **Bots → Waiting on you** with the question it
could not answer, and **will not run again until you reply**.

Your answer is carried into the next run, so the bot does not ask twice about
the same thing.

A duty that has already asked will not file a second question — it repeats the
open one.

## What it remembers

A duty keeps notes between runs. A run that learned one thing writes down that
one thing; it does not have to restate what it already knew, and a run that
failed halfway does not take the rest of the notes with it.

Writing an empty value is how something is deliberately forgotten.

## Where it runs

In the bot's department directory, which is the whole of what the run may
write to. A duty pointed somewhere else is held until you allow that place by
name — see [Sandbox and approvals](/configuration/sandbox-and-approvals).

## Duties, and scheduled tasks

Both run a prompt on a timer. The difference is what they belong to.

| | Belongs to | Escalates | Remembers |
| --- | --- | --- | --- |
| **Duty** | a bot, in a department | yes | yes |
| **Scheduled task** | nothing | no | no |

Use a scheduled task for *every morning at nine, tell me what changed*. Use a
duty for work with a policy attached.
