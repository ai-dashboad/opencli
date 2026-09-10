---
title: Compétences
sidebar_position: 4
---

# Compétences

**Une compétence est un ensemble d'instructions auquel l'agent puise quand une
tâche l'appelle** : une procédure écrite une fois, **plutôt que collée dans un
prompt à chaque fois**.

## Ce qui est fourni

**Six procédures sont livrées avec le produit et fonctionnent dans n'importe quel
répertoire** :

| Compétence | Ce qu'elle fait |
| --- | --- |
| `spreadsheet-review` | Confronte un fichier de lignes aux règles qu'il énonce et signale les lignes fautives **avec leur numéro** |
| `weekly-report` | Ce qui a **réellement changé** ici sur une période : fait, en cours, et ce qui demande une décision |
| `inbox-triage` | Trie les messages selon ce qu'ils demandent et **marque ceux auxquels une personne doit répondre** |
| `document-compare` | Ce qui a changé **sur le fond** entre deux projets, séparément de **ce qui n'a changé que dans la formulation** |
| `meeting-notes` | Une transcription transformée en décisions, actions avec responsables et questions ouvertes |
| `records-review` | Fait remonter ce qui mérite vérification dans un ensemble de dossiers, **en citant la note d'où cela vient** |

Deux autres, héritées, portent sur **l'écriture et l'installation des compétences
elles-mêmes** : `skill-creator` et `skill-installer`.

## D'où elles viennent

| Portée | Répertoire |
| --- | --- |
| Fournies | `~/.opencli/skills/.system` — réécrit à chaque mise à jour |
| Les vôtres | `~/.opencli/skills` |
| Celles de ce projet | `.opencli/skills` dans le répertoire de travail |

## En écrire une

Un répertoire avec un `SKILL.md` dont l'en-tête dit ce que c'est et **quand
l'utiliser** :

```markdown
---
name: invoice-check
description: Check invoices against our payment rules and report what breaks
  them. Use when asked to review, check or audit a file of invoices.
metadata:
  short-description: Find invoices that break the rules
---

# Invoice check

## Find the rules before reading the rows
...
```

**C'est à la `description` que l'agent confronte une demande.** Une description
qui dit seulement ce que la compétence ***est*** **laisse le modèle deviner quand
elle s'applique** : **chaque compétence fournie nomme ses occasions**, et les
vôtres devraient aussi.

## Ce qui fait qu'une compétence marche

**Lire les six fournies est le plus court chemin pour en voir la forme**, mais
trois choses reviennent :

- **Dites quoi lire, et dans quel ordre.** « Les plus anciens d'abord » est une
  vraie instruction ; « passe en revue les dossiers » n'en est pas une.
- **Dites quoi produire.** Un fichier nommé, ou une structure énoncée. Pas « un
  résumé ».
- **Dites ce qu'elle ne doit jamais faire.** La compétence clinique fournie
  **y consacre un tiers de sa longueur**, et c'est pour cela qu'elle peut exister.

**Une leçon apprise à la dure** : si un nombre compte, **dites d'où ce nombre doit
venir**. La compétence tableur demande un nombre de lignes, et **la première
exécution l'a énoncé de mémoire, à un près**. Elle exige désormais **que le compte
vienne du script qui a fait la vérification**.

## En désactiver une

Chaque compétence a un interrupteur dans **Abilities → Skills**. Un changement
s'applique **à la prochaine conversation que vous ouvrez**, pas à celle qui tourne
déjà.
