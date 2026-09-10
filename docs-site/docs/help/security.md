---
title: Security
sidebar_position: 3
---

# Security

What this product does with your machine and your data, stated so you can
decide rather than assume.

## What leaves your machine

Your prompts, and whatever files the agent reads on your behalf, go to **the
endpoint you configured** and nowhere else. There is no gateway of ours in the
middle.

If that endpoint runs on your own machine, nothing leaves it.

Two exceptions, both of which fail quietly offline and neither of which
carries anything you typed:

- the desktop app asks its update endpoint whether there is a newer version
- the Models panel fetches a list of popular models from Hugging Face when
  opened

## What the agent can do to your machine

Two settings, doing different jobs.

**The sandbox** decides what it *can* do. Under `workspace-write` — the
default — it may write **anywhere inside its working directory** and nowhere
else. Reads are never restricted, in any mode.

**Approvals** decide what it must ask about first, from every unfamiliar
command down to nothing at all.

The combination worth being careful with is `danger-full-access` together with
`never`: an agent running arbitrary commands with nothing shown and nothing
asked. There are directories where that is right. Your home directory is not
one of them.

[Sandbox and approvals](/configuration/sandbox-and-approvals) has the detail.

## Where a background run may start

A run whose directory is not the workspace, a department, or somewhere you
allowed by name is **held** rather than started. This exists because a
scheduled task made before departments existed carried a home directory and
had run forty-two times, each run able to reach `.ssh` and `Documents`, with
nobody asked.

Setting approvals to `never` turns this off along with everything else, which
is what that setting means.

## Keys

API keys are kept **out of `config.toml`**, because that file gets shared and
pasted into issues. They are written where your other secrets are, and never
shown again once saved.

Connector keys work the same way: you name the environment variables a server
needs, and the values are stored separately from the server's configuration.

## The gateway

The desktop app and the web UI talk to a local gateway. It:

- **binds loopback** unless explicitly told otherwise, so it is not exposed to
  the network by accident
- **requires a token** on every connection, generated per run and printed
  once, so another local user — or a web page in your browser — cannot drive it

A client of this gateway can make the agent run commands on the machine
hosting it. That is the whole point, and it is why the token exists.

**It is single-user by design.** Serving several untrusted people would need
per-user sandboxing, which is out of scope.

## Paired phones

Pairing hands a device a token that lets it drive the agent on this machine.
The address is shown once. Pair only your own devices, and revoke anything you
do not recognise.

## The builds are not signed

No Apple or Microsoft certificate, so your operating system cannot tell who
built them and says so. That warning is correct and you should read it as
correct.

If you would rather not take our word for any of it, the source is
[here](https://github.com/ai-dashboad/opencli) and it is one `cargo build`.

## Reporting something

**Do not open a public issue for a security bug.** Use GitHub's
[private advisory form](https://github.com/ai-dashboad/opencli/security/advisories/new),
which reaches the maintainers without publishing anything.

The parts most worth looking at are the ones on this page: the sandbox policy,
the approval path, the directory check on background runs, and the gateway's
token.

Please do not include your keys, or logs that contain them.
