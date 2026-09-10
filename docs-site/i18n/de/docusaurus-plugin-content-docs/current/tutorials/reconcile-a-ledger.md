---
title: Ein Hauptbuch abgleichen
sidebar_position: 1
---

# Ein Hauptbuch abgleichen, von Anfang bis Ende

**Zwanzig Minuten, mit einem lokalen Modell.** Am Ende haben Sie **eine Abteilung,
die jeden Morgen zwei Dateien gegeneinander prüft und anhält, um Sie zu fragen,
sobald sie etwas oberhalb einer von Ihnen gesetzten Schwelle findet**.

**Alles hier verwendet die mitgelieferten Beispieldaten**, es muss also **nichts
vorbereitet werden**.

## 1. Die Abteilung anlegen

**Projects → oder mit einer anfangen, die schon läuft → Finance.**

Sie legt `~/.opencli/workspace/finance` an, schreibt drei Dateien hinein und
stellt zwei Bots ein.

**In die Dateien sind absichtlich Probleme eingebaut**:

| Datei | Was darin steht |
| --- | --- |
| `ledger.csv` | was Ihre Bücher sagen |
| `statement.csv` | was die Bank sagt |
| `overdue.csv` | überfällige Rechnungen |

## 2. Einmal von Hand fragen

Öffnen Sie die Abteilung und tippen Sie:

```
Vergleiche ledger.csv mit statement.csv. Liste jede Zeile, die nicht
übereinstimmt, mit Referenz und Betrag, und sag, was deiner Meinung nach
passiert ist.
```

**Sehen Sie zu, was passiert.** Ein dafür geeignetes Modell **liest beide Dateien
mit einem Werkzeug** und **antwortet mit Zeilen und Referenzen**. Ein
ungeeignetes **bittet Sie, den Inhalt einzufügen, oder antwortet in
Allgemeinplätzen** — wenn das geschieht, **liegt es am Modell, nicht an der
Einrichtung**. [Prüfen Sie es](/reference/checking-a-model).

## 3. Daraus einen Dienst machen

**Der Bot hat es einmal getan.** Ein Dienst sorgt dafür, dass es **von selbst
wiederkommt**.

Öffnen Sie den Bot **Reconciler** und stellen Sie seinen Dienst ein:

| Feld | Was hineingehört |
| --- | --- |
| **Was** | Vergleiche `ledger.csv` mit `statement.csv`, Zeile für Zeile. Liste, was nicht übereinstimmt, mit Referenz und Betrag. |
| **Regeln** | Eine Differenz unter 1,00 ist Rundung. Ignorieren. |
| **Eskalieren wenn** | Eine einzelne Zeile über 10.000 liegt. |
| **Alle** | 24 Stunden |

**„Regeln“ und „Was“ sind aus einem Grund getrennt**: Die Arbeit ist jeden Morgen
dieselbe, und **die Schwelle ist eine Richtlinie, die jemand wieder anfasst**. In
einen Prompt verschmolzen heißt eine Änderung der Zahl, **die ganze Anweisung noch
einmal zu lesen, um sie zu finden**.

## 4. Zusehen, wie er anhält

**Run now.** **Die Beispieldaten enthalten eine Abweichung oberhalb der
Schwelle**, der Dienst wird also nicht fertig — **er erscheint unter Bots → Wartet
auf Sie mit der Frage, die er nicht beantworten konnte**.

**Genau darum geht es bei dieser Funktion.** Er hat die Arbeit getan, **die von
Ihnen gezogene Linie erreicht und angehalten, statt zu entscheiden**.

Antworten Sie ihm. **Ihre Antwort wird in den nächsten Lauf mitgenommen**, er
fragt dasselbe also nicht zweimal.

## 5. Das Ergebnis weiterreichen

Die Abteilung Finanzen bringt einen zweiten Bot mit, **Chaser**. Haken Sie ihn in
der Liste **darf übergeben an** des Reconciler an.

Jetzt kann ein Lauf, der nicht übereinstimmende Zeilen findet, sie weitergeben —
**samt dem, was er getan hat, und den Dateien, die er erzeugt hat** — und der
Chaser **entwirft je Kunde eine Mahnmail, ohne dass ihm der Hintergrund erzählt
wird**.

**Bots → Zwischen Bots übergebene Arbeit** zeigt die Kette danach und **markiert
die, die stehen blieb, weil ihr die Sprünge ausgingen**, statt weil sie fertig
war.

## Was Sie jetzt haben

- **ein Verzeichnis, in das der Agent schreiben darf, und sonst nirgends**
- **Arbeit, die passiert, ohne dass Sie sie starten**
- **eine geschriebene Schwelle, an der er anhält und fragt**
- **einen zweiten Bot, der aufnimmt, wo der erste aufgehört hat**

## Was Sie zuerst ändern sollten

**Die Schwelle.** 10.000 **ist eine Zahl aus einem Beispiel. Ihre ist es nicht.**

**Die Regeln.** „Eine Differenz unter 1,00 ist Rundung“ **stimmt für manche
Bücher und für andere nicht**.

**Das Intervall.** Alle 24 Stunden **ist eine Gewohnheit, kein Gesetz**. **Ein
Dienst, der läuft, nachdem die Bank gebucht hat, nützt mehr als einer, der um
Mitternacht läuft.**
