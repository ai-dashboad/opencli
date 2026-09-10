---
title: Surveiller un dossier
sidebar_position: 2
---

# Surveiller un dossier et rapporter ce qui a changé

**Dix minutes.** À la fin, vous avez **quelque chose qui vous rédige un court
compte rendu de ce qui a bougé dans un répertoire, au rythme que vous
choisissez** : un projet, un lecteur partagé, **un dossier où quelqu'un d'autre
n'arrête pas de déposer des choses**.

## 1. Pointez une conversation vers le dossier

Ouvrez une nouvelle conversation et utilisez le bouton dossier au-dessus de la
zone de saisie pour choisir le répertoire.

**Cela compte plus qu'il n'y paraît** : **l'agent peut écrire n'importe où dans le
répertoire où une conversation est ouverte**, et nulle part en dehors.
**Choisir le dossier, c'est choisir le rayon de l'explosion.**

## 2. Demandez le compte rendu une fois

```
Utilise la compétence weekly-report sur ce dossier.
```

La compétence `weekly-report` est fournie avec le produit. **Elle détermine ce
qui a changé** — depuis git si le dossier est un dépôt, depuis les dates de
modification sinon — et écrit trois sections : **ce qui est terminé, ce qui est
en cours, et ce qui demande une décision**.

**C'est cette dernière section qui justifie la lecture.**

## 3. Mettez-la sur une planification

**Exécutions en arrière-plan → planifier une exécution répétée :**

| Champ | |
| --- | --- |
| **Ce qu'elle doit faire** | Utilise la compétence weekly-report sur ce dossier. Enregistre-la sous `report-<date>.md`. |
| **Nom** | Compte rendu hebdomadaire |
| **À quelle fréquence** | 7 jours |
| **Où l'exécuter** | le dossier que vous avez choisi |

## 4. Vérifiez où elle va tourner

**Si le dossier n'est ni dans votre espace de travail ni un service, la première
exécution sera retenue** au lieu de démarrer, et apparaîtra sous *En attente de
vous*.

**C'est délibéré.** Autorisez le répertoire, ou déplacez la tâche dans un service.

## 5. Lisez le premier

**Run now**, puis ouvrez l'exécution pour **lire la sortie à mesure qu'elle est
produite**.

**Si le compte rendu est maigre, la semaine du dossier a été maigre** : la
compétence a pour consigne de **le dire en une ligne plutôt que de meubler**, car
**un compte rendu gonflé à partir d'une semaine vide apprend aux gens à sauter
les comptes rendus**.

## Faire cela sur le dossier de quelqu'un d'autre

**Deux points à surveiller.**

**L'agent lit tout ce vers quoi on le pointe**, et **les lectures ne sont
restreintes par le bac à sable dans aucun mode**. **Un dossier contenant des
choses que vous n'enverriez pas à votre fournisseur de modèle ne devrait pas être
celui que vous visez** — **sauf si votre modèle tourne sur votre propre machine**,
auquel cas rien n'en sort.

**Une planification survit à votre attention.** Quelque chose qui tourne chaque
semaine pendant un an, ce sont **cinquante-deux exécutions que vous n'avez pas
regardées**. **Gardez le répertoire étroit.**
