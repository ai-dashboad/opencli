---
title: Mitmachen
sidebar_position: 3
---

# Mitmachen

**Pull Requests sind willkommen, und es gibt keine Einladung, auf die man warten
müsste.** Dies ist ein kleines Projekt; **das Nützliche ist meist kein großes
Feature**, sondern eine Zeile in einer Tabelle, ein Satz in einer Übersetzung
oder **ein Fehlerbericht, der detailliert genug ist, um damit zu arbeiten**.

## Die nützlichsten Beiträge

**Eine Zeile in der Modelltabelle.**
[Ein Modell prüfen](/reference/checking-a-model) ist eine feste
Fünf-Minuten-Aufgabe. **Die Tabelle ist kurz, weil nur Modelle drinstehen, die
jemand ausprobiert hat**, und **ein negatives Ergebnis ist so viel wert wie ein
positives** — **niemand schreibt über das Modell, das nicht ging, also entdeckt es
jeder neu**.

**Eine Übersetzung, oder eine Zeile Korrektur an einer.** Zehn sind dabei. Jede
lässt sich **Satz für Satz korrigieren, ohne den Rest anzufassen** — siehe
[Sprachen](/configuration/languages). **Eine neue Sprache ist eine einzige
JSON-Datei.**

**Ein Fehlerbericht mit den vier Dingen.** Modell und Anbieter genau geschrieben
(`qwen3-coder:30b` auf Ollama, nicht „ein lokales Modell“), worum Sie gebeten
haben, was passiert ist, und fünfzig Zeilen aus `~/.opencli/log` rund um den
Fehlschlag. **Sehen Sie diese Zeilen vor dem Einfügen auf Schlüssel durch.**

**Uns sagen, was Sie eigentlich tun wollten.** Die mitgelieferten Abteilungen und
Fähigkeiten **wurden aus Vermutungen darüber geschrieben, was Leute brauchen**.
**Wonach Sie gegriffen und es nicht gefunden haben, ist das Nützlichste, was Sie
sagen können.**

## Bevor Sie Code schreiben

**Öffnen Sie für alles, was größer ist als eine Korrektur, zuerst ein Ticket.**
Nicht als Schranke — **sondern damit der Weg abgestimmt ist, bevor Sie einen Abend
hineinstecken**. **Eine PR, die ohne Ticket dahinter eintrifft, wird trotzdem
gelesen.**

## Einrichten

Rust und pnpm; der Workspace ist `opencli-rs/`, die Web-Oberfläche ist `web/` und
die Desktop-Hülle ist `desktop/`.

```shell
git clone https://github.com/ai-dashboad/opencli
cd opencli
pnpm install
cargo build -p opencli-cli
```

`just` aus dem Repository-Wurzelverzeichnis führt die Workspace-Helfer aus;
`just help` listet sie auf.

## Bevor Sie die PR öffnen

```shell
just fmt
just fix -p <crate>
cargo test -p <crate>
```

**Führen Sie kein nacktes `cargo fmt` aus.** Der Baum ist mit
`imports_granularity=Item` formatiert, und das ist **eine reine
Nightly-Option**. Auf stable wird sie **stillschweigend ignoriert**, also
**schreibt `cargo fmt` den Import-Block fast jeder Datei im Workspace neu** und
**begräbt Ihre Änderung unter Hunderten unbeteiligter Diffs**. **Genau darum ruft
`just fmt` nightly auf.** Ohne Nightly-Toolchain
(`rustup toolchain install nightly`) **formatieren Sie nur die Dateien, die Sie
angefasst haben, und lassen die CI den Rest bestätigen**.

Wenn Sie die Web-Oberfläche angefasst haben, findet
`python3 scripts/i18n-check.py` **Englisch, das nie für die Übersetzung eingepackt
wurde** — auch die leicht zu übersehenden Fälle wie **Text, den ein Inline-Tag
zerteilt**, und **Beschriftungen, die beim Import gebaut werden**.

## Was eine PR leicht zusammenführbar macht

- **Eine Sache.** Unbeteiligte Korrekturen kommen in eigene PRs.
- **Ein Test, der vor Ihrer Änderung fehlschlägt und danach durchläuft.** Keine
  vollständige Abdeckung — **eine Zusicherung, die den Fehler gefangen hätte**.
- **Commits, die einzeln bauen.** Erst das macht Review und Rücknahme möglich.
- **Dokumentation, wenn sich Verhalten geändert hat.** Die README,
  `opencli --help` oder die Seite hier, die jetzt falsch ist.
- **Was, warum, wie** in der Beschreibung. **Das *Warum* ist der Teil, den man dem
  Diff nicht ansieht.**

## Kein CLA

**Es gibt nichts zu unterschreiben.** Beiträge stehen unter
[Apache-2.0](https://github.com/ai-dashboad/opencli/blob/main/LICENSE), wie der
Rest des Baums.

## Eine Schwachstelle melden

**Öffnen Sie für einen Sicherheitsfehler kein öffentliches Ticket.** Nutzen Sie
GitHubs
[Formular für vertrauliche Hinweise](https://github.com/ai-dashboad/opencli/security/advisories/new),
das **die Betreuer erreicht, ohne etwas zu veröffentlichen**.

**Am ehesten lohnt der Blick auf**: die Sandbox-Politik, den Freigabepfad und
**alles, was entscheidet, was ein Werkzeugaufruf anfassen darf**. **Ein Agent, der
Ihre Dateien liest und Befehle auf Ihrem Rechner ausführt, hat eine große
Angriffsfläche, und es ist besser, wenn Sie sie finden als jemand anderes.**

## Anständig bleiben

**Behandeln Sie Menschen mit Respekt**; wir folgen dem
[Contributor Covenant](https://www.contributor-covenant.org/). **Unterstellen Sie
gute Absichten** — **schriftliche Kommunikation ist schwer, entscheiden Sie sich im
Zweifel für Großzügigkeit.** Wenn etwas verwirrend ist, ist das für sich genommen
ein Ticket wert: **verwirrende Dokumentation ist ein Fehler in der
Dokumentation**.
