---
name: weekly-report
description: Write a short report of what actually changed in a directory over a period — commits, files, documents, notes — for somebody who was not watching. Use when asked for a weekly report, a status update, a summary of the week, a digest, or what has been happening here.
metadata:
  short-description: What changed here, for somebody who was not watching
---

# Weekly report

A report is read by somebody who has been elsewhere. It answers: what moved,
what is stuck, and what needs them.

## Settle the period first

Default to the last seven days. If the person said "since the last one", find
the last report in this directory and start from its date.

State the period in the report. A report without dates cannot be filed.

## Gather what changed

Use whichever of these the directory actually has:

- **A git repository.** `git log --since=<date> --stat` for what was committed,
  and `git log --since=<date> --format='%an'` for who. Merges are noise unless
  the history is merge-only.
- **Documents and notes.** Files modified in the period. Read the ones that
  changed, not just their names.
- **A record of runs or tasks**, if the directory keeps one.

If nothing changed, say so in one line and stop. A report padded out of an
empty week teaches people to skip reports.

## Write it

Three sections, in this order. Leave out any that is empty rather than writing
"none".

**Done.** What finished, in the words of somebody who wanted it, not of
somebody who built it. "Invoices over 10,000 now need a PO number" rather
than "added a validation rule to `check.py`". Two to six lines.

**In progress.** What is underway and roughly where it is. Say what it is
waiting on if it is waiting.

**Needs a decision.** The things that will not move without somebody. Name the
decision, not the situation: "Which of the two pricing models to use" rather
than "pricing is unclear". This section is the reason the report is read;
put it last so it is the thing left in mind.

## Length

The whole report fits on one screen. If it does not, you are listing rather
than reporting — group the small things into one line and let the big ones
stand alone.

## Cite

Every claim traces to something: a commit hash, a filename, a date. Put the
reference at the end of the line, in brackets. Somebody who wants the detail
must be able to reach it without asking you.

## Never

- Never describe work you did not find evidence of. An empty week is a
  finding.
- Never guess at why something was done. If the reason is not written down,
  report what changed and leave the why to the person who did it.
