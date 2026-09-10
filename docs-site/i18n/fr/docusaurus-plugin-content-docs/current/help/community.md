---
title: Obtenir de l'aide
sidebar_position: 4
---

# Obtenir de l'aide, et où en parler

## Avant de demander

**L'essentiel de ce qui déraille la première semaine est dans**
[Dépannage](/help/troubleshooting), et la réponse à *mon fournisseur est-il pris
en charge* est dans [Fournisseurs](/getting-started/providers).

**Si l'agent parle mais ne touche jamais à vos fichiers, c'est presque toujours le
modèle et non l'installation** — [testez-le](/reference/checking-a-model) avant d'y
passer une soirée de configuration.

## Où demander

**[GitHub Issues](https://github.com/ai-dashboad/opencli/issues)** — les bugs, et
**tout ce qui s'est comporté autrement que ce que dit la documentation**.

**[GitHub Discussions](https://github.com/ai-dashboad/opencli/discussions)** —
questions, idées, et « est-ce censé marcher comme ça ».

**Il n'y a pas encore de serveur de discussion.** Il y en aura **quand il y aura
assez de monde pour que cela vaille la peine d'y être** ; **une salle vide n'aide
personne**.

## Ce qui rend un signalement exploitable

**Quatre lignes**, et **la plupart des signalements ne les ont pas** :

1. **Le modèle et le fournisseur, nommés exactement** — `qwen3-coder:30b` sur
   Ollama, pas « un modèle local ».
2. **Ce que vous lui avez demandé**, mot pour mot.
3. **Ce qui s'est passé**, et **ce que vous attendiez à la place**.
4. **Les cinquante dernières lignes de `~/.opencli/log`** autour de l'échec.

**Vérifiez que ces lignes ne contiennent pas de clés avant de les coller.**

## Ce qui aide le plus

**Une ligne dans le tableau des modèles.**
[Tester un modèle](/reference/checking-a-model) est une tâche fixe d'environ cinq
minutes. **Le tableau est court parce qu'il ne contient que ce qui a été
essayé**, et **un résultat négatif vaut autant qu'un positif** — **personne ne
publie sur le modèle qui n'a pas marché, alors tout le monde le redécouvre**.

**Une traduction, ou une correction sur l'une d'elles.** Dix sont fournies.
Chacune peut être **corrigée ligne par ligne sans toucher au reste** — voir
[Langues](/configuration/languages).

**Nous dire ce que vous cherchiez vraiment à faire.** Les services et procédures
fournis **ont été écrits à partir de suppositions sur ce dont les gens ont
besoin**. **Ce que vous avez cherché sans le trouver est la chose la plus utile que
vous puissiez dire.**

## Contribuer du code

[Contribuer](/reference/contributing) contient l'installation et le processus de
pull request.
