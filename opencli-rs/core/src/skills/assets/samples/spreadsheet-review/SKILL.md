---
name: spreadsheet-review
description: Check a spreadsheet or CSV against the rules it is supposed to follow, and report the rows that break them with their row numbers. Use when asked to review, check, reconcile, or audit a file of rows — invoices, expenses, payroll, inventory, orders, a ledger — or when asked what looks wrong in one.
metadata:
  short-description: Find the rows that break the rules, and say which rows
---

# Spreadsheet review

Rows are checked one at a time against rules stated in words. The result is a
short list of what is wrong and where, not a summary of what the file contains.

## Find the rules before reading the rows

The rules are usually written down near the data:

1. A `rules.md`, `README.md`, or `notes.txt` beside the file.
2. The department's standing instructions, if this is a department directory.
3. What the person asked for, if they stated a rule in the request.

If you cannot find any rule, **ask which rules apply before checking
anything**. A review with invented rules produces confident findings about
nothing, and those are worse than no findings — somebody acts on them.

## Read the whole file

Read every row. Do not sample, and do not stop at the first problem.

A file too large to read at once is read in parts, and every part is read
before anything is reported.

Say how many rows you read; a reviewer needs to know whether the answer covers
the file or a corner of it. **Take that number from the script that did the
checking, not from memory** — a count stated from recollection was off by one
the first time this skill was run, and a coverage figure that cannot be
trusted is worse than none, because it is the line that says the review is
complete.

## Check each rule against each row

For every finding, record three things:

- **Which row.** By its number in the file, and by whatever identifier the row
  carries (invoice number, employee, SKU). A row number alone is useless once
  the file is sorted.
- **Which rule it breaks.** Quote the rule.
- **What the row actually says.** The values, not your reading of them.

## What counts as a finding

A finding is a row that breaks a stated rule. These are not findings:

- A row that looks unusual but breaks no rule. Note it separately, under
  "worth a look", and say plainly that no rule covers it.
- A pattern across rows, unless the rules speak to patterns.
- Formatting, spelling, or column order.

## Report

Findings first, most costly first. For each:

```
Row 47 — INV-2231 — Amount 12,400 with no purchase order
Rule: "Anything over 10,000 needs a PO number."
```

Then, if any: **worth a look** — the things no rule covers.

Then one line: how many rows were read, and how many rules were checked.

## Never

- Never change the file. A review reports; it does not correct. If asked to
  fix, fix in a copy and say which copy.
- Never state a total or a difference you have not computed from the rows you
  read. Arithmetic across hundreds of rows is where a confident wrong number
  comes from — compute it with a script and show the script.
- Never guess at a value that is missing. A blank cell is a finding.
