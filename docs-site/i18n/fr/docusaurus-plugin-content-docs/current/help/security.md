---
title: Sécurité
sidebar_position: 3
---

# Sécurité

**Ce que ce produit fait de votre machine et de vos données**, énoncé **pour que
vous puissiez décider plutôt que supposer**.

## Ce qui quitte votre machine

Vos prompts, et les fichiers que l'agent lit pour vous, vont **vers l'endpoint que
vous avez configuré** et nulle part ailleurs. **Il n'y a aucune passerelle à nous
au milieu.**

Si cet endpoint tourne sur votre propre machine, **rien n'en sort**.

**Deux exceptions**, qui toutes deux **échouent silencieusement hors ligne** et
dont **aucune ne transporte quoi que ce soit que vous ayez tapé** :

- l'application de bureau demande à son endpoint de mise à jour s'il existe une
  version plus récente
- le panneau Models récupère chez Hugging Face une liste de modèles populaires à
  son ouverture

## Ce que l'agent peut faire à votre machine

**Deux réglages, deux rôles différents.**

**Le bac à sable** décide de ce qu'il *peut* faire. Sous `workspace-write` — le
défaut — il peut écrire **n'importe où dans son répertoire de travail** et nulle
part ailleurs. **Les lectures ne sont restreintes dans aucun mode.**

**Les autorisations** décident de ce qu'il doit demander d'abord, depuis toute
commande inhabituelle jusqu'à rien du tout.

**La combinaison à surveiller est `danger-full-access` avec `never`** : un agent
**qui exécute des commandes arbitraires sans rien montrer ni rien demander**.
**Il existe des répertoires où c'est le bon choix. Votre dossier personnel n'en
fait pas partie.**

[Bac à sable et autorisations](/configuration/sandbox-and-approvals) donne le
détail.

## Où une exécution en arrière-plan peut démarrer

**Une exécution dont le répertoire n'est ni l'espace de travail, ni un service, ni
un endroit que vous avez autorisé nommément, est retenue** au lieu de démarrer.

Cela existe parce qu'**une tâche planifiée créée avant l'existence des services
portait un dossier personnel et avait tourné quarante-deux fois** : **chaque
exécution pouvant atteindre `.ssh` et `Documents`, sans que personne soit
consulté**.

**Mettre les autorisations sur `never` désactive cela en même temps que tout le
reste**, ce qui est précisément le sens de ce réglage.

## Clés

**Les clés d'API sont conservées hors de `config.toml`**, parce que **ce fichier se
partage et se colle dans des tickets**. Elles sont écrites là où sont vos autres
secrets, et **ne sont plus jamais affichées une fois enregistrées**.

**Les clés des connecteurs fonctionnent pareil** : vous nommez les variables
d'environnement dont un serveur a besoin, et **les valeurs sont stockées à part de
la configuration de ce serveur**.

## La passerelle

L'application de bureau et l'interface web parlent à **une passerelle locale**.
Elle :

- **se lie à la boucle locale** sauf instruction explicite contraire, de sorte
  qu'**elle n'est pas exposée au réseau par accident**
- **exige un jeton à chaque connexion**, généré par exécution et affiché une seule
  fois, pour qu'**un autre utilisateur local — ou une page web dans votre
  navigateur — ne puisse pas la piloter**

**Un client de cette passerelle peut faire exécuter des commandes à l'agent sur la
machine qui l'héberge.** C'est tout l'objet, **et c'est pourquoi le jeton
existe**.

**Elle est mono-utilisateur par conception.** Servir plusieurs personnes non
fiables demanderait **un cloisonnement par utilisateur**, ce qui est hors sujet.

## Téléphones appairés

**L'appairage remet à un appareil un jeton qui lui permet de piloter l'agent sur
cette machine.** L'adresse est affichée une seule fois. **N'appairez que vos
propres appareils, et révoquez tout ce que vous ne reconnaissez pas.**

## Les builds ne sont pas signés

**Aucun certificat Apple ou Microsoft**, votre système d'exploitation **ne peut
donc pas savoir qui les a construits, et il le dit**. **Cet avertissement est
exact et vous devriez le lire comme tel.**

Si vous préférez ne nous croire sur rien de tout cela, la source est
[ici](https://github.com/ai-dashboad/opencli) et c'est **un `cargo build`**.

## Signaler quelque chose

**N'ouvrez pas de ticket public pour une faille de sécurité.** Utilisez le
[formulaire d'avis privé](https://github.com/ai-dashboad/opencli/security/advisories/new)
de GitHub, qui **atteint les mainteneurs sans rien publier**.

**Ce qui mérite le plus d'être examiné est ce qui figure sur cette page** : la
politique du bac à sable, le chemin d'autorisation, la vérification de répertoire
des exécutions en arrière-plan, et le jeton de la passerelle.

**N'y joignez pas vos clés, ni des journaux qui en contiennent.**
