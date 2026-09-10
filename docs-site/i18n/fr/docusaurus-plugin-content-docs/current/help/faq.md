---
title: Questions fréquentes
sidebar_position: 1
---

# Les questions que les gens posent vraiment

## Mes données sont-elles envoyées quelque part ?

**Vers l'endpoint que vous avez configuré, et nulle part ailleurs.** **Il n'y a
aucune passerelle à nous au milieu**, pas de compte de télémétrie, et **aucune clé
gravée dans le binaire**.

Si cet endpoint est un modèle sur votre propre machine, **rien ne quitte la
machine**.

## Est-ce que ça marche hors ligne ?

**Oui, avec un modèle local.** L'application de bureau vérifie ses propres mises à
jour et le panneau Models récupère une liste de modèles populaires — **les deux
échouent silencieusement sans réseau, et aucun n'est nécessaire pour tenir une
conversation**.

## Ai-je besoin d'une clé d'API ?

**Non, si vous faites tourner un modèle en local.** Ollama, LM Studio, llama.cpp
et les autres ne demandent rien. Un fournisseur hébergé a besoin de sa clé, qui
**est conservée à l'écart du fichier de configuration et n'est plus jamais
affichée**.

## Quel modèle utiliser ?

**Celui que votre machine peut contenir**, avec **une exigence non négociable :
il doit appeler des outils.** Un modèle qui ne le fait pas **se limite ici à la
conversation**.

[Tester un modèle](/reference/checking-a-model) est un **test de cinq minutes**
qui répond à cette question. Le tableau qui s'y trouve est court parce qu'**il ne
contient que ce qui a été essayé**.

## Pourquoi est-ce moins bon que Claude Code / Codex ?

**Parce qu'un modèle de 27B quantifié pour tenir sur un portable n'est pas
GPT-5.** L'interface est la même ; **le raisonnement, non**.

**Ce que ce projet change, c'est la portée** — savoir si le modèle que vous avez
peut être utilisé ainsi — **pas son intelligence**.

## Peut-il utiliser GPT-5 ou Claude ?

**Oui.** Configurez OpenAI ou Anthropic comme n'importe quel autre fournisseur.
**Rien dans le produit ne préfère l'un à l'autre.**

## Où démarre une conversation ?

Dans `~/.opencli/workspace`, sauf si elle appartient à un service, auquel cas elle
démarre dans le répertoire de ce service.

**C'était autrefois votre dossier personnel. Ça ne l'est plus**, parce que la
racine inscriptible du bac à sable **est** le répertoire de travail — voir
[Bac à sable et autorisations](/configuration/sandbox-and-approvals).

## Plusieurs personnes peuvent-elles partager une installation ?

**Non.** La passerelle est **mono-utilisateur par conception** et **le dit dans son
propre code**. **Chacun fait tourner sa copie** ; un **serveur de modèles
partagé** derrière est l'arrangement habituel.

## Le travail planifié tourne-t-il pendant que mon portable dort ?

**Non.** Les tâches planifiées et les permanences ne tournent **que pendant
qu'OpenCLI est ouvert**, car **ceci est un agent local et non un serveur**. Tout
ce qui doit se déclencher machine endormie relève de `cron`, `launchd` ou du
Planificateur de tâches.

## En quoi est-ce différent d'Open WebUI ou de Jan ?

**Ce sont des interfaces de discussion pour modèles locaux, et de bonnes.**
**Ceci est un agent** : il lit et modifie vos fichiers, exécute des commandes et
**continue de travailler en arrière-plan**. **Ce n'est pas le même métier, et rien
n'empêche de faire tourner les deux.**

## En quoi est-ce différent de Codex, dont il est issu ?

**Codex est bâti pour les modèles d'OpenAI.** Les services, les bots, les
permanences, les exécutions en arrière-plan, les passations entre bots, les
procédures fournies et les dix langues d'interface **viennent de ce côté-ci de la
bifurcation**, avec **un travail conséquent sur ce qui casse quand le modèle est
petit**.

## Pourquoi dit-il que l'application est endommagée / non vérifiée ?

**Parce que les builds ne portent aucun certificat Apple ou Microsoft** — ceux-ci
**coûtent de l'argent chaque année et ce projet ne l'a pas dépensé**.
[Installation](/getting-started/install) dit exactement sur quoi cliquer.

## Puis-je changer son nom ?

**Pas encore.** L'identité visuelle est compilée dedans.

## Quelque chose est cassé. Où regarder ?

[Dépannage](/help/troubleshooting), puis les journaux dans `~/.opencli/log`, puis
[un ticket](https://github.com/ai-dashboad/opencli/issues).
