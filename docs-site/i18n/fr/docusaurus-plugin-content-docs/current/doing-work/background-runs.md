---
title: Exécutions en arrière-plan
sidebar_position: 3
---

# Exécutions en arrière-plan

**Du travail envoyé tourner tout seul.** Chaque exécution est **un agent distinct
dans son propre répertoire**, elle **continue donc après que vous avez fermé la
conversation qui l'a lancée**.

## Quatre façons d'en démarrer une

| Origine | Lancée par |
| --- | --- |
| **Dispatch** | vous, à la main, dans le panneau Dispatch |
| **Planifiée** | une tâche récurrente qui arrive à échéance |
| **Permanence** | la permanence d'un bot qui arrive à échéance |
| **Cowork** | l'envoi d'un message en mode Cowork |

**Les quatre finissent dans la même liste**, et c'est pourquoi le panneau vaut
d'être lu même si vous ne lancez jamais rien à la main.

## Elles ne tournent que pendant qu'OpenCLI est ouvert

**Ceci est un agent local, pas un serveur.** Tout ce qui doit se déclencher
machine endormie relève **du planificateur du système d'exploitation** : `cron`,
`launchd`, le Planificateur de tâches.

Dit franchement, parce que l'alternative est **une tâche qui, en silence, n'a
jamais tourné**.

## Combien à la fois

**Trois par défaut.** Chacune est un agent entier avec ses propres appels au
modèle : **au-delà de ce que votre machine peut nourrir, elles ralentissent
toutes au lieu de finir plus vite**. Ce nombre est un réglage du panneau et
**prend effet sans redémarrage**.

**Le plafond est seize**, et pas par goût : au-delà, **les exécutions cessent
d'avancer et se disputent les mêmes poids**.

## Répertoires, et pourquoi une exécution peut être retenue

Le bac à sable d'une exécution peut écrire **n'importe où dans son répertoire de
travail**. Ce répertoire n'est donc pas un confort : c'est **la totalité de ce que
l'exécution peut modifier**.

Une exécution est donc autorisée à démarrer quand son répertoire est **un que ce
produit connaît déjà** :

- à l'intérieur de l'espace de travail
- à l'intérieur du répertoire propre d'un service
- **à un endroit que vous avez autorisé nommément**

Tout le reste est **retenu**, et apparaît sous **En attente de vous** avec un
bouton *Autoriser ce répertoire*. **Autoriser un endroit libère toutes les
exécutions qui l'attendaient.**

Si votre réglage d'autorisation est **Ne jamais demander**, **rien n'est retenu**.
Qui a coupé les autorisations l'a dit, et **le produit ne passe pas outre le
réglage qu'il a lui-même proposé**.

## En suivre une

**La sortie apparaît à mesure que l'agent la produit**, pas quand l'exécution se
termine. Une exécution de dix minutes **se lit pendant les dix**.

## La reprendre

**Une exécution terminée peut se poursuivre en conversation ordinaire** :
**Continue in a chat** ouvre un nouveau fil dans le même répertoire, avec **ce
qu'on lui a demandé et ce qu'elle a rapporté déjà dans le contexte**.

**On ne peut pas parler à l'exécution elle-même.** Voici la porte de retour.
