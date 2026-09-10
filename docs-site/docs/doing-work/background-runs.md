---
title: Background runs
sidebar_position: 3
---

# Background runs

Work sent off to run on its own. Each run is a separate agent in its own
directory, so it keeps going after you close the chat that started it.

## Four ways one starts

| Source | Started by |
| --- | --- |
| **Dispatch** | you, by hand, in the Dispatch panel |
| **Scheduled** | a recurring task coming due |
| **Duty** | a bot's duty coming due |
| **Cowork** | sending a message in Cowork mode |

All four end up in the same list, which is why the panel is worth reading even
if you never dispatch anything by hand.

## They run only while OpenCLI is open

This is a local agent, not a server. Anything that must fire while the machine
is asleep belongs in the operating system's scheduler — `cron`, `launchd`,
Task Scheduler.

Said plainly because the alternative is a task that silently never ran.

## How many at once

Three by default. Each is a whole agent with its own model calls, so more than
your machine can feed makes them all slower rather than finishing sooner. The
number is a control in the panel and takes effect without a restart.

Sixteen is the ceiling, and not as a matter of taste: past it, runs stop
making progress and start competing for the same weights.

## Directories, and why a run may be held

A run's sandbox can write **anywhere inside its working directory**. That
directory is therefore not a convenience — it is the whole of what the run may
change.

So a run is allowed to start when its directory is one this product already
knows about:

- inside the workspace
- inside a department's own directory
- somewhere you have allowed by name

Anything else is **held**, and appears under **Waiting for you** with an
*Allow this directory* button. Allowing a place releases every run waiting on
it.

If your approval setting is **Never ask**, nothing is held. Somebody who has
turned approvals off has said as much, and the product does not overrule the
setting it offered.

## Watching one

Output appears as the agent produces it, not when the run finishes. A run that
takes ten minutes is readable for all ten.

## Picking one up

A finished run can be continued as an ordinary conversation: **Continue in a
chat** opens a new thread in the same directory, with what the run was asked
and what it reported already in context.

The run itself cannot be spoken to. This is the way back in.
