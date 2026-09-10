---
title: Sprachen
sidebar_position: 3
---

# Eine Sprache hinzufügen

**Zehn Übersetzungen kommen mit OpenCLI**: English, 简体中文, 繁體中文, 日本語,
한국어, Español, Português (Brasil), Français, Deutsch und Русский.

**Jede weitere Sprache ist eine Datei** — und eine Korrektur an einer der zehn
ebenso.

## Über die Oberfläche

**Customize → Language → Add a language file…** nimmt eine `.json`-Datei entgegen
und behält sie. **Sie erscheint sofort in der Auswahl.**

## Von Hand

Dieselbe Datei, in `~/.opencli/locales`, nach der Sprache benannt:

```
~/.opencli/locales/nl.json
```

**Beide Wege schreiben an dieselbe Stelle**, was über die Oberfläche hinzugefügt
wurde, lässt sich also danach von Hand bearbeiten oder auf einen anderen Rechner
kopieren.

## Was darin steht

**Jeder Eintrag ist ein englischer Satz genau so, wie er in der Oberfläche
erscheint** — und daneben, was stattdessen gezeigt werden soll:

```json
{
  "name": "Nederlands",
  "strings": {
    "Dispatch": "Verzenden",
    "Scheduled tasks": "Geplande taken",
    "Runs ({count})": "Uitvoeringen ({count})"
  }
}
```

`name` ist, was die Sprachauswahl anzeigt. Fehlt er, wird der Dateiname benutzt.
**Die bloße Zuordnung funktioniert auch, ohne die Hülle**:

```json
{ "Dispatch": "Verzenden" }
```

## Mit einer mitgelieferten anfangen

Die mitgelieferten Übersetzungen sind dieselbe Art Datei, in
[`web/src/locales/`](https://github.com/ai-dashboad/opencli/tree/main/web/src/locales).
**Kopieren Sie eine, ersetzen Sie die rechte Seite jeder Zeile** — und Sie haben
**einen vollständigen Ausgangspunkt** statt einer Liste von Sätzen, die man erst
zusammensuchen muss.

Um jeden Satz zu sehen, den die Oberfläche verwendet:

```
python3 scripts/i18n-check.py
```

## Platzhalter

`{name}` in einem Satz wird gefüllt. **Behalten Sie dieselben Platzhalter, in der
Reihenfolge, die Ihre Sprache will** — **dieses Umstellen ist der halbe Grund,
warum es sie gibt**:

```json
{ "Allowed {count} of {total}": "{count} von {total} erlaubt" }
```

## Pluralformen

`plural()` wählt **zwischen zwei Formen**. Für Englisch, Deutsch, Spanisch,
Französisch und Portugiesisch reicht das; **die dritte Form, die Russisch für
2–4 verlangt, hat es nicht**. Wo eine Sprache mehr als zwei Formen braucht,
**schreiben Sie den Satz so, dass die Zahl den Sinn allein trägt** —
`запусков: {count}` statt eines Substantivs, das sich danach richten muss.

**Chinesisch, Japanisch und Koreanisch nehmen die Singularform und lassen die
Zahl die Arbeit machen**; das ist bereits erledigt.

## Eine mitgelieferte Übersetzung korrigieren

**Eine Datei, die nach einer bereits mitgelieferten Sprache benannt ist, wird mit
ihr zusammengeführt, nicht an ihre Stelle gesetzt.** Um einen Satz zu ändern,
schreiben Sie einen Eintrag:

```json
{ "Dispatch": "Verteilen" }
```

**Alles Übrige behält den mitgelieferten Wortlaut.**

## Wann es wirkt

Eine über die Oberfläche hinzugefügte Datei gilt **sofort**. Eine von Hand ins
Verzeichnis gelegte **wird gelesen, wenn sich ein Fenster verbindet** — öffnen Sie
das Fenster also neu. **Eine Datei, die sich nicht parsen lässt, wird
übersprungen**, mit einer Zeile im Gateway-Protokoll — **die anderen Sprachen sind
nicht betroffen**.

## Nicht übersetzte Sätze

**Ein Satz ohne Eintrag wird auf Englisch gezeigt**, eine teilweise Übersetzung
liest sich also als Mischung und nicht als **Bildschirm voller Lücken**. **Man muss
sie nicht fertigstellen, damit sie nützt.**

## Von rechts nach links

Arabisch, Hebräisch und Persisch sind nicht unter den mitgelieferten
Übersetzungen, und **eines davon als Datei hinzuzufügen ergibt eine Seite, die von
links nach rechts gesetzt ist**. Die Oberfläche behandelt `dir="rtl"` noch nicht;
**das ist eine Änderung am Stylesheet, nicht an einer Übersetzungsdatei**.
