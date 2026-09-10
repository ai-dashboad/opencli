---
title: Abteilungen und Bots
sidebar_position: 1
---

# Abteilungen und Bots

**Ein Chat ist ein Gespräch.** Arbeit, die wiederkommt, braucht etwas, **das ihn
überdauert**.

| | Ist | Liegt in |
| --- | --- | --- |
| **Abteilung** | ein Verzeichnis plus ständige Anweisungen | standardmäßig `~/.opencli/workspace/<Name>` |
| **Bot** | ein Chat innerhalb einer Abteilung, mit einer Aufgabe | dieser Abteilung |
| **Dienst** | eine Aufgabe, die von selbst wiederkommt | einem Bot |

**Die Wörter sind absichtlich aus dem Büro geborgt.** Eine Abteilung ist kein
Ordner mit hübschem Namen: sie ist **die Grenze dessen, was die Arbeit darin
anfassen darf**.

## Mit einer anfangen, die schon läuft

**Neun Abteilungen kommen mit Beispieldaten** — Dateien, in die bereits Probleme
eingebaut sind — damit der erste Lauf **etwas tut**, statt zu erklären, dass es
nichts zu tun gibt.

| Abteilung | Was mitkommt |
| --- | --- |
| Finanzen | `ledger.csv` gegen `statement.csv` abgleichen; Überfälliges nachfassen |
| Support | Beantworten, was hereinkam; Fragen danach bündeln, worum es wirklich geht |
| Betrieb | Jede noch nicht versandte Bestellung auflisten, und wie lange sie wartet |
| Marketing | Notizen in eine Woche Beiträge verwandeln; Kontakte nach Gekauftem gruppieren |
| Personal & Verwaltung | Bewerbungen gegen eine Stelle lesen; Entscheidungen und Zuständige aus Notizen ziehen |
| Recht | Deren Entwurf gegen unsere Bedingungen stellen, Klausel für Klausel, beide zitiert |
| Recherche | Wo Studien übereinstimmen, wo sie sich widersprechen, und warum |
| Patientenakten | Was dokumentiert ist und worauf ein Kliniker schauen sollte, zitiert |
| Technik | Einen Dienst lesen und melden, was eine falsche Antwort ergäbe |

**Projects → oder mit einer anfangen, die schon läuft.** Sie legt das Verzeichnis
an, schreibt die Beispieldateien und stellt die Bots ein.

## Eine eigene bauen

**Projects → New**, dann:

- **Name** — wie sie heißt
- **Ordner** — wird angelegt, wenn es ihn nicht gibt
- **Ständige Anweisungen** — werden dem Agenten in ***jedem*** hier geöffneten
  Chat mitgegeben

**In den ständigen Anweisungen steht das, was Sie sonst jedes Mal neu tippen
müssten**: wie gebaut wird, was nicht angefasst wird, welche Zahlen Politik sind.
Sie sind getrennt von der Beschreibung, die **nur Sie lesen**.

## Bots

**Ein Bot ist ein Chat mit einer Aufgabe.** Diese Aufgabe geht **jedes Mal
wieder mit hinein, wenn der Bot geweckt wird** — man muss ihm also nicht erneut
sagen, wofür er da ist.

Vier Zustände, im Panel **Bots**:

| | |
| --- | --- |
| **Untätig** | nichts zu tun |
| **Arbeitet** | ein Lauf ist unterwegs |
| **Wartet auf Sie** | er hat angehalten und gefragt — siehe [Dienste](/doing-work/duties) |
| **Fehler** | der letzte Lauf ist fehlgeschlagen |

## Bots, die einander Arbeit übergeben

Ein Bot kann einem anderen Arbeit **namentlich** übergeben, samt dem, was er
getan hat, und den Dateien, die er erzeugt hat. Der Empfänger **fängt damit an
und nicht bei null**.

**Drei Absagen** verhindern, dass das durchgeht — und sie sind der eigentliche
Inhalt:

- **Tiefe.** Eine Kette ist bei **acht Sprüngen** gedeckelt.
- **Wiederholung.** Kein Bot darf in einer Kette **mehr als dreimal** vorkommen.
- **Richtung.** Einem Bot darf **nur eine dafür freigegebene Abteilung** Arbeit
  übergeben. Innerhalb einer Abteilung ist es immer erlaubt.

Das Panel **Bots** zeigt jede Kette und **markiert die, die stehen blieben, weil
ihnen das Seil ausging** statt weil sie fertig waren.

## Weiter

[Dienste](/doing-work/duties) — Arbeit, die wiederkommt, ohne dass Sie sie
starten.
