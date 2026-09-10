---
title: Fähigkeiten
sidebar_position: 4
---

# Fähigkeiten

**Eine Fähigkeit ist eine Sammlung von Anweisungen, auf die der Agent
zurückgreift, wenn eine Aufgabe danach verlangt**: ein einmal aufgeschriebenes
Verfahren, **statt jedes Mal in einen Prompt kopiert zu werden**.

## Was mitgeliefert wird

**Sechs Abläufe kommen mit dem Produkt und funktionieren in jedem Verzeichnis**:

| Fähigkeit | Was sie tut |
| --- | --- |
| `spreadsheet-review` | Prüft eine Datei mit Zeilen gegen die dort genannten Regeln und meldet die Zeilen, die dagegen verstoßen, **mit ihrer Zeilennummer** |
| `weekly-report` | Was sich hier in einem Zeitraum **tatsächlich geändert hat**: erledigt, in Arbeit, und was eine Entscheidung braucht |
| `inbox-triage` | Sortiert Nachrichten danach, worum sie bitten, und **markiert die, auf die ein Mensch antworten muss** |
| `document-compare` | Was sich **inhaltlich** zwischen zwei Entwürfen geändert hat, getrennt von dem, **was sich nur in der Formulierung geändert hat** |
| `meeting-notes` | Ein Protokoll wird zu Entscheidungen, Aufgaben mit Zuständigen und offenen Fragen |
| `records-review` | Hebt hervor, was in einem Satz Akten geprüft werden sollte, **und zitiert die Notiz, aus der es stammt** |

Zwei weitere, geerbte, handeln vom **Schreiben und Installieren von Fähigkeiten
selbst**: `skill-creator` und `skill-installer`.

## Woher sie kommen

| Geltungsbereich | Verzeichnis |
| --- | --- |
| Mitgeliefert | `~/.opencli/skills/.system` — wird beim App-Update neu geschrieben |
| Ihre eigenen | `~/.opencli/skills` |
| Die dieses Projekts | `.opencli/skills` im Arbeitsverzeichnis |

## Eine schreiben

Ein Verzeichnis mit einer `SKILL.md`, deren Front Matter sagt, was sie ist und
**wann sie zu benutzen ist**:

```markdown
---
name: invoice-check
description: Check invoices against our payment rules and report what breaks
  them. Use when asked to review, check or audit a file of invoices.
metadata:
  short-description: Find invoices that break the rules
---

# Invoice check

## Find the rules before reading the rows
...
```

**Die `description` ist das, womit der Agent eine Anfrage abgleicht.** Eine
Beschreibung, die nur sagt, was die Fähigkeit ***ist***, **überlässt es dem
Modell zu raten, wann sie greift** — **jede mitgelieferte Fähigkeit benennt ihre
Anlässe**, und Ihre sollte das auch.

## Was eine Fähigkeit funktionieren lässt

**Die sechs mitgelieferten zu lesen ist der schnellste Weg, die Form zu sehen**,
aber drei Dinge kehren wieder:

- **Sagen Sie, was zu lesen ist, und in welcher Reihenfolge.** „Das Älteste
  zuerst“ ist eine echte Anweisung; „sieh dir die Akten an“ ist keine.
- **Sagen Sie, was herauskommen soll.** Eine benannte Datei oder eine genannte
  Struktur. Nicht „eine Zusammenfassung“.
- **Sagen Sie, was sie nie tun darf.** Die mitgelieferte klinische Fähigkeit
  **verwendet darauf ein Drittel ihrer Länge**, und genau deshalb darf es sie
  geben.

**Eine schmerzhaft gelernte**: Wenn eine Zahl zählt, **sagen Sie, woher die Zahl
kommen muss**. Die Tabellen-Fähigkeit verlangt eine Zeilenzahl, und **der erste
Lauf nannte sie aus dem Gedächtnis und lag um eins daneben**. Jetzt verlangt sie,
**dass die Zahl aus dem Skript kommt, das die Prüfung gemacht hat**.

## Eine abschalten

Jede Fähigkeit hat einen Schalter unter **Abilities → Skills**. Eine Änderung
gilt für **den nächsten Chat, den Sie öffnen**, nicht für den bereits laufenden.
