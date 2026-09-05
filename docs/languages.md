# Adding a language

Ten translations ship with OpenCLI: English, 简体中文, 繁體中文, 日本語, 한국어,
Español, Português (Brasil), Français, Deutsch and Русский.

Any other language is one file, and so is a correction to one of those.

## Through the interface

**Customize → Language → Add a language file…** takes a `.json` file and keeps
it. It appears in the picker straight away.

## By hand

The same file, in `~/.opencli/locales`, named for the language:

```
~/.opencli/locales/nl.json
```

Both routes write to the same place, so anything added through the interface
can afterwards be edited by hand or copied to another machine.

## What is in it

Each entry is an English sentence exactly as it appears in the interface, and
what to show instead:

```json
{
  "name": "Nederlands",
  "strings": {
    "Dispatch": "Verzenden",
    "Scheduled tasks": "Geplande taken",
    "Runs ({count})": "Uitvoeringen ({count})"
  }
}
```

`name` is what the language picker shows. Leave it out and the filename is
used. The bare map also works, without the envelope:

```json
{ "Dispatch": "Verzenden" }
```

## Starting from one that ships

The shipped translations are the same kind of file, in
[`web/src/locales/`](../web/src/locales/). Copy one, replace the right-hand
side of each line, and you have a complete starting point rather than a list of
sentences to hunt for.

To see every sentence the interface uses:

```
python3 scripts/i18n-check.py
```

## Placeholders

`{name}` in a sentence is filled in. Keep the same placeholders, in whatever
order your language wants them — that reordering is most of why they exist:

```json
{ "Allowed {count} of {total}": "{total} 中允许了 {count} 个" }
```

## Plurals

`plural()` chooses between two forms. That is enough for English, German,
Spanish, French and Portuguese; it does **not** have the third form Russian
wants for 2–4. Where a language needs more forms than two, write the sentence
so the number carries the sense on its own — `запусков: {count}` rather than a
noun that has to agree with it.

Chinese, Japanese and Korean take the singular form and let the number do the
work, which is handled for you.

## Correcting a shipped translation

A file named for a language that already ships is merged into it, not
substituted for it. To change one sentence, write one entry:

```json
{ "Dispatch": "派活儿" }
```

Everything else keeps the shipped wording.

## When it takes effect

A file added through the interface applies at once. One placed in the directory
by hand is read when a window connects, so reopen the window. A file that will
not parse is skipped, with a line in the gateway log — the other languages are
unaffected.

## Untranslated sentences

A sentence with no entry is shown in English, so a partial translation reads as
a mix rather than as a screen of blanks. There is no need to finish one before
it is useful.

## Right-to-left

Arabic, Hebrew and Persian are not among the shipped translations, and adding
one as a file will produce a page laid out left to right. The interface has no
`dir="rtl"` handling yet; that is a change to the stylesheet, not to a
translation file.
