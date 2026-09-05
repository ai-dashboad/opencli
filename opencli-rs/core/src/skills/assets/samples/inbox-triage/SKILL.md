---
name: inbox-triage
description: Sort a folder of incoming messages — support tickets, emails, form submissions, feedback — into what they are asking for, and pick out the ones a person has to answer. Use when asked to triage, sort, group, or go through messages, tickets, or an inbox.
metadata:
  short-description: Group incoming messages by what they want, and flag the urgent
---

# Inbox triage

The purpose is to shorten somebody's queue without hiding anything from them.
Everything is accounted for; nothing is answered on their behalf.

## Read every message

All of them, in full. A message triaged from its subject line is triaged
wrong — the subject says what the sender thought it was about before they
wrote it.

Say how many you read.

## Group by what is being asked for

Not by tone, sender, or product area. The groups are whatever the messages
actually contain; typical ones are:

- **Broken** — something does not work and they want it to.
- **How do I** — it works, they cannot find it.
- **Billing** — money, invoices, refunds, plans.
- **Wants something new** — a feature request, however it is phrased.
- **Not a question** — praise, complaint, or spam.

Invent a group when several messages need one. Do not force a message into a
group it does not fit — a group of one is honest.

Within each group, put the messages that say the same thing together and say
how many said it. "Nine people cannot find the export button" is the finding;
nine separate lines are a list.

## Flag what needs a person, now

A separate section at the top, before the groups. A message goes here when:

- Somebody is losing money or data right now.
- It threatens to leave, escalate, or publish.
- It mentions a legal or safety matter.
- It has been waiting longer than the others — say how long.

Nothing else goes here. A flag section that holds a third of the inbox is not
a flag section.

## For each message, keep

- Who, when, and where to find it (filename or id).
- One line of what they want, in their words where possible.
- Whether anything in the folder already answers it.

## Report

```
Needs you (3)
  2026-09-01  ticket-4471  Renewal charged twice, asking for a refund today
  ...

Broken (12)
  9 × cannot find the export button  [4471, 4478, 4480, ...]
  3 × login loops on Safari          [4462, 4469, 4477]

How do I (7)
  ...
```

End with one line: how many messages, how many groups, how many flagged.

## Never

- Never reply to anybody, draft a reply, or mark anything as handled unless
  you were asked to. Triage sorts; it does not answer.
- Never drop a message because it is unclear. Put it in a group called
  "unclear" and say what is missing.
- Never judge severity from how upset somebody sounds. Judge it from what is
  happening to them.
