---
title: Connectors
sidebar_position: 5
---

# Connectors

A connector is an MCP server the agent can call tools through — GitHub, a
database, a browser, your files. It is how the agent reaches something that is
not a file on this machine.

## Adding one

**Abilities → Connectors** lists what is configured and what can be added.
Adding from the catalogue takes one click; adding your own takes a name and
either a command or a URL:

| | |
| --- | --- |
| **Local command** | a program on this machine, started by OpenCLI |
| **HTTP server** | a server reachable over HTTP |

## Keys

Most connectors need one. Name the environment variables the server expects —
names only, separated by spaces — and set the values afterwards.

**Values are kept with your other keys, not in the connector's
configuration**, and are never shown again once saved. That is deliberate: the
configuration file gets shared and pasted into issues, and a key in it goes
with it.

## Testing

**Test connections** starts every configured server and waits for a handshake.
It is a button rather than something that happens when the panel opens,
because starting them takes seconds — measured at 2.2 against one that fails
to authenticate.

The result appears on each row, with the tools that server offers.

## When a change takes effect

Servers start with a chat. A connector added now applies to the **next**
conversation you open, not the one in front of you.

## What a connector is not

It is not a capability the model gains. A model that will not call tools does
not start calling them because a connector was added — see
[Limits](/reference/limits).

## Departments

The chips above the list filter by department, so a newly created Finance
department can be asked *what should this be connected to* rather than
*what is Playwright*.

A connector with no department tag shows under every chip: something nobody
has categorised should not be hidden from everybody.
