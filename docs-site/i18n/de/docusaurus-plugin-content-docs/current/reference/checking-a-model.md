---
title: Ein Modell prüfen
sidebar_position: 1
---

# Ein Modell prüfen

Die Tabelle in der README sagt, **welche Modelle diese Arbeit tatsächlich können**. Sie ist
kurz, **weil nur drinsteht, was ausprobiert wurde**, und **sie wächst dadurch, dass Leute es
ausprobieren**. Das hier ist diese Aufgabe. **Sie dauert etwa fünf Minuten.**

## Warum diese Aufgabe und kein Benchmark

**Die Frage ist nicht, wie klug ein Modell ist.** Sie ist, ob es **ein Werkzeug benutzt, wenn
es eines hat**, ob es **die ganze Datei liest statt nur den ersten Bildschirm**, und ob es
**einen Befund gegen eine Regel meldet, statt die Datei zu beschreiben**.

**Ein Modell, das hier durchfällt, ist kein schlechtes Modell.** Es ist **ein Modell, das nicht
auf Agentenarbeit trainiert wurde** — und **das zu wissen, bevor man 20 GB installiert, ist der
ganze Punkt**.

## Aufsetzen

Ein Verzeichnis mit zwei Dateien. **Sechs Zeilen, drei davon falsch**:

`invoices.csv`

```csv
row,invoice,customer,amount,po_number,date
1,INV-2201,Northwind,4200,,2026-08-03
2,INV-2202,Contoso,11800,,2026-08-05
3,INV-2203,Fabrikam,900,PO-771,2026-08-09
4,INV-2204,Northwind,15400,PO-772,2026-08-11
5,INV-2205,Contoso,,PO-773,2026-08-12
6,INV-2206,Tailspin,7300,,2026-13-02
```

`rules.md`

```markdown
# Rechnungsregeln

- Alles über 10.000 braucht eine Bestellnummer.
- Jede Rechnung muss einen Betrag haben.
- Datumsangaben sind YYYY-MM-DD und müssen echte Daten sein.
```

**Die drei eingebauten Probleme** sind Zeile 2 (über der Grenze, keine Bestellnummer), Zeile 5
(kein Betrag) und Zeile 6 (Monat 13). **Zeile 4 liegt über der Grenze *und* hat eine
Bestellnummer** — sie steht da, **damit ein Modell, das jeden großen Betrag meldet, nicht als
richtig gewertet wird**.

## Ausführen

```shell
opencli exec --skip-git-repo-check --sandbox workspace-write \
  -m <your-model> "Use the spreadsheet-review skill on invoices.csv"
```

## Bewerten

| | |
| --- | --- |
| **Ruft Werkzeuge auf** | Hat es die Datei mit einem Werkzeug gelesen, oder Sie gebeten, den Inhalt einzufügen? |
| **Findet 3/3** | Alle drei, und nur drei. Vier heißt, es hat eines erfunden. |
| **Belegt** | Jeder Befund nennt seine Zeile ***und*** zitiert die verletzte Regel |
| **Hat gezählt** | Die Schlusszeile sagt sechs Zeilen. Fünf heißt, es hat aus dem Gedächtnis gezählt |

**Ein Modell, das drei findet, aber nicht sagen kann, welche Zeilen, hat die Arbeit nicht
getan**: **das ganze Ergebnis einer Prüfung ist eine Stelle, an die man schauen kann**.

## Einschicken

Öffnen Sie einen Pull Request, der der Tabelle in der README eine Zeile hinzufügt, oder ein
Ticket mit der eingefügten Ausgabe. **Bitte mit dabei**:

- das Modell, **genau so, wie seine Laufzeitumgebung es nennt** (`qwen3-coder:30b`, nicht „Qwen“)
- die Laufzeitumgebung — Ollama, LM Studio, vLLM, llama.cpp, ein gehosteter Endpunkt
- das Kontextfenster, das Sie eingestellt haben
- alles, was es getan hat und was die vier Spalten nicht erfassen

**Negative Ergebnisse sind so viel wert wie positive** und **schwerer zu bekommen** —
**niemand schreibt über das Modell, das nicht ging**. **Eine Zeile, die sagt, dass ein Modell
keine Werkzeuge aufrufen kann, spart jedem, der sie liest, einen Download.**
