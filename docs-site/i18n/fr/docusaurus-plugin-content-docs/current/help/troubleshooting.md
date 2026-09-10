---
title: Dépannage
sidebar_position: 2
---

# Dépannage

## Il dit que les identifiants ont été refusés

```
The model provider would not accept the request without credentials.
(status 401 Unauthorized)
```

**Soit aucune clé n'est définie pour le fournisseur sélectionné, soit celle qui
l'est n'est pas valable pour lui.** Trois choses à vérifier, **dans cet ordre** :

1. **Quel fournisseur est réellement sélectionné** — `model` dans `config.toml`,
   ou le sélecteur au-dessus de la zone de saisie. **Pointer vers un modèle dont
   vous n'avez jamais configuré le fournisseur** est la cause habituelle.
2. **La variable d'environnement nommée par `env_key`** est bien définie dans le
   shell où tourne l'agent. **L'application de bureau la lit là où elle range vos
   clés, pas dans votre shell.**
3. **La clé appartient à ce fournisseur.** La clé de l'un n'est pas la clé de
   l'autre.

**Un 401 n'est délibérément pas réessayé** : **des identifiants ne deviennent pas
valides parce qu'on les propose une seconde fois.**

## La liste des modèles est vide

Le panneau **Models** et le sélecteur de la zone de saisie viennent tous deux du
`/v1/models` du fournisseur. **Une liste vide veut dire que cette requête a
échoué**, et la raison est dans `~/.opencli/log`.

**Un fournisseur qui exige une clé ne renvoie rien sans elle** : ceci et le 401
ci-dessus sont **le plus souvent le même problème**.

## Il répond, mais ne touche jamais à mes fichiers

**Votre modèle n'appelle pas les outils.** C'est **la déception la plus fréquente**,
et **ce n'est pas une erreur de configuration** : **certains modèles ne le font
tout simplement pas**.

[Testez-le](/reference/checking-a-model). Cinq minutes, une tâche fixe. **S'il
échoue, le modèle est le mauvais outil pour cela, et aucun réglage n'y changera
rien.**

## Il lance `grep` au lieu de lire le fichier correctement

**Le même manque de fond, sous une forme plus douce** : un modèle non entraîné au
travail d'agent **se rabat sur le shell même avec un outil de fichiers sous les
yeux**. **Rien dans l'interface ne comble cela.**

## Une exécution en arrière-plan dit qu'elle m'attend

**Son répertoire de travail n'est pas un que ce produit connaisse** — ni l'espace
de travail, ni le répertoire d'un service, ni **un endroit que vous avez autorisé
nommément**.

Soit **Autoriser ce répertoire** dans le panneau Dispatch, soit **Déplacer** la
tâche dans un service. **Elle est retenue plutôt que lancée parce qu'une exécution
peut écrire n'importe où dans son répertoire.**

## Une tâche planifiée n'a jamais tourné

**Deux possibilités** :

- **OpenCLI était fermé.** Le travail planifié ne tourne **que pendant qu'il est
  ouvert**.
- **Elle est retenue**, comme ci-dessus. Les tâches retenues apparaissent sous
  *En attente de vous*.

## La conversation n'arrête pas de se résumer

**Si elle résume et qu'il faut aussitôt recommencer, la longueur ne vient pas de
la conversation** : elle vient de **la partie fixe de chaque requête**, c'est-à-dire
surtout **des schémas d'outils de vos connecteurs**. **Quatre connecteurs peuvent
faire dix mille tokens avant que vous ayez dit quoi que ce soit.**

**Il le dit une fois plutôt que de recommencer à chaque tour.** Le remède est
**d'éteindre les connecteurs dont vous ne vous servez pas dans cette
conversation**.

## L'application de bureau ne s'ouvre pas

**macOS** : lancez `xattr -dr com.apple.quarantine /Applications/OpenCLI.app`, ou
clic droit → **Ouvrir**.

**Windows** : SmartScreen → **Informations complémentaires** → **Exécuter quand
même**.

Si elle refuse toujours, **le téléchargement est peut-être incomplet** — comparez
la taille du fichier avec la page de la version.

## L'agent a fait quelque chose que je n'ai pas vu

**Artifacts ne liste que les modifications faites avec l'outil d'édition de
fichiers de l'agent.** Les fichiers écrits par une commande shell qu'il a lancée —
un heredoc, un script, `git checkout` — **sont de vraies modifications qui n'y
apparaîtront pas**.

**`git status` dans le répertoire de travail est la réponse fiable.**

## L'interface est en anglais alors que j'ai choisi une autre langue

**Le dictionnaire est récupéré au moment où sa langue est choisie**, il y a donc
**un instant où l'anglais s'affiche**. S'il reste en anglais, **le fragment ne
s'est pas chargé** — regardez la console du navigateur dans les outils de
développement de l'application de bureau.

**Une phrase sans traduction affiche toujours l'anglais, par conception** ; c'est
**une traduction partielle, pas un défaut**.

## Où sont les journaux

```
~/.opencli/log
```

**Settings → About → Logs** ouvre le répertoire. Pour signaler un problème, **les
cinquante dernières lignes autour de l'échec suffisent presque toujours** — et
**vérifiez qu'elles ne contiennent pas de clés avant de les coller**.
