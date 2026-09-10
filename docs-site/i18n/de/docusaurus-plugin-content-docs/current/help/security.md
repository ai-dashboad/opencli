---
title: Sicherheit
sidebar_position: 3
---

# Sicherheit

**Was dieses Produkt mit Ihrem Rechner und Ihren Daten tut** — so aufgeschrieben,
**dass Sie entscheiden können, statt zu vermuten**.

## Was Ihren Rechner verlässt

Ihre Prompts und alle Dateien, die der Agent in Ihrem Auftrag liest, gehen **an
den Endpunkt, den Sie eingerichtet haben**, und sonst nirgendwohin. **Es gibt kein
Gateway von uns dazwischen.**

Läuft dieser Endpunkt auf Ihrem eigenen Rechner, **verlässt ihn nichts**.

**Zwei Ausnahmen**, die beide **offline still fehlschlagen** und von denen **keine
etwas mitnimmt, das Sie getippt haben**:

- die Desktop-App fragt ihren Update-Endpunkt, ob es eine neuere Version gibt
- das Models-Panel holt beim Öffnen eine Liste beliebter Modelle von Hugging Face

## Was der Agent Ihrem Rechner antun kann

**Zwei Einstellungen mit verschiedenen Aufgaben.**

**Die Sandbox** entscheidet, was er *kann*. Unter `workspace-write` — dem Standard
— darf er **überall innerhalb seines Arbeitsverzeichnisses** schreiben und
nirgends sonst. **Lesezugriffe sind in keinem Modus eingeschränkt.**

**Freigaben** entscheiden, was er vorher fragen muss — von jedem ungewohnten
Befehl bis hin zu gar nichts.

**Die Kombination, bei der Vorsicht angebracht ist, ist `danger-full-access`
zusammen mit `never`**: ein Agent, der **beliebige Befehle ausführt, ohne dass
etwas gezeigt und etwas gefragt wird**. **Es gibt Verzeichnisse, wo das richtig
ist. Ihr Benutzerordner gehört nicht dazu.**

[Sandbox und Freigaben](/configuration/sandbox-and-approvals) hat die Einzelheiten.

## Wo ein Hintergrundlauf starten darf

**Ein Lauf, dessen Verzeichnis weder der Arbeitsbereich noch eine Abteilung noch
ein von Ihnen namentlich freigegebener Ort ist, wird zurückgehalten**, statt zu
starten.

Das gibt es, weil **eine vor der Existenz von Abteilungen angelegte geplante
Aufgabe einen Benutzerordner mit sich trug und zweiundvierzig Mal gelaufen war**:
**jeder Lauf mit Zugriff auf `.ssh` und `Documents`, ohne dass jemand gefragt
wurde**.

**Freigaben auf `never` zu stellen schaltet das zusammen mit allem anderen ab** —
und genau das bedeutet diese Einstellung.

## Schlüssel

**API-Schlüssel liegen außerhalb von `config.toml`**, weil **diese Datei
weitergegeben und in Tickets eingefügt wird**. Sie werden dort abgelegt, wo Ihre
anderen Geheimnisse liegen, und **nach dem Speichern nie wieder angezeigt**.

**Connector-Schlüssel funktionieren genauso**: Sie nennen die Umgebungsvariablen,
die ein Server braucht, und **die Werte liegen getrennt von der Konfiguration
dieses Servers**.

## Das Gateway

Die Desktop-App und die Web-Oberfläche sprechen mit **einem lokalen Gateway**. Es:

- **bindet an Loopback**, sofern nicht ausdrücklich anders gesagt, damit es
  **nicht versehentlich im Netz steht**
- **verlangt bei jeder Verbindung ein Token**, pro Lauf erzeugt und einmal
  ausgegeben, damit **weder ein anderer lokaler Benutzer noch eine Webseite in
  Ihrem Browser es steuern kann**

**Ein Client dieses Gateways kann den Agenten dazu bringen, Befehle auf dem
Rechner auszuführen, der es beherbergt.** Genau darum geht es, **und dafür gibt es
das Token**.

**Es ist von der Anlage her Einbenutzer-Software.** Mehrere nicht vertrauenswürdige
Personen zu bedienen bräuchte **eine Sandbox je Benutzer**, und das liegt außerhalb
des Rahmens.

## Gekoppelte Telefone

**Beim Koppeln bekommt ein Gerät ein Token, mit dem es den Agenten auf diesem
Rechner steuern kann.** Die Adresse wird einmal angezeigt. **Koppeln Sie nur Ihre
eigenen Geräte, und widerrufen Sie alles, was Sie nicht wiedererkennen.**

## Die Builds sind nicht signiert

**Kein Apple- oder Microsoft-Zertifikat**, Ihr Betriebssystem **kann also nicht
erkennen, wer sie gebaut hat, und sagt das**. **Diese Warnung ist zutreffend, und
Sie sollten sie als zutreffend lesen.**

Wenn Sie uns bei alldem lieber nicht aufs Wort glauben: der Quelltext ist
[hier](https://github.com/ai-dashboad/opencli), und es ist **ein `cargo build`**.

## Etwas melden

**Öffnen Sie für einen Sicherheitsfehler kein öffentliches Ticket.** Nutzen Sie
GitHubs
[Formular für vertrauliche Hinweise](https://github.com/ai-dashboad/opencli/security/advisories/new),
das **die Betreuer erreicht, ohne etwas zu veröffentlichen**.

**Am ehesten lohnt der Blick auf das, was auf dieser Seite steht**: die
Sandbox-Politik, den Freigabepfad, die Verzeichnisprüfung bei Hintergrundläufen
und das Token des Gateways.

**Bitte fügen Sie weder Ihre Schlüssel noch Protokolle bei, die sie enthalten.**
