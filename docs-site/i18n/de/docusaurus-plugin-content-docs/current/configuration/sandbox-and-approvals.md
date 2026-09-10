---
title: Sandbox und Freigaben
sidebar_position: 2
---

# Sandbox und Freigaben

**Zwei Einstellungen mit verschiedenen Aufgaben.** Die Sandbox entscheidet, was
der Agent ***kann***; die Freigaben entscheiden, **was er vorher fragen muss**.

## Die Sandbox

```toml
sandbox_mode = "workspace-write"
```

| | Der Agent darf |
| --- | --- |
| `read-only` | Dateien ansehen, nicht ändern |
| `workspace-write` | innerhalb seines Arbeitsverzeichnisses schreiben |
| `danger-full-access` | alles, was Ihr Konto darf |

**Lesezugriffe werden nie eingeschränkt.** Nur Schreiben und Netzwerkzugriff
werden es — `read-only` heißt also, dass **der Agent Ihre ganze Platte sieht und
nichts davon ändert**.

### Die beschreibbare Wurzel ist das Arbeitsverzeichnis

Unter `workspace-write` bedeutet „der Arbeitsbereich“ **das Verzeichnis, in dem
das Gespräch oder der Lauf geöffnet ist**. Nicht das Projekt, nicht das
Repository — **dieses Verzeichnis**.

**Das ist der wichtigste Satz auf dieser Seite.** Ein Lauf, der in Ihrem
Benutzerordner geöffnet wurde, darf in `.ssh`, `Documents` und `Library`
schreiben.

**Das ist nicht hypothetisch.** Eine geplante Aufgabe, die vor der Existenz von
Abteilungen angelegt worden war, **trug den Benutzerordner mit sich und war so
zweiundvierzig Mal gelaufen** — jeder Lauf konnte alles erreichen, **niemand
wurde gefragt und nichts wurde gesagt**. Den Standard für neue Gespräche zu
ändern rührte sie nicht an, denn **ein Standard wirkt nicht rückwirkend**.

Darum gibt es **eine zweite Prüfung, in dem Moment, in dem ein Lauf startet**.

## Wo ein Hintergrundlauf starten darf

Ein Lauf darf beginnen, wenn sein Verzeichnis **eines ist, das dieses Produkt
bereits kennt**:

- innerhalb des Arbeitsbereichs
- innerhalb des Verzeichnisses einer Abteilung
- **an einem Ort, den Sie namentlich freigegeben haben**

Alles andere wird **zurückgehalten** und erscheint unter **Wartet auf Sie** im
Dispatch-Panel mit einer Schaltfläche *Dieses Verzeichnis freigeben*. **Einen Ort
freizugeben löst jeden Lauf, der darauf wartet.**

**Das Fragen ist der Punkt**: an einem ungewöhnlichen Ort zu laufen ist oft
**genau das, was gewollt war**, und die Antwort ist **eine Rückfrage, keine
Ablehnung**.

## Freigaben

```toml
approval_policy = "on-failure"
```

| | |
| --- | --- |
| `untrusted` | jeder nicht als sicher bekannte Befehl wird vorher gezeigt |
| `on-failure` | Befehle laufen unbeaufsichtigt; gefragt wird, wenn einer mehr Zugriff braucht |
| `never` | vor der Ausführung wird nichts gezeigt |

`never` heißt außerdem, dass **nichts zurückgehalten wird**. Wer Freigaben
abgeschaltet hat, **hat wörtlich gesagt, dass er nicht angehalten werden will**,
und **zu entscheiden, er habe etwas Engeres gemeint, hieße, dass sich das Produkt
über seine eigene Einstellung hinwegsetzt**.

Nehmen Sie es für ein Verzeichnis, **in dem Sie ein Skript frei laufen lassen
würden**.

## Die Kombination, über die Leute stolpern

`sandbox_mode = "danger-full-access"` zusammen mit `approval_policy = "never"` ist
**ein Agent, der beliebige Befehle auf Ihrem Rechner ausführt, ohne dass etwas
gezeigt und etwas gefragt wird**. **Es gibt Verzeichnisse, wo das die richtige
Antwort ist. Ihr Benutzerordner gehört nicht dazu.**

## Zwei Dinge, die die Sandbox nicht tut

- **Sie hindert das Modell nicht daran, Ihre Dateien zu lesen.** Lesezugriffe
  sind **in keinem Modus** eingeschränkt.
- **Sie deckt nicht ab, was ein von ihr ausgeführter Befehl danach tut.** Ein
  Skript, das der Agent startet, erbt die Sandbox; **ein Dienst, den er startet
  und der den Lauf überdauert, nicht**.
