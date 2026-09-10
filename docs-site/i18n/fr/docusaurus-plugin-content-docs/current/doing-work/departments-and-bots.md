---
title: Services et bots
sidebar_position: 1
---

# Services et bots

**Une conversation n'est qu'une conversation.** Le travail qui revient a besoin
de quelque chose **qui lui survive**.

| | C'est | Ça vit dans |
| --- | --- | --- |
| **Service** | un répertoire plus des consignes permanentes | `~/.opencli/workspace/<nom>` par défaut |
| **Bot** | une conversation dans un service, avec un travail | ce service |
| **Permanence** | un travail qui revient tout seul | un bot |

**Le vocabulaire est emprunté au bureau exprès.** Un service n'est pas un dossier
avec un joli nom : c'est **la limite de ce que le travail à l'intérieur peut
toucher**.

## Partir d'un service qui marche déjà

**Neuf services sont fournis avec des données d'exemple** — des fichiers dans
lesquels des problèmes ont été plantés — pour que la première exécution
**fasse quelque chose** au lieu d'expliquer qu'il n'y a rien à faire.

| Service | Ce qui vient avec |
| --- | --- |
| Finance | Rapprocher `ledger.csv` de `statement.csv` ; relancer les impayés |
| Support | Répondre à ce qui est arrivé ; regrouper les questions par ce dont elles parlent vraiment |
| Opérations | Lister toute commande non expédiée, et depuis combien de temps elle attend |
| Marketing | Transformer des notes en une semaine de publications ; regrouper les contacts par achat |
| RH et administration | Lire des candidatures face à un poste ; extraire décisions et responsables des notes |
| Juridique | Comparer leur projet à nos conditions, clause par clause, en citant les deux |
| Recherche | Là où les études s'accordent, là où elles se contredisent, et pourquoi |
| Dossiers cliniques | Ce qui est consigné, et ce qu'un clinicien devrait regarder, cité |
| Ingénierie | Lire un service et signaler ce qui donnerait une réponse fausse |

**Projects → ou partez d'un service qui marche déjà.** Il crée le répertoire,
écrit les fichiers d'exemple et embauche les bots.

## Créer le vôtre

**Projects → New**, puis :

- **Nom** — comment il s'appelle
- **Dossier** — créé s'il n'existe pas
- **Consignes permanentes** — données à l'agent dans ***chaque*** conversation
  ouverte ici

**Les consignes permanentes sont l'endroit où va ce que vous retaperiez sinon** :
comment construire, à quoi ne pas toucher, quels chiffres relèvent de la
politique. Elles sont distinctes de la description, que **vous seul lisez**.

## Bots

**Un bot est une conversation qui a un travail.** Ce travail est réinjecté
**chaque fois que le bot est réveillé**, il n'a donc pas besoin qu'on lui
rappelle à quoi il sert.

Quatre états, dans le panneau **Bots** :

| | |
| --- | --- |
| **Au repos** | rien à faire |
| **Au travail** | une exécution est en cours |
| **En attente de vous** | il s'est arrêté et a demandé — voir [Permanences](/doing-work/duties) |
| **En erreur** | la dernière exécution a échoué |

## Des bots qui se passent le travail

Un bot peut passer du travail à un autre **en le nommant**, avec ce qu'il a fait
et les fichiers qu'il a produits. Celui qui reçoit **part de là, pas de rien**.

**Trois refus** empêchent que cela s'emballe, et ils en sont la substance :

- **Profondeur.** Une chaîne est plafonnée à **huit sauts**.
- **Répétition.** Aucun bot ne peut apparaître **plus de trois fois** dans une
  chaîne.
- **Sens.** Un bot ne peut recevoir du travail **que d'un service autorisé**. Au
  sein d'un même service, c'est toujours permis.

Le panneau **Bots** montre chaque chaîne et **marque celles qui se sont arrêtées
faute de corde** plutôt que parce qu'elles avaient fini.

## Ensuite

[Permanences](/doing-work/duties) — du travail qui revient sans que vous le
lanciez.
