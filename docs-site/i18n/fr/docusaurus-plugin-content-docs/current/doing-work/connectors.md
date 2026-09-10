---
title: Connecteurs
sidebar_position: 5
---

# Connecteurs

**Un connecteur est un serveur MCP par lequel l'agent peut appeler des outils** :
GitHub, une base de données, un navigateur, vos fichiers. C'est **la façon dont
l'agent atteint quelque chose qui n'est pas un fichier de cette machine**.

## En ajouter un

**Abilities → Connectors** liste ce qui est configuré et ce qui peut être ajouté.
Ajouter depuis le catalogue tient en un clic ; ajouter le vôtre demande un nom et
soit une commande, soit une URL :

| | |
| --- | --- |
| **Commande locale** | un programme de cette machine, lancé par OpenCLI |
| **Serveur HTTP** | un serveur joignable en HTTP |

## Clés

**La plupart des connecteurs en demandent une.** Nommez les variables
d'environnement attendues par le serveur — **les noms seulement**, séparés par
des espaces — et **renseignez les valeurs ensuite**.

**Les valeurs sont conservées avec vos autres clés, pas dans la configuration du
connecteur**, et **ne sont plus jamais affichées une fois enregistrées**. C'est
délibéré : **le fichier de configuration se partage et se colle dans des tickets,
et une clé qui s'y trouve part avec lui.**

## Tester

**Test connections** démarre tous les serveurs configurés et attend une poignée de
main. C'est un bouton, et non quelque chose qui se produit à l'ouverture du
panneau, parce que **les démarrer prend des secondes** — mesurées à **2,2** sur
un serveur dont l'authentification échoue.

Le résultat s'affiche sur chaque ligne, **avec les outils que ce serveur propose**.

## Quand un changement prend effet

**Les serveurs démarrent avec une conversation.** Un connecteur ajouté maintenant
s'applique à la **prochaine** conversation que vous ouvrirez, pas à celle qui est
devant vous.

## Ce qu'un connecteur n'est pas

**Ce n'est pas une capacité que le modèle acquiert.** Un modèle qui n'appelle pas
d'outils **ne se met pas à en appeler parce qu'un connecteur a été ajouté** —
voir [Limites](/reference/limits).

## Services

Les puces au-dessus de la liste filtrent par service : on peut ainsi demander à
un service Finance tout juste créé *à quoi ceci devrait être connecté* plutôt que
*qu'est-ce que Playwright*.

**Un connecteur sans étiquette de service apparaît sous toutes les puces** :
**ce que personne n'a classé ne devrait pas être caché à tout le monde.**
