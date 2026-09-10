---
title: Roadmap
sidebar_position: 4
---

# Roadmap

What is known, honestly labelled. Nothing here is a promise with a date on it
— this is a small project and dates it cannot keep would be worth less than
no dates at all.

## Being worked on

**Code signing.** The desktop builds carry no Apple or Microsoft certificate,
which is the single roughest edge in the product: the first launch of a fresh
download tells people something is wrong when nothing is. It costs money per
year, which is the only reason it has not happened.

**A provider catalogue.** Configuring a provider means writing a `base_url`
you have to go and look up. Forty of them have been verified; the list should
be in the app, so choosing one is a click and pasting a key.

**Bringing the interface's shape up to date.** The panels are named after the
parts — artifacts, dispatch, scheduled — rather than after the work. Three of
them feed the same queue and are shown as three peers.

## Known gaps, no work started

**Right-to-left layout.** Arabic, Hebrew and Persian can be added as
translation files today and the page will still be laid out left to right.
That is a change to the stylesheet.

**A workflow canvas.** Bots, duties and handoffs already form a graph — the
data for it is on disk — and there is no way to see it. A chain is currently
one line of text.

**White-labelling.** Branding is compiled in.

**A model compatibility table with more than one row.** This is the most
useful thing anybody could contribute, and it needs no permission:
[check a model](/reference/checking-a-model) and open a pull request.

## Deliberately not planned

**Multi-user serving.** The gateway is single-user by design. An agent that
reads your files and runs commands on your machine does not become a
multi-tenant service by adding accounts to it; it becomes a different product
with a different security model.

**A hosted version.** There is nowhere for your data to go that is not the
model provider you chose.

**Our own model.** This ships no models and has no opinion about where
inference comes from. That is the point of it.

## How this list changes

It is a file in the repository, edited when something moves. If something you
need is in the second section and you would use it,
[say so](https://github.com/ai-dashboad/opencli/issues) — a gap somebody is
waiting on is a different thing from a gap nobody has asked about.
