---
title: Grenzen
sidebar_position: 2
---

# Grenzen

**Hier gesagt, statt später entdeckt.**

## Die Modelle

**Ein kleines lokales Modell ist darin nicht so gut wie ein Spitzenmodell.** Die
Oberfläche ist dieselbe; **das Denken nicht**.

**Allgemeine offene Modelle greifen zu `grep`, obwohl sie ein Datei-Werkzeug
haben.** Auch mit einem strukturierten Weg, eine Datei zu lesen, **weicht ein
nicht auf Agentenarbeit trainiertes Modell in die Shell aus**. **Das ist eine
Lücke in den Modellen, und keine Oberfläche schließt sie.** **Was dieses Projekt
ändern kann, ist die Reichweite, nicht die Intelligenz.**

**Ein Modell, das keine Werkzeuge aufruft, kann diese Arbeit überhaupt nicht.** Es
wird sich unterhalten. [Prüfen Sie Ihres](/reference/checking-a-model), bevor Sie
sich festlegen — fünf Minuten, eine feste Aufgabe.

## Das Zählen

**Tokenzahlen werden geschätzt, nie gezählt.** Der Tokenizer gehört zum Modell,
und **hier laufen Modelle, die es nie gesehen hat**. Vier ASCII-Bytes je Token,
sonst ein Token je Zeichen: **nah dran für Englisch wie für Chinesisch**, und
anderswo **eher zu hoch gegriffen**.

**Alles Nachgelagerte ist damit ungefähr**: wann ein Gespräch zusammengefasst
wird, wann die Ausgabe eines Werkzeugs abgeschnitten wird, und was die
Verbrauchszeile sagt.

## Die Zeitsteuerung

**Geplante Aufgaben und Dienste laufen nur, solange OpenCLI offen ist.** **Dies
ist ein lokaler Agent, kein Server.** Alles, was bei schlafendem Rechner auslösen
muss, gehört in **den Scheduler des Betriebssystems**.

## Die Sandbox

**Ein Hintergrundlauf darf alles innerhalb des Verzeichnisses schreiben, in dem er
läuft.** **Die beschreibbare Wurzel *ist* dieses Verzeichnis.** Läufe außerhalb
des Verzeichnisses einer Abteilung **werden zurückgehalten, bis Sie den Ort
namentlich freigeben** — **es sei denn, die Freigaben stehen auf never**, dann
wird nichts zurückgehalten.

**Lesezugriffe sind nie eingeschränkt**, in keinem Sandbox-Modus.

## Der Nachweis dessen, was sich geändert hat

**Artifacts listet nur Änderungen auf, die mit dem Datei-Werkzeug des Agenten
gemacht wurden.** Dateien, die ein von ihm ausgeführter Shell-Befehl geschrieben
hat — ein Heredoc, ein Skript, `git checkout` — werden nicht erfasst und tauchen
nicht auf. **Die Änderung ist echt; die Liste ist unvollständig.**

## Die Desktop-Builds

**Sie sind nicht signiert** — weder mit einem Apple- noch mit einem
Microsoft-Zertifikat. Ihr Betriebssystem wird Sie warnen, **und das zu Recht**:
**es kann nicht erkennen, wer sie gebaut hat**.
[Installation](/getting-started/install) sagt, was zu tun ist.

## Die Oberfläche

**Sprachen von rechts nach links werden nicht unterstützt.** Arabisch, Hebräisch
und Persisch lassen sich als Übersetzungsdateien hinzufügen, und **die Seite wird
weiterhin von links nach rechts gesetzt**. **Das ist eine Änderung am Stylesheet,
nicht an einer Übersetzung.**

## Eskalation ist eine Anweisung, keine Garantie

Das *Eskalieren wenn* eines Dienstes **wird dem Modell als Pflicht mitgegeben**.
**Es wird von diesem Produkt nicht ausgewertet**, ist also **genau so verlässlich
wie das Modell, das es liest**. Schreiben Sie es als etwas Prüfbares — *eine
einzelne Zeile über 10.000* — statt *irgendetwas Ungewöhnliches*.
