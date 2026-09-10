---
title: Bac à sable et autorisations
sidebar_position: 2
---

# Bac à sable et autorisations

**Deux réglages, deux rôles différents.** Le bac à sable décide de ce que l'agent
***peut*** faire ; les autorisations décident de **ce qu'il doit demander
d'abord**.

## Le bac à sable

```toml
sandbox_mode = "workspace-write"
```

| | L'agent peut |
| --- | --- |
| `read-only` | regarder les fichiers, pas les modifier |
| `workspace-write` | écrire dans son répertoire de travail |
| `danger-full-access` | tout ce que votre compte peut faire |

**Les lectures ne sont jamais restreintes.** Seuls l'écriture et l'accès réseau
le sont : `read-only` signifie donc que **l'agent voit tout votre disque et n'en
change rien**.

### La racine inscriptible est le répertoire de travail

Sous `workspace-write`, « l'espace de travail » désigne **le répertoire dans
lequel la conversation ou l'exécution est ouverte**. Pas le projet, pas le dépôt
— **ce répertoire-là**.

**C'est la phrase la plus importante de cette page.** Une exécution ouverte dans
votre dossier personnel peut écrire dans `.ssh`, `Documents` et `Library`.

**Ce n'est pas une hypothèse.** Une tâche planifiée créée avant l'existence des
services **portait le dossier personnel et avait tourné quarante-deux fois
ainsi**, chaque exécution pouvant tout atteindre, **sans que personne soit
consulté ni que rien soit dit**. Changer la valeur par défaut pour les nouvelles
conversations n'y a rien changé, parce qu'**un défaut n'est pas rétroactif**.

D'où **une seconde vérification, au moment où une exécution démarre**.

## Où une exécution en arrière-plan peut démarrer

Une exécution est autorisée à commencer quand son répertoire est **un que ce
produit connaît déjà** :

- à l'intérieur de l'espace de travail
- à l'intérieur du répertoire d'un service
- **à un endroit que vous avez autorisé nommément**

Tout le reste est **retenu**, et apparaît sous **En attente de vous** dans le
panneau Dispatch avec un bouton *Autoriser ce répertoire*. **Autoriser un endroit
libère toutes les exécutions qui l'attendaient.**

**Le fait de demander est le sujet** : tourner à un endroit inhabituel est
souvent **exactement ce qu'on voulait**, et la réponse est **une question, pas un
refus**.

## Autorisations

```toml
approval_policy = "on-failure"
```

| | |
| --- | --- |
| `untrusted` | toute commande non connue comme sûre est montrée d'abord |
| `on-failure` | les commandes s'exécutent sans surveillance ; on vous demande quand l'une a besoin de plus d'accès |
| `never` | rien n'est montré avant l'exécution |

`never` veut dire aussi que **rien n'est retenu**. Qui a coupé les autorisations
**a dit, en toutes lettres, qu'il ne voulait pas être arrêté**, et **décider qu'il
voulait dire quelque chose de plus étroit reviendrait pour le produit à passer
outre son propre réglage**.

À utiliser pour un répertoire **dans lequel vous lâcheriez un script**.

## La combinaison qui piège

`sandbox_mode = "danger-full-access"` avec `approval_policy = "never"`, c'est **un
agent qui exécute des commandes arbitraires sur votre machine sans rien montrer
ni rien demander**. **Il existe des répertoires où c'est la bonne réponse. Votre
dossier personnel n'en fait pas partie.**

## Deux choses que le bac à sable ne fait pas

- **Il n'empêche pas le modèle de lire vos fichiers.** Les lectures ne sont
  restreintes **dans aucun mode**.
- **Il ne couvre pas ce que fait ensuite une commande qu'il a lancée.** Un script
  que l'agent démarre hérite du bac à sable ; **un service qu'il démarre et qui
  survit à l'exécution, non**.
