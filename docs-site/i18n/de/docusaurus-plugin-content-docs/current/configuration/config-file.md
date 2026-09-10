---
title: Die Konfigurationsdatei
sidebar_position: 1
---

# Die Konfigurationsdatei

`~/.opencli/config.toml`. **Alles hier hat einen Standardwert**; die Datei
enthält nur, **was Sie geändert haben**.

**Die Desktop-App schreibt dieselbe Datei und behält Ihre Kommentare und
Formatierung**, also sind **Bearbeiten von Hand und Bearbeiten in Settings
dasselbe**.

## Anbieter und Modelle

**Ein Anbieter ist eine Basis-URL und der Name einer Umgebungsvariable, die den
Schlüssel enthält**:

```toml
[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

Darunter deklarierte Modelle erscheinen in der Auswahl:

```toml
model = "my-model"

[[models]]
slug = "my-model"
model = "provider-side-model-id"
provider = "my-provider"
display_name = "My Model"
context_window = 128000
reasoning_efforts = ["low", "medium", "high"]
```

`slug` ist, **was Sie tippen**; `model` ist, **wie der Anbieter es nennt**. **Sie
weichen oft genug voneinander ab, dass sich das Trennen lohnt.**

**Sie müssen sie nicht deklarieren.** Modelle werden vom `/v1/models` des
Anbieters geholt. Eines zu deklarieren dient dazu, **ein Kontextfenster, einen
Anzeigenamen oder die akzeptierten Denkstufen festzunageln**.

## Freigaben und Sandbox

```toml
approval_policy = "on-failure"   # untrusted | on-failure | never
sandbox_mode = "workspace-write" # read-only | workspace-write | danger-full-access
```

Erklärt in [Sandbox und Freigaben](/configuration/sandbox-and-approvals).

## Werkzeug-Ausgaben

```toml
tool_output_token_limit = 10000
```

**Ein Budget dafür, was die Ausgabe eines Werkzeugs dem Gespräch hinzufügen
darf.**

**Tokens werden geschätzt, nicht gezählt.** Der Tokenizer gehört zum Modell, und
**hier laufen Modelle, die es nie gesehen hat**. Die Schätzung lautet **vier
ASCII-Bytes je Token und sonst ein Token je Zeichen** — für Englisch wie für
Chinesisch nah dran und anderswo **eher zu hoch gegriffen**. Diesen Wert auf 500
zu setzen **schneidet nicht exakt bei 500 Tokens**; **es schneidet in der Nähe, in
denselben Einheiten, in denen die Zahl geschrieben ist**.

## Sehen, was gilt

**Settings** zeigt **jeden geltenden Wert und woher er kommt**, auch **die, die
Sie nie gesetzt haben**. `Show raw config` ist die Datei selbst.

## Die vollständige Referenz

Jeder Schlüssel, den diese Datei akzeptiert, mit seinem Standardwert:
[Vollständige Konfigurationsreferenz](/configuration/reference).
