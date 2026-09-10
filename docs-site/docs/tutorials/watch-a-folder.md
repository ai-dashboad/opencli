---
title: Watch a folder
sidebar_position: 2
---

# Watch a folder and report what changed

Ten minutes. At the end, something writes you a short report of what moved in
a directory, on whatever schedule you choose — a project, a shared drive, a
folder somebody else keeps putting things in.

## 1. Point a chat at the folder

Open a new chat and use the folder button above the composer to choose the
directory.

This matters more than it looks: **the agent may write anywhere inside the
directory a chat is open in**, and nowhere outside it. Choosing the folder is
choosing the blast radius.

## 2. Ask for the report once

```
Use the weekly-report skill on this folder.
```

The `weekly-report` skill ships with the product. It works out what changed —
from git if the folder is a repository, from modification times otherwise —
and writes three sections: what finished, what is underway, and **what needs a
decision**.

That last section is the reason to read it.

## 3. Put it on a schedule

**Background runs → Schedule a repeating one:**

| Field | |
| --- | --- |
| **What should it do** | Use the weekly-report skill on this folder. Save it as `report-<date>.md`. |
| **Name** | Weekly report |
| **How often** | 7 days |
| **Where to run** | the folder you chose |

## 4. Check where it will run

If the folder is not inside your workspace and not a department, the first run
will be **held** rather than started, and appear under *Waiting for you*.

That is deliberate. Allow the directory, or move the task into a department.

## 5. Read the first one

**Run now**, then open the run to read the output as it is produced.

If the report is thin, the folder had a thin week — the skill is told to say
so in one line rather than padding, because a report padded out of an empty
week teaches people to skip reports.

## Doing this to somebody else's folder

Two things worth being careful about.

**The agent reads everything it is pointed at**, and reads are not restricted
by the sandbox in any mode. A folder with things you would not send to your
model provider should not be the folder you point it at — unless your model is
on your own machine, in which case nothing leaves it.

**A schedule outlives your attention.** Something that runs weekly for a year
is fifty-two runs you did not watch. Keep the directory tight.
