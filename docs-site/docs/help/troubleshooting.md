---
title: Troubleshooting
sidebar_position: 2
---

# Troubleshooting

## It says the credentials were refused

```
The model provider would not accept the request without credentials.
(status 401 Unauthorized)
```

Either no key is set for the provider you selected, or the one set is not
valid for it. Three things to check, in order:

1. **Which provider is actually selected** — `model` in `config.toml`, or the
   picker in the composer. Pointing at a model whose provider you never
   configured is the common cause.
2. **The environment variable named by `env_key`** is set in the shell the
   agent runs in. The desktop app reads it from where it keeps your keys, not
   from your shell.
3. **The key belongs to that provider.** A key for one is not a key for
   another.

A 401 is not retried, deliberately: credentials do not become valid by being
offered again.

## The model list is empty

The **Models** panel and the composer's picker both come from the provider's
`/v1/models`. An empty list means that request failed, and the reason is in
`~/.opencli/log`.

A provider that requires a key returns nothing without one, so this and the
401 above are usually the same problem.

## It answers, but never touches my files

Your model is not calling tools. That is the single most common
disappointment, and it is not a configuration mistake — some models simply do
not.

[Check it](/reference/checking-a-model). Five minutes, one fixed task. If it
fails, the model is the wrong tool for this and no setting will change that.

## It runs `grep` instead of reading the file properly

The same underlying gap, in a milder form: a model not trained toward agentic
work reaches for the shell even when a file tool is in front of it. Nothing in
the interface closes it.

## A background run says it is waiting for me

Its working directory is not one this product knows about — not the workspace,
not a department's directory, and not somewhere you have allowed by name.

Either **Allow this directory** in the Dispatch panel, or **Move** the task to
a department. The reason it is held rather than run is that a run may write
anywhere inside its directory.

## A scheduled task never ran

Two possibilities:

- **OpenCLI was closed.** Scheduled work runs only while it is open.
- **It is held**, as above. Held tasks appear under *Waiting for you*.

## The conversation keeps summarising itself

If it summarises and immediately needs to again, the length is not coming from
the conversation — it is the fixed part of every request, which is mostly the
tool schemas of your connectors. Four connectors can be ten thousand tokens
before you have said anything.

It says so once, rather than doing it every turn. Turning off connectors you
are not using in that conversation is the fix.

## The desktop app will not open

**macOS**: run `xattr -dr com.apple.quarantine /Applications/OpenCLI.app`, or
right-click → **Open**.

**Windows**: SmartScreen → **More info** → **Run anyway**.

If it still refuses, the download may be incomplete — check the file size
against the release page.

## The agent did something I did not see

**Artifacts** lists only edits made with the agent's file-editing tool. Files
written by a shell command it ran — a heredoc, a script, `git checkout` — are
real changes that will not appear there.

`git status` in the working directory is the reliable answer.

## The interface is in English when I chose another language

A dictionary is fetched when its language is chosen, so there is a moment
where the English shows. If it stays English, the chunk did not load — check
the browser console in the desktop app's developer tools.

A sentence with no translation always shows English by design; that is a
partial translation, not a fault.

## Where the logs are

```
~/.opencli/log
```

**Settings → About → Logs** opens the directory. When reporting a problem, the
last fifty lines around the failure are almost always enough — and check them
for keys before pasting.
