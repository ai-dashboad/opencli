---
title: Sandbox and approvals
sidebar_position: 2
---

# Sandbox and approvals

Two settings, doing different jobs. The sandbox decides what the agent *can*
do; approvals decide what it must ask about first.

## The sandbox

```toml
sandbox_mode = "workspace-write"
```

| | The agent may |
| --- | --- |
| `read-only` | look at files, not change them |
| `workspace-write` | write inside its working directory |
| `danger-full-access` | anything your account can |

**Reads are never restricted.** Only writing and network access are, so
`read-only` means the agent can see your whole disk and change none of it.

### The writable root is the working directory

Under `workspace-write`, "the workspace" means **the directory the
conversation or run is open in**. Not the project, not the repository — that
directory.

This is the single most important sentence on this page. A run opened in your
home directory may write to `.ssh`, `Documents` and `Library`.

That is not hypothetical. A scheduled task created before departments existed
carried the home directory and had run forty-two times that way, each run able
to reach all of it, with nobody asked and nothing said. Changing the default
for new conversations did not touch it, because a default is not retroactive.

So a second check exists, at the moment a run starts.

## Where a background run may start

A run is allowed to begin when its directory is one this product already knows
about:

- inside the workspace
- inside a department's directory
- somewhere you allowed by name

Anything else is **held**, and appears under **Waiting for you** in the
Dispatch panel with an *Allow this directory* button. Allowing a place
releases every run waiting on it.

The asking is the point: running somewhere unusual is often exactly what was
wanted, and the answer is a prompt rather than a refusal.

## Approvals

```toml
approval_policy = "on-failure"
```

| | |
| --- | --- |
| `untrusted` | every command not known to be safe is shown first |
| `on-failure` | commands run unattended; you are asked when one needs more access |
| `never` | nothing is shown before it runs |

`never` also means **nothing is held**. Somebody who has turned approvals off
has said, in as many words, that they do not want to be stopped, and deciding
they meant something narrower would be the product overruling its own setting.

Use it for a directory you would let a script loose in.

## The combination that catches people

`sandbox_mode = "danger-full-access"` with `approval_policy = "never"` is an
agent running arbitrary commands on your machine with nothing shown and
nothing asked. There are directories where that is the right answer. Your home
directory is not one of them.

## Two things the sandbox does not do

- **It does not stop the model reading your files.** Reads are not restricted
  in any mode.
- **It does not cover what a command it ran does afterwards.** A script the
  agent starts inherits the sandbox; a service it starts that outlives the run
  does not.
