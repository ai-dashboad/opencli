---
title: Fehlersuche
sidebar_position: 2
---

# Fehlersuche

## Es sagt, die Zugangsdaten seien abgelehnt worden

```
The model provider would not accept the request without credentials.
(status 401 Unauthorized)
```

**Entweder ist für den gewählten Anbieter kein Schlüssel gesetzt, oder der
gesetzte gilt für ihn nicht.** Drei Dinge zum Prüfen, **der Reihe nach**:

1. **Welcher Anbieter tatsächlich ausgewählt ist** — `model` in `config.toml` oder
   die Auswahl über dem Eingabefeld. **Auf ein Modell zu zeigen, dessen Anbieter Sie
   nie eingerichtet haben**, ist die übliche Ursache.
2. **Die von `env_key` benannte Umgebungsvariable** ist in der Shell gesetzt, in der
   der Agent läuft. **Die Desktop-App liest sie dort, wo sie Ihre Schlüssel
   aufbewahrt, nicht aus Ihrer Shell.**
3. **Der Schlüssel gehört zu diesem Anbieter.** Der Schlüssel des einen ist nicht
   der Schlüssel des anderen.

**Ein 401 wird absichtlich nicht wiederholt**: **Zugangsdaten werden nicht dadurch
gültig, dass man sie noch einmal anbietet.**

## Die Modellliste ist leer

Das Panel **Models** und die Auswahl über dem Eingabefeld kommen beide aus dem
`/v1/models` des Anbieters. **Eine leere Liste heißt, dass diese Anfrage
fehlgeschlagen ist**, und der Grund steht in `~/.opencli/log`.

**Ein Anbieter, der einen Schlüssel verlangt, gibt ohne ihn nichts zurück** — dies
und der 401 oben sind also **meist dasselbe Problem**.

## Er antwortet, rührt meine Dateien aber nie an

**Ihr Modell ruft keine Werkzeuge auf.** Das ist **die häufigste Enttäuschung**, und
es ist **kein Konfigurationsfehler**: **manche Modelle tun es einfach nicht**.

[Prüfen Sie es](/reference/checking-a-model). Fünf Minuten, eine feste Aufgabe.
**Fällt es durch, ist das Modell das falsche Werkzeug dafür, und keine Einstellung
ändert das.**

## Er ruft `grep` auf, statt die Datei ordentlich zu lesen

**Dieselbe grundlegende Lücke, in milderer Form**: Ein nicht auf Agentenarbeit
trainiertes Modell **greift zur Shell, auch wenn ein Datei-Werkzeug vor ihm
liegt**. **Nichts an der Oberfläche schließt das.**

## Ein Hintergrundlauf sagt, er warte auf mich

**Sein Arbeitsverzeichnis ist keines, das dieses Produkt kennt** — nicht der
Arbeitsbereich, nicht das Verzeichnis einer Abteilung und nicht **ein Ort, den Sie
namentlich freigegeben haben**.

Entweder **Dieses Verzeichnis freigeben** im Dispatch-Panel oder die Aufgabe in
eine Abteilung **verschieben**. **Zurückgehalten statt gestartet wird sie, weil ein
Lauf überall in seinem Verzeichnis schreiben darf.**

## Eine geplante Aufgabe ist nie gelaufen

**Zwei Möglichkeiten**:

- **OpenCLI war geschlossen.** Geplante Arbeit läuft **nur, solange es offen ist**.
- **Sie wird zurückgehalten**, wie oben. Zurückgehaltene Aufgaben erscheinen unter
  *Wartet auf Sie*.

## Das Gespräch fasst sich ständig selbst zusammen

**Wenn es zusammenfasst und sofort wieder muss, kommt die Länge nicht aus dem
Gespräch**: sie kommt aus **dem festen Teil jeder Anfrage**, und das sind vor allem
**die Werkzeug-Schemata Ihrer Connectors**. **Vier Connectors können zehntausend
Tokens sein, bevor Sie überhaupt etwas gesagt haben.**

**Es sagt das einmal, statt es in jedem Zug zu tun.** Die Abhilfe ist, **Connectors
abzuschalten, die Sie in diesem Gespräch nicht brauchen**.

## Die Desktop-App öffnet nicht

**macOS**: `xattr -dr com.apple.quarantine /Applications/OpenCLI.app` ausführen
oder Rechtsklick → **Öffnen**.

**Windows**: SmartScreen → **Weitere Informationen** → **Trotzdem ausführen**.

Weigert sie sich weiterhin, **ist der Download womöglich unvollständig** —
vergleichen Sie die Dateigröße mit der Release-Seite.

## Der Agent hat etwas getan, das ich nicht gesehen habe

**Artifacts listet nur Änderungen auf, die mit dem Datei-Werkzeug des Agenten
gemacht wurden.** Dateien, die ein von ihm ausgeführter Shell-Befehl geschrieben
hat — ein Heredoc, ein Skript, `git checkout` — **sind echte Änderungen, die dort
nicht auftauchen**.

**`git status` im Arbeitsverzeichnis ist die verlässliche Antwort.**

## Die Oberfläche ist auf Englisch, obwohl ich eine andere Sprache gewählt habe

**Ein Wörterbuch wird geholt, wenn seine Sprache gewählt wird**, es gibt also
**einen Moment, in dem das Englische zu sehen ist**. Bleibt es englisch, **wurde
das Bündel nicht geladen** — sehen Sie in die Browser-Konsole in den
Entwicklerwerkzeugen der Desktop-App.

**Ein Satz ohne Übersetzung zeigt konstruktionsbedingt immer Englisch**; das ist
**eine teilweise Übersetzung, kein Fehler**.

## Wo die Protokolle liegen

```
~/.opencli/log
```

**Settings → About → Logs** öffnet das Verzeichnis. Beim Melden eines Problems
reichen **die letzten fünfzig Zeilen rund um den Fehlschlag fast immer** — und
**sehen Sie sie vor dem Einfügen auf Schlüssel durch**.
