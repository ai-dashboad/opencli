---
title: Rapprocher un grand livre
sidebar_position: 1
---

# Rapprocher un grand livre, de bout en bout

**Vingt minutes, avec un modèle local.** À la fin, vous avez **un service qui
compare deux fichiers chaque matin et s'arrête pour vous demander dès qu'il
trouve quelque chose au-dessus d'un seuil que vous fixez**.

**Tout ici utilise les données d'exemple fournies**, il n'y a donc **rien à
préparer**.

## 1. Créer le service

**Projects → ou partez d'un service qui marche déjà → Finance.**

Il crée `~/.opencli/workspace/finance`, y écrit trois fichiers et embauche deux
bots.

**Des problèmes ont été plantés exprès dans les fichiers** :

| Fichier | Ce qu'il contient |
| --- | --- |
| `ledger.csv` | ce que disent vos livres |
| `statement.csv` | ce que dit la banque |
| `overdue.csv` | les factures échues |

## 2. Le lui demander une fois, à la main

Ouvrez le service et tapez :

```
Compare ledger.csv et statement.csv. Liste chaque ligne qui ne correspond pas,
avec la référence et le montant, et dis ce qui s'est passé selon toi.
```

**Regardez ce qu'il fait.** Un modèle adapté **lira les deux fichiers avec un
outil** et **répondra avec des lignes et des références**. Un modèle inadapté
**vous demandera de coller le contenu ou répondra par des généralités** — si cela
arrive, **c'est le modèle le problème, pas l'installation**.
[Testez-le](/reference/checking-a-model).

## 3. En faire une permanence

**Le bot l'a fait une fois.** Une permanence fait que **cela revient tout seul**.

Ouvrez le bot **Reconciler** et réglez sa permanence :

| Champ | Ce qu'il faut mettre |
| --- | --- |
| **Quoi** | Compare `ledger.csv` et `statement.csv` ligne à ligne. Liste ce qui ne correspond pas, avec la référence et le montant. |
| **Règles** | Un écart inférieur à 1,00 est un arrondi. Ignore-le. |
| **Escalader si** | Une seule ligne dépasse 10 000. |
| **Tous les** | 24 heures |

**« Règles » et « Quoi » sont séparés pour une raison** : le travail est le même
chaque matin, et **le seuil est une politique que quelqu'un révise**. Fondus en un
seul prompt, changer le nombre oblige à **relire toute la consigne pour le
trouver**.

## 4. Le voir s'arrêter

**Run now.** **Les données d'exemple contiennent un écart au-dessus du seuil** :
la permanence n'ira donc pas au bout — **elle apparaîtra dans Bots → En attente de
vous avec la question à laquelle elle n'a pas pu répondre**.

**C'est tout l'intérêt de la fonction.** Elle a fait le travail, **a atteint la
ligne que vous avez tracée, et s'est arrêtée au lieu de décider**.

Répondez-lui. **Votre réponse est reportée dans l'exécution suivante**, elle ne
pose donc pas deux fois la même question.

## 5. Passer le résultat

Le service Finance est livré avec un second bot, **Chaser**. Dans la liste **peut
passer à** du Reconciler, cochez-le.

Désormais, une exécution qui trouve des lignes non rapprochées peut les
transmettre — **avec ce qu'elle a fait et les fichiers qu'elle a produits** — et le
Chaser **rédige une relance par client sans qu'on lui explique le contexte**.

**Bots → Travail passé entre bots** montre ensuite la chaîne, et **marque celle
qui s'est arrêtée faute de sauts** plutôt que parce qu'elle avait fini.

## Ce que vous avez maintenant

- **un répertoire où l'agent peut écrire, et nulle part ailleurs**
- **du travail qui se fait sans que vous le lanciez**
- **un seuil écrit auquel il s'arrête et demande**
- **un second bot qui reprend là où le premier s'est arrêté**

## Ce qu'il faut changer en premier

**Le seuil.** 10 000 **est un nombre tiré d'un exemple. Le vôtre ne l'est pas.**

**Les règles.** « Un écart inférieur à 1,00 est un arrondi » **est vrai pour
certains livres et pas pour d'autres**.

**L'intervalle.** Toutes les 24 heures **est une habitude, pas une loi**. **Une
permanence qui tourne après la comptabilisation par la banque est plus utile
qu'une qui tourne à minuit.**
