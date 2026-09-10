---
title: Einen Ordner beobachten
sidebar_position: 2
---

# Einen Ordner beobachten und melden, was sich geändert hat

**Zehn Minuten.** Am Ende haben Sie **etwas, das Ihnen in dem von Ihnen gewählten
Takt einen kurzen Bericht darüber schreibt, was sich in einem Verzeichnis getan
hat** — ein Projekt, ein gemeinsames Laufwerk, **ein Ordner, in den jemand
anderes ständig Dinge legt**.

## 1. Richten Sie einen Chat auf den Ordner

Öffnen Sie einen neuen Chat und wählen Sie das Verzeichnis über die
Ordner-Schaltfläche oberhalb des Eingabefeldes.

**Das zählt mehr, als es aussieht**: **Der Agent darf überall innerhalb des
Verzeichnisses schreiben, in dem ein Chat geöffnet ist**, und nirgends außerhalb.
**Den Ordner zu wählen heißt, den Wirkungsradius zu wählen.**

## 2. Bitten Sie einmal um den Bericht

```
Verwende die Fähigkeit weekly-report auf diesen Ordner.
```

Die Fähigkeit `weekly-report` kommt mit dem Produkt. **Sie ermittelt, was sich
geändert hat** — aus git, wenn der Ordner ein Repository ist, sonst aus den
Änderungszeiten — und schreibt drei Abschnitte: **was fertig wurde, was läuft und
was eine Entscheidung braucht**.

**Wegen des letzten Abschnitts liest man ihn.**

## 3. Auf einen Zeitplan setzen

**Hintergrundläufe → einen wiederkehrenden planen:**

| Feld | |
| --- | --- |
| **Was soll er tun** | Verwende die Fähigkeit weekly-report auf diesen Ordner. Speichere sie als `report-<date>.md`. |
| **Name** | Wochenbericht |
| **Wie oft** | 7 Tage |
| **Wo ausführen** | der Ordner, den Sie gewählt haben |

## 4. Prüfen, wo er laufen wird

**Liegt der Ordner nicht im Arbeitsbereich und ist er keine Abteilung, wird der
erste Lauf zurückgehalten**, statt zu starten, und erscheint unter *Wartet auf
Sie*.

**Das ist Absicht.** Geben Sie das Verzeichnis frei, oder verschieben Sie die
Aufgabe in eine Abteilung.

## 5. Den ersten lesen

**Run now**, dann öffnen Sie den Lauf und **lesen die Ausgabe, während sie
entsteht**.

**Ist der Bericht dünn, hatte der Ordner eine dünne Woche**: Die Fähigkeit ist
angewiesen, **das in einer Zeile zu sagen, statt zu strecken**, denn **ein aus
einer leeren Woche aufgeblasener Bericht bringt Leuten bei, Berichte zu
überspringen**.

## Das mit dem Ordner eines anderen tun

**Zwei Dinge, bei denen Vorsicht angebracht ist.**

**Der Agent liest alles, worauf man ihn richtet**, und **Lesezugriffe sind in
keinem Modus durch die Sandbox beschränkt**. **Ein Ordner mit Dingen, die Sie
Ihrem Modellanbieter nicht schicken würden, sollte nicht der Ordner sein, auf den
Sie ihn richten** — **es sei denn, Ihr Modell läuft auf Ihrem eigenen Rechner**,
dann verlässt es nichts.

**Ein Zeitplan überdauert Ihre Aufmerksamkeit.** Etwas, das ein Jahr lang
wöchentlich läuft, sind **zweiundfünfzig Läufe, die Sie nicht angesehen haben**.
**Halten Sie das Verzeichnis eng.**
