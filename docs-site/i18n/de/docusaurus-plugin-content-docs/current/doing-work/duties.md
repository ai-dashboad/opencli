---
title: Dienste
sidebar_position: 2
---

# Dienste

**Ein Dienst ist eine Aufgabe, die ein Bot in einem Intervall ausführt** und die
**anhält und Sie fragt, sobald sie an etwas kommt, das sie nicht allein
entscheiden sollte.**

**Dieser letzte Teil ist der Punkt.** Einen Prompt auf einem Timer laufen zu
lassen kann alles; brauchbar für echte Arbeit wird das erst dadurch, dass ihm
**vorab gesagt ist, was er nicht selbst regeln darf.**

## Die vier Felder

```
Was             Vergleiche ledger.csv mit statement.csv, Zeile für Zeile,
                und liste, was nicht übereinstimmt, mit Referenz und Betrag.

Regeln          Eine Differenz unter 1,00 ist Rundung. Ignorieren.

Eskalieren wenn Eine einzelne Zeile über 10.000 liegt.

Alle            24 Stunden
```

**„Was“ und „Regeln“ bleiben absichtlich getrennt.** Die Arbeit ist jeden Morgen
dieselbe; **die Erstattungsobergrenze ist eine Richtlinie, die jemand wieder
anfasst.** In einen Prompt verschmolzen bedeutet das Ändern der Zahl, **die ganze
Anweisung noch einmal zu lesen, um sie zu finden.**

**„Eskalieren wenn“ wird in Worten geschrieben, nicht als Bedingung.** Es wird dem
Modell **als Pflicht mitgegeben und nicht vom Produkt ausgewertet** — es ist also
**nur so verlässlich wie das Modell, das es liest.** Schreiben Sie es als etwas
Prüfbares: *eine einzelne Zeile über 10.000*, nicht *irgendetwas
Ungewöhnliches*.

## Was beim Eskalieren passiert

**Der Dienst hält an.** Er erscheint unter **Bots → Wartet auf Sie** mit der
Frage, die er nicht beantworten konnte, und **läuft nicht wieder, bis Sie
antworten.**

**Ihre Antwort wird in den nächsten Lauf mitgenommen**, der Bot fragt dasselbe
also nicht zweimal.

**Ein Dienst, der schon gefragt hat, stellt keine zweite Frage** — er wiederholt
die offene.

## Was er sich merkt

**Ein Dienst führt Notizen zwischen den Läufen.** Ein Lauf, der eine Sache
gelernt hat, **schreibt diese eine Sache auf**; er muss nicht wiederholen, was er
schon wusste, und **ein Lauf, der auf halbem Weg scheiterte, reißt die übrigen
Notizen nicht mit.**

**Einen leeren Wert zu schreiben ist die Art, etwas absichtlich zu vergessen.**

## Wo er läuft

**Im Abteilungsverzeichnis des Bots** — und das ist **alles, worin der Lauf
schreiben darf.** Ein Dienst, der woanders hinzeigt, **wird zurückgehalten, bis
Sie diesen Ort namentlich freigeben** — siehe
[Sandbox und Freigaben](/configuration/sandbox-and-approvals).

## Dienste und geplante Aufgaben

**Beide lassen einen Prompt auf einem Timer laufen.** Der Unterschied ist,
**wozu sie gehören.**

| | Gehört zu | Eskaliert | Merkt sich |
| --- | --- | --- | --- |
| **Dienst** | einem Bot, in einer Abteilung | ja | ja |
| **Geplante Aufgabe** | nichts | nein | nein |

Nehmen Sie eine geplante Aufgabe für *jeden Morgen um neun, sag mir, was sich
geändert hat*. Nehmen Sie einen Dienst für **Arbeit, an der eine Richtlinie
hängt**.
