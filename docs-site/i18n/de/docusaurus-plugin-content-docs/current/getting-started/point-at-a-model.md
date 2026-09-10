---
title: Auf ein Modell zeigen
sidebar_position: 2
---

# Auf ein Modell zeigen

**OpenCLI bringt weder Modell noch Schlüssel mit.** Bei einer frischen
Installation sagt der erste Bildschirm genau das und bietet die beiden Wege
unten an.

**Das ist keine Liste von Integrationen, sondern ein einziges Protokoll.** Alles,
was auf `/v1/chat/completions` und `/v1/models` so antwortet wie OpenAI, kann
angesprochen werden, und **seine Modelle erscheinen von selbst in der Auswahl**.
Sie müssen sie nicht einzeln deklarieren.

## Auf diesem Rechner

Die Desktop-App kann eines für Sie installieren: Öffnen Sie **Models**, und sie
schaut nach, **was schon auf dem Rechner ist**, bevor sie anbietet, etwas zu
holen.

Von Hand, mit bereits laufendem [Ollama](https://ollama.com):

```toml
model = "qwen3-coder"

[model_providers.ollama]
name = "Ollama"
base_url = "http://localhost:11434/v1"
wire_api = "chat"

[[models]]
slug = "qwen3-coder"
model = "qwen3-coder:30b"
provider = "ollama"
context_window = 32768
```

Legen Sie das in `~/.opencli/config.toml` und starten Sie `opencli`.

**Nichts verlässt den Rechner, und es gibt keinen Schlüssel aufzubewahren.**

## Ein Anbieter

**Alle funktionieren gleich.** Das Muster ist eine Basis-URL und der Name einer
Umgebungsvariable, die den Schlüssel enthält:

```toml
model = "my-model"

[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

```shell
export MY_PROVIDER_API_KEY=...
opencli
```

In der Desktop-App macht man dasselbe unter **Settings**, wo der Schlüssel
**gespeichert und nie wieder angezeigt wird**.

### Kostenlose Kontingente sind der billigste Weg, ein großes Modell zu probieren

Mehrere Anbieter geben etwas her, und so lässt sich ein Modell betreiben, das
**weit größer ist, als Ihr Rechner es fassen könnte**. Was kostenlos ist,
ändert sich von Monat zu Monat, deshalb nennt diese Seite keine Beträge:
**sehen Sie auf deren eigenen Preisseiten nach**.

Die [README](https://github.com/ai-dashboad/opencli#where-the-model-comes-from)
führt die vollständige Anbieterliste, **jeder Eintrag geprüft, indem nach seiner
Modellliste gefragt wurde**.

## Ein Modell kommt nicht unbedingt von der Firma, die es gebaut hat

Xiaomi veröffentlicht MiMo, ByteDance veröffentlicht Seed, und **keine von
beiden betreibt einen eigenen öffentlichen OpenAI-kompatiblen Endpunkt**. Beide
werden von anderen geführt — MiMo erreichen Sie also über OpenRouter, Novita,
DeepInfra, PPIO oder Hugging Face, nicht über Xiaomi.

## Erreichbar zu sein heißt nicht, darin gut zu sein

**Ein Anbieter, der die OpenAI-API beantwortet, aber ihren Werkzeugaufruf-Teil
nicht, wird sich unterhalten und wenig sonst**: Dieser Agent arbeitet, indem er
Werkzeuge aufruft. Bevor Sie sich auf ein Modell festlegen,
[prüfen Sie es](/reference/checking-a-model) — **fünf Minuten, eine feste
Aufgabe**.

## Weiter

[Ihr erstes Gespräch](/getting-started/first-conversation).
