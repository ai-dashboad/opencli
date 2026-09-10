---
title: Première conversation
sidebar_position: 3
---

# Première conversation

## Où elle démarre

Une nouvelle conversation s'ouvre dans `~/.opencli/workspace`, sauf si elle
appartient à un service, auquel cas elle s'ouvre dans le répertoire de ce
service.

**Cela compte plus qu'il n'y paraît.** Le bac à sable de l'agent peut écrire
n'importe où dans son répertoire de travail : **le répertoire dans lequel une
conversation est ouverte est donc la totalité de ce qu'elle peut modifier**.
Le défaut était autrefois votre dossier personnel ; ce n'est plus le cas, et la
raison se trouve dans
[Bac à sable et autorisations](/configuration/sandbox-and-approvals).

Changez-le avec le bouton dossier au-dessus de la zone de saisie.

## Demander quelque chose

Des phrases ordinaires. L'agent dispose de vos fichiers, d'un shell et des
[connecteurs](/doing-work/connectors) que vous avez ajoutés :

```
Lis invoices.csv et liste chaque ligne qui enfreint les règles de rules.md
```

```
Qu'est-ce qui a changé dans ce dépôt depuis une semaine ?
```

```
Compare their-draft.md et our-terms.md et liste chaque clause qui diffère
```

## Ce qui se passe avant que quoi que ce soit ne change

Par défaut, l'agent **vous montre une commande qui n'est pas connue comme sûre
avant de l'exécuter**, et **montre une écriture de fichier avant de la faire**.
Vous approuvez ou refusez chacune.

Trois réglages, dans **Customize** :

| | |
| --- | --- |
| **Demander devant tout ce qui n'est pas familier** | toute commande non connue comme sûre est montrée d'abord |
| **Demander seulement après un échec** | les commandes s'exécutent sans surveillance ; on vous demande quand l'une a besoin de plus d'accès |
| **Ne jamais demander** | rien n'est montré avant l'exécution |

Le dernier est fait pour un répertoire **dans lequel vous lâcheriez un script**.
Il est expliqué comme il faut dans
[Bac à sable et autorisations](/configuration/sandbox-and-approvals).

## Voir ce qu'il a fait

**Artifacts** liste les fichiers que l'agent a modifiés dans cette conversation,
avec leurs diffs. Une limite honnête : **seules les modifications faites avec
l'outil d'édition de fichiers de l'agent y figurent**. Les fichiers écrits par
une commande shell qu'il a lancée — un heredoc, un script, `git checkout` — ne
sont pas suivis et n'apparaîtront pas.

## Quand cela ne tient plus

Une conversation devenue longue **est résumée pour continuer à tenir**. Vous
verrez **Summarising the conversation…**, puis le fil continue avec un résumé à
la place des tours anciens.

**Si résumer ne peut pas aider** — parce que la longueur vient des schémas
d'outils et non de la conversation — **il le dit une fois, au lieu de
recommencer à chaque tour**.

## Ensuite

**Une conversation n'est qu'une conversation.** Pour que le travail avance sans
vous, [montez un service](/doing-work/departments-and-bots).
