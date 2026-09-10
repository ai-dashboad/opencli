---
title: Installation
sidebar_position: 1
---

# Installation

## Desktop-App

Laden Sie sie unter [opencli.ai/download](https://opencli.ai/download.html)
herunter oder holen Sie sie direkt aus dem neuesten Release:

| Plattform | Download |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

**Jeder Link zeigt immer auf das neueste Release**, funktioniert also weiter,
wenn sich die Versionen ändern.

Danach **aktualisiert sich die App selbst**.

### Beim ersten Mal warnt Sie Ihr Rechner

Diese Builds sind **nicht signiert** — weder mit einem Apple- noch mit einem
Microsoft-Zertifikat. Solche Zertifikate kosten jedes Jahr Geld, und dieses
Projekt hat es nicht ausgegeben. **Mit dem Download ist nichts verkehrt**: das
Betriebssystem kann nur nicht erkennen, wer ihn gebaut hat.

**macOS** — nachdem Sie OpenCLI in den Programme-Ordner gezogen haben, führen
Sie einmal aus:

```shell
xattr -dr com.apple.quarantine /Applications/OpenCLI.app
```

oder rechtsklicken Sie die App, wählen **Öffnen** und bestätigen. **Nur beim
ersten Start.**

**Windows** — SmartScreen zeigt einen blauen Kasten. Klicken Sie auf **Weitere
Informationen** und dann auf **Trotzdem ausführen**.

## Kommandozeile

Eine Binärdatei, macOS und Linux:

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

**Es ermittelt Ihre Plattform**, holt den passenden Build und legt `opencli`
nach `/usr/local/bin` — oder nach `~/.local/bin`, wenn es dort nicht schreiben
darf, mit dem Hinweis, es in Ihren `PATH` aufzunehmen.

**Das npm-Paket ist noch nicht veröffentlicht**: der Scope `@ai-dashboad` ist
nicht registriert. Bis dahin sind **der Installer oben und die Desktop-Builds
die beiden Wege**.

## Aus dem Quellcode

Eine aktuelle Rust-Toolchain:

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

Die Binärdatei landet unter `opencli-rs/target/release/opencli`.

## Was wohin geschrieben wurde

| | |
| --- | --- |
| `~/.opencli/config.toml` | Anbieter, Modelle, Freigabe- und Sandbox-Einstellungen |
| `~/.opencli/workspace/` | wo ein Gespräch beginnt, wenn nichts anderes gesagt ist |
| `~/.opencli/skills/` | Fähigkeiten, auch die mitgelieferten |
| `~/.opencli/locales/` | Sprachen, die Sie hinzufügen |
| `~/.opencli/log/` | Protokolle |

**Außerhalb von `~/.opencli` wird nichts geschrieben, bis Sie den Agenten auf
ein Verzeichnis richten.**

## Weiter

[Zeigen Sie ihm ein Modell](/getting-started/point-at-a-model) — es bringt
keines mit und **antwortet nicht, solange es niemanden zu fragen hat**.
