---
title: Reconcile a ledger
sidebar_position: 1
---

# Reconcile a ledger, start to finish

Twenty minutes, with a local model. At the end you have a department that
checks two files against each other every morning and stops to ask you when it
finds something over a threshold you set.

Everything here uses the sample data that ships, so nothing has to be prepared.

## 1. Create the department

**Projects → or start with one that already works → Finance.**

It creates `~/.opencli/workspace/finance`, writes three files into it, and
hires two bots.

The files have problems planted in them on purpose:

| File | What is in it |
| --- | --- |
| `ledger.csv` | what your books say |
| `statement.csv` | what the bank says |
| `overdue.csv` | invoices past their date |

## 2. Ask it once, by hand

Open the department and type:

```
Compare ledger.csv against statement.csv. List every line that does not
match, with the reference and the amount, and say what you think happened.
```

Watch what it does. A model suited to this will read both files with a tool
and answer with rows and references. A model that is not will either ask you
to paste the contents or answer in generalities — if that happens, the model
is the problem, not the setup. [Check it](/reference/checking-a-model).

## 3. Turn it into a duty

The bot did it once. A duty makes it come round on its own.

Open the **Reconciler** bot, and set its duty:

| Field | What to put |
| --- | --- |
| **What** | Compare `ledger.csv` against `statement.csv` line by line. List what does not match, with the reference and the amount. |
| **Rules** | A difference under 1.00 is rounding. Ignore it. |
| **Escalate when** | Any single line over 10,000. |
| **Every** | 24 hours |

**Rules** and **What** are separate for a reason: the work is the same every
morning, and the threshold is a policy somebody revisits. Merged into one
prompt, changing the number means re-reading the whole instruction to find it.

## 4. Watch it stop

**Run now.** The sample data contains a mismatch above the threshold, so the
duty will not finish — it will appear in **Bots → Waiting on you** with the
question it could not answer.

That is the whole point of the feature. It did the work, reached the line you
drew, and stopped rather than deciding.

Answer it. Your answer is carried into the next run, so it does not ask twice
about the same thing.

## 5. Hand the result on

The Finance department ships with a second bot, **Chaser**. In the Reconciler's
**can hand to** list, tick it.

Now a run that finds unmatched lines can pass them on — along with what it did
and the files it produced — and the Chaser drafts one chasing email per
customer without being told the background.

**Bots → Work passed between bots** shows the chain afterwards, and marks one
that stopped because it ran out of hops rather than because it finished.

## What you have now

- a directory the agent may write to, and nowhere else
- work that happens without you starting it
- a written threshold at which it stops and asks
- a second bot that picks up where the first left off

## What to change first

**The threshold.** 10,000 is a number from an example. Yours is not.

**The rules.** "A difference under 1.00 is rounding" is true of some books and
not others.

**The interval.** Every 24 hours is a habit, not a law. A duty that runs after
the bank posts is more useful than one that runs at midnight.
