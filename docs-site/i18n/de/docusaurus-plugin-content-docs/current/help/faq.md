---
title: Häufige Fragen
sidebar_position: 1
---

# Fragen, die tatsächlich gestellt werden

## Werden meine Daten irgendwohin geschickt?

**An den Endpunkt, den Sie eingerichtet haben, und sonst nirgendwohin.** **Es gibt
kein Gateway von uns dazwischen**, kein Telemetriekonto und **keinen ins Binary
eingebackenen Schlüssel**.

Ist dieser Endpunkt ein Modell auf Ihrem eigenen Rechner, **verlässt gar nichts
den Rechner**.

## Funktioniert es offline?

**Ja, mit einem lokalen Modell.** Die Desktop-App sucht nach eigenen Updates und
das Models-Panel holt eine Liste beliebter Modelle — **beides scheitert ohne Netz
still, und beides wird für ein Gespräch nicht gebraucht**.

## Brauche ich einen API-Schlüssel?

**Nicht, wenn Sie ein Modell lokal betreiben.** Ollama, LM Studio, llama.cpp und
die übrigen verlangen nichts. Ein gehosteter Anbieter braucht seinen Schlüssel,
und der **liegt getrennt von der Konfigurationsdatei und wird nie wieder
angezeigt**.

## Welches Modell soll ich nehmen?

**Das, was Ihr Rechner fassen kann**, mit **einer harten Bedingung: es muss
Werkzeuge aufrufen.** Ein Modell, das das nicht tut, **ist hier auf Unterhaltung
beschränkt**.

[Ein Modell prüfen](/reference/checking-a-model) ist ein **Fünf-Minuten-Test**,
der das beantwortet. Die Tabelle dort ist kurz, weil **nur drinsteht, was
ausprobiert wurde**.

## Warum ist es schlechter als Claude Code / Codex?

**Weil ein 27B-Modell, quantisiert bis es auf ein Notebook passt, kein GPT-5
ist.** Die Oberfläche ist dieselbe; **das Denken nicht**.

**Was dieses Projekt ändert, ist die Reichweite** — ob das Modell, das Sie haben,
sich überhaupt so verwenden lässt — **nicht, wie klug es ist**.

## Kann es GPT-5 oder Claude nutzen?

**Ja.** Richten Sie OpenAI oder Anthropic ein wie jeden anderen Anbieter.
**Nichts im Produkt bevorzugt eines gegenüber dem anderen.**

## Wo beginnt ein Gespräch?

In `~/.opencli/workspace` — es sei denn, es gehört zu einer Abteilung, dann im
Verzeichnis dieser Abteilung.

**Früher war es Ihr Benutzerordner. Jetzt nicht mehr**, denn die beschreibbare
Wurzel der Sandbox **ist** das Arbeitsverzeichnis — siehe
[Sandbox und Freigaben](/configuration/sandbox-and-approvals).

## Können mehrere Leute eine Installation benutzen?

**Nein.** Das Gateway ist **von der Anlage her Einbenutzer-Software** und **sagt
das im eigenen Quelltext**. **Jede Person betreibt ihre eigene Kopie**; ein
**gemeinsamer Modellserver dahinter** ist die übliche Anordnung.

## Läuft geplante Arbeit, während mein Notebook schläft?

**Nein.** Geplante Aufgaben und Dienste laufen **nur, solange OpenCLI offen ist**,
denn **dies ist ein lokaler Agent und kein Server**. Alles, was bei schlafendem
Rechner auslösen muss, gehört in `cron`, `launchd` oder die Aufgabenplanung.

## Wie unterscheidet sich das von Open WebUI oder Jan?

**Das sind Chat-Oberflächen für lokale Modelle, und gute.** **Dies ist ein
Agent**: Er liest und bearbeitet Ihre Dateien, führt Befehle aus und **arbeitet im
Hintergrund weiter**. **Andere Aufgabe — es spricht nichts dagegen, beides zu
betreiben.**

## Wie unterscheidet sich das von Codex, aus dem es geforkt wurde?

**Codex ist für OpenAIs Modelle gebaut.** Abteilungen, Bots, Dienste,
Hintergrundläufe, Übergaben zwischen Bots, die mitgelieferten Abläufe und die
zehn Oberflächensprachen **stammen von dieser Seite des Forks**, zusammen mit
**einer Menge Arbeit daran, was kaputtgeht, wenn das Modell klein ist**.

## Warum heißt es, die App sei beschädigt / nicht verifiziert?

**Weil die Builds kein Apple- oder Microsoft-Zertifikat tragen** — die **kosten
jedes Jahr Geld, und dieses Projekt hat es nicht ausgegeben**.
[Installation](/getting-started/install) sagt genau, worauf zu klicken ist.

## Kann ich ändern, wie es heißt?

**Noch nicht.** Die Marke ist einkompiliert.

## Etwas ist kaputt. Wo schaue ich nach?

[Fehlersuche](/help/troubleshooting), dann die Protokolle in `~/.opencli/log`,
dann [ein Ticket](https://github.com/ai-dashboad/opencli/issues).
