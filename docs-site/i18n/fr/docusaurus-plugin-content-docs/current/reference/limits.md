---
title: Limites
sidebar_position: 2
---

# Limites

**Dit ici plutôt que découvert plus tard.**

## Les modèles

**Un petit modèle local n'est pas aussi bon à cela qu'un modèle de pointe.**
L'interface est la même ; **le raisonnement, non**.

**Les modèles ouverts généralistes se rabattent sur `grep` alors qu'ils ont un
outil de fichiers.** Même avec une manière structurée de lire un fichier, un
modèle non entraîné au travail d'agent **passera quand même par le shell**.
**C'est un manque des modèles, et aucune interface ne le comble.** **Ce que ce
projet peut changer, c'est la portée, pas l'intelligence.**

**Un modèle qui n'appelle pas les outils ne peut pas faire ce travail du tout.**
Il discutera. [Testez le vôtre](/reference/checking-a-model) avant de vous y
engager — cinq minutes, une tâche fixe.

## Le comptage

**Les nombres de tokens sont estimés, jamais comptés.** Le tokeniseur appartient
au modèle, et **ceci fait tourner des modèles qu'il n'a jamais vus**. Quatre
octets ASCII par token, un token par caractère sinon : **juste aussi bien pour
l'anglais que pour le chinois**, et **penchant vers le surcomptage** ailleurs.

**Tout ce qui en découle est donc approximatif** : le moment où une conversation
est résumée, celui où la sortie d'un outil est coupée, et ce que dit la ligne
d'usage.

## La planification

**Les tâches planifiées et les permanences ne tournent que pendant qu'OpenCLI est
ouvert.** **Ceci est un agent local, pas un serveur.** Tout ce qui doit se
déclencher machine endormie relève **du planificateur du système d'exploitation**.

## Le bac à sable

**Une exécution en arrière-plan peut écrire n'importe quoi dans le répertoire où
elle tourne.** **La racine inscriptible *est* ce répertoire.** Les exécutions hors
du répertoire d'un service **sont retenues jusqu'à ce que vous autorisiez
l'endroit nommément** — **sauf si les autorisations sont sur never**, auquel cas
rien n'est retenu.

**Les lectures ne sont jamais restreintes**, dans aucun mode de bac à sable.

## Le relevé de ce qui a changé

**Artifacts ne liste que les modifications faites avec l'outil d'édition de
fichiers de l'agent.** Les fichiers écrits par une commande shell qu'il a lancée —
un heredoc, un script, `git checkout` — ne sont pas suivis et n'apparaîtront pas.
**La modification est réelle ; c'est la liste qui est incomplète.**

## Les builds de bureau

**Ils ne sont pas signés** avec un certificat Apple ou Microsoft. Votre système
d'exploitation vous avertira, **et il a raison** : **il ne peut pas savoir qui les
a construits**. [Installation](/getting-started/install) dit quoi faire.

## L'interface

**Les langues de droite à gauche ne sont pas prises en charge.** L'arabe,
l'hébreu et le persan peuvent être ajoutés comme fichiers de traduction, et **la
page restera composée de gauche à droite**. **C'est une modification de la feuille
de style, pas d'une traduction.**

## L'escalade est une consigne, pas une garantie

Le *escalader si* d'une permanence **est donné au modèle comme une obligation**.
**Il n'est pas évalué par ce produit**, ce qui veut dire qu'il est **exactement
aussi fiable que le modèle qui le lit**. Écrivez-le comme quelque chose de
vérifiable — *une seule ligne dépasse 10 000* — plutôt que *quoi que ce soit
d'inhabituel*.
