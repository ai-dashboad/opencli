---
title: Connectors
sidebar_position: 5
---

# Connectors

**Ein Connector ist ein MCP-Server, über den der Agent Werkzeuge aufrufen kann**:
GitHub, eine Datenbank, ein Browser, Ihre Dateien. Es ist **die Art, wie der
Agent an etwas herankommt, das keine Datei auf diesem Rechner ist**.

## Einen hinzufügen

**Abilities → Connectors** listet, was eingerichtet ist und was hinzugefügt
werden kann. Aus dem Katalog hinzufügen ist ein Klick; einen eigenen hinzufügen
verlangt einen Namen und entweder einen Befehl oder eine URL:

| | |
| --- | --- |
| **Lokaler Befehl** | ein Programm auf diesem Rechner, von OpenCLI gestartet |
| **HTTP-Server** | ein über HTTP erreichbarer Server |

## Schlüssel

**Die meisten Connectors brauchen einen.** Nennen Sie die Umgebungsvariablen, die
der Server erwartet — **nur die Namen**, durch Leerzeichen getrennt — und
**tragen Sie die Werte danach ein**.

**Die Werte liegen bei Ihren anderen Schlüsseln, nicht in der Konfiguration des
Connectors**, und werden **nach dem Speichern nie wieder angezeigt**. Das ist
Absicht: **die Konfigurationsdatei wird geteilt und in Tickets eingefügt, und ein
Schlüssel darin geht mit.**

## Testen

**Test connections** startet jeden eingerichteten Server und wartet auf einen
Handshake. Es ist eine Schaltfläche und nichts, was beim Öffnen des Panels
passiert, weil **das Starten Sekunden dauert** — gemessen **2,2** bei einem, der
sich nicht authentifizieren kann.

Das Ergebnis erscheint in jeder Zeile, **mit den Werkzeugen, die dieser Server
anbietet**.

## Wann eine Änderung wirkt

**Server starten mit einem Chat.** Ein jetzt hinzugefügter Connector gilt für das
**nächste** Gespräch, das Sie öffnen, nicht für das vor Ihnen.

## Was ein Connector nicht ist

**Er ist keine Fähigkeit, die das Modell dazugewinnt.** Ein Modell, das keine
Werkzeuge aufruft, **fängt nicht damit an, weil ein Connector hinzugefügt wurde**
— siehe [Grenzen](/reference/limits).

## Abteilungen

Die Chips über der Liste filtern nach Abteilung, sodass man eine frisch angelegte
Finanzabteilung fragen kann, *womit das hier verbunden sein sollte*, statt *was
Playwright ist*.

**Ein Connector ohne Abteilungs-Etikett erscheint unter jedem Chip**: **was
niemand einsortiert hat, sollte nicht vor allen verborgen sein.**
