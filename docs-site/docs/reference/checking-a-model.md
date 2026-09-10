---
title: Checking a model
sidebar_position: 1
---

# Checking a model

The table in the README says which models can actually do this work. It is
short because it only holds what has been run, and it grows by people running
it. This is that task. It takes about five minutes.

## Why this task and not a benchmark

The question is not how clever a model is. It is whether it will use a tool
when it has one, read a whole file rather than the first screen of it, and
report a finding against a rule instead of describing the file.

A model that fails this is not a bad model. It is a model that was not trained
towards agentic work, and knowing that before installing 20GB is the point.

## Set it up

A directory with two files. Six rows, three of them wrong:

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
# Invoice rules

- Anything over 10,000 needs a PO number.
- Every invoice must have an amount.
- Dates are YYYY-MM-DD and must be real dates.
```

The three planted problems are row 2 (over the limit, no PO), row 5 (no
amount), and row 6 (month 13). Row 4 is over the limit *and* has a PO — it is
there so that a model reporting every large amount is not scored as correct.

## Run it

```shell
opencli exec --skip-git-repo-check --sandbox workspace-write \
  -m <your-model> "Use the spreadsheet-review skill on invoices.csv"
```

## Score it

| | |
| --- | --- |
| **Calls tools** | Did it read the file with a tool, or ask you to paste the contents? |
| **Found 3/3** | All three, and only three. Four means it invented one. |
| **Cited** | Each finding names its row *and* quotes the rule it breaks |
| **Counted** | The closing line says six rows. Five means it counted from memory |

A model that finds three but cannot say which rows has not done the job: the
whole output of a review is somewhere to look.

## Send it in

Open a pull request adding one row to the table in the README, or an issue with
the output pasted in. Include:

- the model, exactly as its runtime names it (`qwen3-coder:30b`, not "Qwen")
- the runtime — Ollama, LM Studio, vLLM, llama.cpp, a hosted endpoint
- the context window you configured
- anything it did that the four columns do not capture

**Negative results are worth as much as positive ones**, and are harder to come
by — nobody posts about the model that did not work. A row saying a model
cannot call tools saves everybody who reads it a download.
