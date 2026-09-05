# Adding a language

Two translations ship with OpenCLI: English and Simplified Chinese. Any number
can be added on the machine running it, without rebuilding anything.

Put a JSON file in `~/.opencli/locales`, named for the language:

```
~/.opencli/locales/de.json
```

Each entry is an English sentence exactly as it appears in the interface, and
what to show instead:

```json
{
  "name": "Deutsch",
  "strings": {
    "Dispatch": "Versand",
    "Scheduled tasks": "Geplante Aufgaben",
    "Runs ({count})": "Läufe ({count})"
  }
}
```

`name` is what the language picker shows. Leave it out and the filename is
used. The bare map also works, without the envelope:

```json
{ "Dispatch": "Versand" }
```

## What the sentences are

The English source *is* the key — there are no identifiers to look up. To see
every sentence the interface uses:

```
python3 scripts/i18n-check.py
```

`web/src/locales/zh.ts` is the same idea in TypeScript, and is worth reading
as a worked example.

## Placeholders

`{name}` in a sentence is filled in. Keep the same placeholders, in whatever
order your language wants them — that reordering is most of why they exist:

```json
{ "Allowed {count} of {total}": "{total} 中允许了 {count} 个" }
```

## Correcting a shipped translation

A file named for a language that already ships is merged into it, not
substituted for it. To change one Chinese sentence, write one entry:

```json
{ "Dispatch": "派活儿" }
```

Everything else keeps the shipped wording.

## When it takes effect

Files are read when a window connects. Reopen the window after adding or
editing one. A file that will not parse is skipped, with a line in the gateway
log — the other languages are unaffected.

## Untranslated sentences

A sentence with no entry is shown in English, so a partial translation reads as
a mix rather than as a screen of blanks. There is no need to finish one before
it is useful.
