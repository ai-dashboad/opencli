---
title: Install
sidebar_position: 1
---

# Install

## Desktop app

Download it from [opencli.ai/download](https://opencli.ai/download.html), or
take it straight from the latest release:

| Platform | File |
| --- | --- |
| macOS, Apple Silicon | `OpenCLI-macos-aarch64.dmg` |
| macOS, Intel | `OpenCLI-macos-x86_64.dmg` |
| Windows | `OpenCLI-windows-x86_64-setup.exe` |
| Linux | `OpenCLI-linux-x86_64.AppImage` |

The app updates itself after that.

### Your computer will warn you the first time

These builds are **not signed** with an Apple or Microsoft certificate. Those
cost money per year and this project has not spent it. Nothing is wrong with
the download; the operating system cannot tell who built it.

**macOS** — after dragging OpenCLI to Applications, either run once:

```shell
xattr -dr com.apple.quarantine /Applications/OpenCLI.app
```

or right-click the app, choose **Open**, and confirm. Only the first launch.

**Windows** — SmartScreen shows a blue box. Click **More info**, then
**Run anyway**.

## Command line

One binary, macOS and Linux:

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

It works out your platform, fetches the matching build, and puts `opencli` in
`/usr/local/bin` — or in `~/.local/bin` if it cannot write there, telling you
to add it to your `PATH`.

The npm package is not published yet — the `@ai-dashboad` scope is not
registered. Until it is, the installer above and the desktop builds are the
two routes.

## From source

A recent Rust toolchain:

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

The binary lands at `opencli-rs/target/release/opencli`.

## What it wrote where

| | |
| --- | --- |
| `~/.opencli/config.toml` | providers, models, approval and sandbox settings |
| `~/.opencli/workspace/` | where a conversation starts when nothing else says |
| `~/.opencli/skills/` | skills, including the ones that ship |
| `~/.opencli/locales/` | languages you add |
| `~/.opencli/log/` | logs |

Nothing is written outside `~/.opencli` until you point the agent at a
directory.

## Next

[Point it at a model](/getting-started/point-at-a-model) — it ships without
one, and will not answer until it has somewhere to ask.
