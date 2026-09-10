---
title: Hilfe bekommen
sidebar_position: 4
---

# Hilfe bekommen, und wo man etwas sagt

## Bevor Sie fragen

**Das meiste, was in der ersten Woche schiefgeht, steht in**
[Fehlersuche](/help/troubleshooting), und die Antwort auf *wird mein Anbieter
unterstützt* steht in [Anbieter](/getting-started/providers).

**Wenn der Agent redet, aber Ihre Dateien nie anfasst, liegt das fast immer am
Modell und nicht an der Einrichtung** — [prüfen Sie es](/reference/checking-a-model),
bevor Sie einen Abend in die Konfiguration stecken.

## Wo fragen

**[GitHub Issues](https://github.com/ai-dashboad/opencli/issues)** — Fehler, und
**alles, was sich anders verhalten hat, als die Dokumentation sagt**.

**[GitHub Discussions](https://github.com/ai-dashboad/opencli/discussions)** —
Fragen, Ideen und „ist das so gedacht“.

**Einen Chat-Server gibt es noch nicht.** Es wird einen geben, **wenn genug Leute
da sind, dass sich das Dasitzen lohnt**; **ein leerer Raum hilft niemandem**.

## Was einen Bericht leicht bearbeitbar macht

**Vier Zeilen** — und **die meisten Berichte haben sie nicht**:

1. **Modell und Anbieter, genau so benannt** — `qwen3-coder:30b` auf Ollama, nicht
   „ein lokales Modell“.
2. **Worum Sie gebeten haben**, wörtlich.
3. **Was passiert ist**, und **was Sie stattdessen erwartet hatten**.
4. **Die letzten fünfzig Zeilen aus `~/.opencli/log`** rund um den Fehlschlag.

**Sehen Sie diese Zeilen vor dem Einfügen auf Schlüssel durch.**

## Was am meisten hilft

**Eine Zeile in der Modelltabelle.**
[Ein Modell prüfen](/reference/checking-a-model) ist eine feste Aufgabe von etwa
fünf Minuten. **Die Tabelle ist kurz, weil nur drinsteht, was ausprobiert wurde**,
und **ein negatives Ergebnis ist so viel wert wie ein positives** — **niemand
schreibt über das Modell, das nicht ging, also entdeckt es jeder neu**.

**Eine Übersetzung, oder eine Korrektur an einer davon.** Zehn sind dabei. Jede
lässt sich **Zeile für Zeile korrigieren, ohne den Rest anzufassen** — siehe
[Sprachen](/configuration/languages).

**Uns sagen, was Sie eigentlich vorhatten.** Die mitgelieferten Abteilungen und
Abläufe **wurden aus Vermutungen darüber geschrieben, was Leute brauchen**.
**Wonach Sie gegriffen und es nicht gefunden haben, ist das Nützlichste, was Sie
sagen können.**

## Code beitragen

[Mitmachen](/reference/contributing) enthält die Einrichtung und den
Pull-Request-Ablauf.
