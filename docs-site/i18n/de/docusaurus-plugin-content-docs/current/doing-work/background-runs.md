---
title: Hintergrundläufe
sidebar_position: 3
---

# Hintergrundläufe

**Arbeit, die zum Alleinlaufen weggeschickt wurde.** Jeder Lauf ist **ein eigener
Agent in einem eigenen Verzeichnis** und **läuft weiter, nachdem Sie den Chat
geschlossen haben, der ihn gestartet hat**.

## Vier Arten, wie einer beginnt

| Herkunft | Gestartet von |
| --- | --- |
| **Dispatch** | Ihnen, von Hand, im Dispatch-Panel |
| **Geplant** | einer wiederkehrenden Aufgabe, die fällig wird |
| **Dienst** | dem Dienst eines Bots, der fällig wird |
| **Cowork** | dem Senden einer Nachricht im Cowork-Modus |

**Alle vier landen in derselben Liste** — deshalb lohnt sich das Panel auch,
wenn Sie nie etwas von Hand losschicken.

## Sie laufen nur, solange OpenCLI offen ist

**Das hier ist ein lokaler Agent, kein Server.** Alles, was bei schlafendem
Rechner auslösen muss, gehört in **den Scheduler des Betriebssystems**: `cron`,
`launchd`, die Aufgabenplanung.

Deutlich gesagt, weil die Alternative **eine Aufgabe ist, die stillschweigend nie
gelaufen ist**.

## Wie viele gleichzeitig

**Standardmäßig drei.** Jeder ist ein vollständiger Agent mit eigenen
Modellaufrufen — **mehr, als Ihr Rechner speisen kann, macht alle langsamer,
statt sie früher fertig werden zu lassen**. Die Zahl ist ein Regler im Panel und
**wirkt ohne Neustart**.

**Die Obergrenze ist sechzehn**, und das ist keine Geschmacksfrage: darüber
hinaus **kommen die Läufe nicht mehr voran und konkurrieren um dieselben
Gewichte**.

## Verzeichnisse, und warum ein Lauf zurückgehalten werden kann

Die Sandbox eines Laufs darf **überall in ihrem Arbeitsverzeichnis** schreiben.
Dieses Verzeichnis ist also keine Bequemlichkeit — es ist **alles, was der Lauf
ändern kann**.

Ein Lauf darf deshalb starten, wenn sein Verzeichnis **eines ist, das dieses
Produkt bereits kennt**:

- innerhalb des Arbeitsbereichs
- innerhalb des eigenen Verzeichnisses einer Abteilung
- **an einem Ort, den Sie namentlich freigegeben haben**

Alles andere wird **zurückgehalten** und erscheint unter **Wartet auf Sie** mit
einer Schaltfläche *Dieses Verzeichnis freigeben*. **Einen Ort freizugeben löst
jeden Lauf, der darauf wartet.**

Steht Ihre Freigabe-Einstellung auf **Nie fragen**, wird **nichts
zurückgehalten**. Wer Freigaben abgeschaltet hat, hat das gesagt, und **das
Produkt setzt sich nicht über die Einstellung hinweg, die es selbst angeboten
hat**.

## Einem zusehen

**Die Ausgabe erscheint, während der Agent sie erzeugt**, nicht erst am Ende des
Laufs. Ein Lauf, der zehn Minuten dauert, **ist zehn Minuten lang lesbar**.

## Einen aufgreifen

**Ein fertiger Lauf lässt sich als gewöhnliches Gespräch fortsetzen**:
**Continue in a chat** öffnet einen neuen Verlauf im selben Verzeichnis, mit
**dem, worum der Lauf gebeten wurde, und dem, was er berichtet hat, bereits im
Kontext**.

**Mit dem Lauf selbst kann man nicht sprechen.** Das hier ist der Weg zurück
hinein.
