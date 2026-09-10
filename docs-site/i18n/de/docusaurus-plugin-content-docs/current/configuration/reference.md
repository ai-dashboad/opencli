---
title: Vollständige Konfigurationsreferenz
sidebar_position: 4
---

# Vollständige Konfigurationsreferenz

Jeder Schlüssel, den `~/.opencli/config.toml` akzeptiert. Für **die Handvoll, die
die meisten Leute anfassen**, ist
[die Konfigurationsdatei](/configuration/config-file) kürzer.

### Der schnellste Weg: OpenCLI Ihre Modelle finden lassen

Wenn bei Ihnen schon Ollama, LM Studio, vLLM oder llama.cpp lokal läuft:

```shell
opencli provider scan
```

**Das klopft die üblichen localhost-Ports ab**, fragt jeden gefundenen Server,
welche Modelle er ausliefert, und schreibt die passenden `[model_providers.*]`-
und `[[models]]`-Abschnitte in Ihre `config.toml` — **vorhandene Kommentare und
Einstellungen bleiben erhalten**. Mit `--dry-run` sehen Sie vorher, was es
schreiben würde.

Für gehostete Anbieter installieren Sie einen aus dem Katalog und setzen seinen
Schlüssel:

```shell
opencli provider list          # der Katalog, plus was schon eingerichtet ist
opencli provider add openrouter
export OPENROUTER_API_KEY=...
```

**Der Katalog enthält nur Verbindungsangaben**: mit der Binärdatei kommt kein
Schlüssel mit, und **nichts ist aktiv, bis Sie es hinzufügen**. Um etwas
einzurichten, das nicht im Katalog steht, schreiben Sie die Abschnitte wie unten
beschrieben von Hand.

#### Die Fähigkeiten eines Modells nachtragen

**Kontextfenster und Werkzeugaufruf-Unterstützung eines lokalen Modells sind
nirgends veröffentlicht**, und **Raten ist schlimmer, als sie leer zu lassen**:
Ein zu großes Kontextfenster führt dazu, dass der Anbieter Züge **ablehnt**,
statt automatisch zu verdichten. **Fragen Sie stattdessen das Modell**:

```shell
opencli model probe <slug>            # mit --dry-run zur Vorschau
```

**Das liest die Metadaten der Laufzeitumgebung selbst, sofern vorhanden**
(**Ollama meldet die echte Kontextlänge und die Fähigkeitsliste**) und stellt
zusätzlich **eine echte Anfrage**, um zu sehen, ob das Modell ein angebotenes
Werkzeug aufruft und ob es sein Denken in einem eigenen `reasoning`-Feld
zurückgibt. Die Befunde werden in den `[[models]]`-Eintrag des Modells
geschrieben.

**Modelle, die überhaupt nicht chatten können** — etwa Embedding-Modelle —
**überspringt `provider scan`**, sie erreichen die `/model`-Auswahl also nie.

### Modelle und Anbieter wählen

Dieser Build bringt Voreinstellungen für mehrere Gateways mit, aber **jedes über
eine OpenAI-kompatible API erreichbare Modell lässt sich** in
`~/.opencli/config.toml` **ohne Neubau konfigurieren**.

#### Einen Anbieter hinzufügen

Einträge unter `[model_providers.<id>]` **überschreiben einen eingebauten Anbieter
gleicher id** — **so leitet man also auch ein mitgeliefertes Gateway auf einen
Proxy oder Spiegel um**:

```toml
[model_providers.my-gateway]
name = "My Gateway"
base_url = "https://gateway.example.com/v1"
env_key = "MY_GATEWAY_API_KEY"
wire_api = "chat"
# Optional: erhöhen, wenn dieses Gateway lange bis zum ersten Token braucht.
stream_idle_timeout_ms = 90000
```

**API-Schlüssel werden immer aus der Umgebung gelesen; sie werden nie in der
Konfigurationsdatei gespeichert.**

#### Ein Modell hinzufügen

Deklarieren Sie Modelle mit `[[models]]`. Sie erscheinen in der `/model`-Auswahl
neben den eingebauten Voreinstellungen, und **ein Eintrag, dessen `model` einer
eingebauten Voreinstellung entspricht, ersetzt diese**:

```toml
[[models]]
model = "qwen3-max"
provider = "my-gateway"
display_name = "Qwen3 Max"     # optional, Standard ist der Slug
description = "Selbst betrieben." # optional
show_in_picker = true          # optional, Standard true
```

`provider` ist Pflicht und muss einen oben definierten oder einen eingebauten
Anbieter benennen; **ein Modell, das auf einen undefinierten Anbieter zeigt, wird
schon beim Start abgelehnt**, statt später mit einem sachfremden Fehler
umzufallen.

Um ein Modell zu wählen, ohne es in die Auswahl aufzunehmen, setzen Sie `model`
und `model_provider` direkt:

```toml
model = "qwen3-max"
model_provider = "my-gateway"
```

Benennt `model` etwas, das weder eine eingebaute Voreinstellung noch ein
`[[models]]`-Eintrag ist, und ist `model_provider` nicht gesetzt, **fallen
Anfragen auf den Anbieter `openai` zurück**, und eine Warnung wird protokolliert.

#### Kontextfenster

**Modelle, zu denen dieser Build keine Metadaten hat, beginnen mit einem
vorsichtigen Fenster von 131.072 Tokens** und **lernen das echte aus der ersten
Ablehnung wegen Kontextfenster** durch das Gateway. Setzen Sie
`model_context_window`, um es ausdrücklich festzuschreiben.

### Mit MCP-Servern verbinden

OpenCLI kann sich mit MCP-Servern verbinden, die in `~/.opencli/config.toml`
deklariert sind.

```toml
[mcp_servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env_vars = ["GITHUB_PERSONAL_ACCESS_TOKEN"]

[mcp_servers.internal]
url = "https://mcp.example.com/mcp"
```

`env_vars` benennt die Variablen, die der Server braucht; **die Werte liegen bei
Ihren anderen Schlüsseln und nicht in dieser Datei, die weitergegeben wird**. Ein
hier deklarierter Server startet **mit dem nächsten Chat, den Sie öffnen**, nicht
mit dem vor Ihnen.

Die Desktop-App schreibt dieselbe Tabelle über **Abilities → Connectors**, was
außerdem **den Handshake testet** und die Werkzeuge auflistet, die jeder Server
anbietet.

### Apps (Connectors)

Mit `$` im Eingabefeld fügen Sie einen ChatGPT-Connector ein; das Popover listet
erreichbare Apps. Der Befehl `/apps` listet verfügbare und installierte Apps.
**Verbundene Apps stehen vorn und sind als verbunden gekennzeichnet**; die
übrigen sind als installierbar markiert.

### Benachrichtigung

OpenCLI kann einen Benachrichtigungs-Hook ausführen, wenn der Agent einen Zug
beendet.

```toml
notify = ["/path/to/your/script.sh"]
```

Das Programm wird mit einem Argument aufgerufen: **einem JSON-Objekt, das
beschreibt, was passiert ist**. **Es läuft abgekoppelt, ein langsames Skript hält
also den nächsten Zug nicht auf**, und ein Skript, das fehlschlägt, wird
protokolliert statt in den Vordergrund geholt.

### JSON-Schema

Das erzeugte JSON-Schema für `config.toml` liegt unter
[`opencli-rs/core/config.schema.json`](https://github.com/ai-dashboad/opencli/blob/main/opencli-rs/core/config.schema.json)
und **wird mit jedem Release als `config-schema.json` hochgeladen**. Richten Sie
Ihren Editor darauf, dann haben Sie Vervollständigung und Prüfung, während Sie
die Datei von Hand bearbeiten.

**Es wird aus den Rust-Typen erzeugt, und die CI schlägt fehl, wenn es von ihnen
abweicht** — es ist damit **die einzige Beschreibung dieser Datei, die nicht
veralten kann**.

### Hinweise

OpenCLI speichert „Nicht mehr anzeigen“-Merker für einige Oberflächenhinweise
unter der Tabelle `[notice]`.

Das Beenden mit Strg+C/Strg+D nutzt einen Doppeldruck-Hinweis von etwa einer
Sekunde (`ctrl + c again to quit`).
