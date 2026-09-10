---
title: Erstes Gespräch
sidebar_position: 3
---

# Erstes Gespräch

## Wo es beginnt

Ein neuer Chat öffnet in `~/.opencli/workspace` — es sei denn, er gehört zu
einer Abteilung, dann öffnet er im Verzeichnis dieser Abteilung.

**Das zählt mehr, als es aussieht.** Die Sandbox des Agenten darf überall in
ihrem Arbeitsverzeichnis schreiben, also ist **das Verzeichnis, in dem ein
Gespräch geöffnet ist, alles, was es ändern kann**. Früher war Ihr
Benutzerordner der Standard; das ist er nicht mehr, und der Grund steht in
[Sandbox und Freigaben](/configuration/sandbox-and-approvals).

Ändern lässt es sich mit der Ordner-Schaltfläche über dem Eingabefeld.

## Um etwas bitten

Gewöhnliche Sätze. Der Agent hat Ihre Dateien, eine Shell und alle
[Connectors](/doing-work/connectors), die Sie hinzugefügt haben:

```
Lies invoices.csv und liste jede Zeile, die gegen die Regeln in rules.md verstößt
```

```
Was hat sich in diesem Repository in der letzten Woche geändert?
```

```
Vergleiche their-draft.md mit our-terms.md und liste jede abweichende Klausel
```

## Was passiert, bevor etwas geändert wird

Standardmäßig **zeigt der Agent einen Befehl, der nicht als sicher bekannt ist,
bevor er ihn ausführt**, und **zeigt einen Schreibvorgang, bevor er ihn
vornimmt**. Sie geben jeden einzeln frei oder lehnen ihn ab.

Drei Einstellungen, unter **Customize**:

| | |
| --- | --- |
| **Bei allem Unbekannten fragen** | jeder nicht als sicher bekannte Befehl wird vorher gezeigt |
| **Erst fragen, wenn etwas fehlschlägt** | Befehle laufen unbeaufsichtigt; gefragt wird, wenn einer mehr Zugriff braucht |
| **Nie fragen** | vor der Ausführung wird nichts gezeigt |

Das Letzte ist für ein Verzeichnis gedacht, **in dem Sie ein Skript frei laufen
lassen würden**. Ordentlich erklärt wird es in
[Sandbox und Freigaben](/configuration/sandbox-and-approvals).

## Sehen, was er getan hat

**Artifacts** listet die Dateien, die der Agent in diesem Gespräch bearbeitet
hat, samt Diffs. Eine ehrliche Grenze: **aufgeführt werden nur Änderungen, die
mit dem Datei-Werkzeug des Agenten gemacht wurden**. Dateien, die ein von ihm
ausgeführter Shell-Befehl geschrieben hat — ein Heredoc, ein Skript,
`git checkout` — werden nicht erfasst und tauchen dort nicht auf.

## Wenn es nicht mehr hineinpasst

Ein lang gewordenes Gespräch **wird zusammengefasst, damit es weiter
hineinpasst**. Sie sehen **Summarising the conversation…**, und danach läuft der
Verlauf mit einer Zusammenfassung anstelle der älteren Züge weiter.

**Wenn Zusammenfassen nicht helfen kann** — weil die Länge von den
Werkzeug-Schemata kommt und nicht vom Gespräch — **sagt er das einmal, statt es
in jedem Zug erneut zu versuchen**.

## Weiter

**Ein Gespräch ist ein Gespräch.** Damit Arbeit auch ohne Sie passiert,
[richten Sie eine Abteilung ein](/doing-work/departments-and-bots).
