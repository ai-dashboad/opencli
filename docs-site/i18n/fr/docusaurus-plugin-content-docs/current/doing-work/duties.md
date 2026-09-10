---
title: Permanences
sidebar_position: 2
---

# Permanences

**Une permanence est un travail qu'un bot effectue à intervalle régulier**, et
qui **s'arrête pour vous demander quand il atteint quelque chose qu'il ne
devrait pas trancher seul.**

**C'est cette dernière partie qui compte.** N'importe quoi sait lancer un prompt
sur une minuterie ; ce qui rend ceci utile pour du vrai travail, c'est qu'on lui
a dit **à l'avance ce qu'il n'a pas le droit de régler.**

## Les quatre champs

```
Quoi            Compare ledger.csv et statement.csv, ligne à ligne,
                et liste ce qui ne correspond pas, avec sa référence et son montant.

Règles          Un écart inférieur à 1,00 est un arrondi. Ignore-le.

Escalader si    Une seule ligne dépasse 10 000.

Tous les        24 heures
```

**« Quoi » et « Règles » sont séparés exprès.** Le travail est le même chaque
matin ; **le plafond de remboursement est une politique que quelqu'un révise.**
Fondus en un seul prompt, changer ce nombre oblige à **relire toute la consigne
pour le trouver.**

**« Escalader si » s'écrit en mots, pas comme une condition.** C'est donné au
modèle **comme une obligation, ce n'est pas évalué par le produit** — donc c'est
**aussi fiable que le modèle qui le lit.** Écrivez-le comme quelque chose de
vérifiable : *une seule ligne dépasse 10 000*, pas *quoi que ce soit
d'inhabituel*.

## Ce qui se passe à l'escalade

**La permanence s'arrête.** Elle apparaît dans **Bots → En attente de vous** avec
la question à laquelle elle n'a pas pu répondre, et **ne repartira pas tant que
vous n'aurez pas répondu.**

**Votre réponse est reportée dans l'exécution suivante**, le bot ne pose donc pas
deux fois la même question.

**Une permanence qui a déjà demandé n'ouvrira pas une deuxième question** : elle
répète celle qui est en suspens.

## Ce qu'elle retient

**Une permanence garde des notes d'une exécution à l'autre.** Une exécution qui a
appris une chose **note cette chose** ; elle n'a pas à redire ce qu'elle savait
déjà, et **une exécution qui a échoué à mi-chemin n'emporte pas le reste des
notes avec elle.**

**Écrire une valeur vide, c'est ainsi qu'on oublie quelque chose exprès.**

## Où elle s'exécute

**Dans le répertoire du service du bot**, qui est **la totalité de ce que
l'exécution peut écrire.** Une permanence pointée ailleurs **est retenue jusqu'à
ce que vous autorisiez cet endroit nommément** — voir
[Bac à sable et autorisations](/configuration/sandbox-and-approvals).

## Permanences et tâches planifiées

**Les deux lancent un prompt sur une minuterie.** La différence, c'est **ce à quoi
elles appartiennent.**

| | Appartient à | Escalade | Retient |
| --- | --- | --- | --- |
| **Permanence** | un bot, dans un service | oui | oui |
| **Tâche planifiée** | rien | non | non |

Prenez une tâche planifiée pour *chaque matin à neuf heures, dis-moi ce qui a
changé*. Prenez une permanence pour **du travail auquel est attachée une
politique**.
