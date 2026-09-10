<div align="center">

<img src="../website/public/favicon.svg" width="80" alt="OpenCLI" />

# OpenCLI

**Un agent open source pour les modèles que vous faites tourner vous-même**

[![CI](https://img.shields.io/github/actions/workflow/status/ai-dashboad/opencli/rust-ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/ai-dashboad/opencli/actions/workflows/rust-ci.yml)
[![Release](https://img.shields.io/github/v/release/ai-dashboad/opencli?style=flat-square)](https://github.com/ai-dashboad/opencli/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ai-dashboad/opencli/total?style=flat-square)](https://github.com/ai-dashboad/opencli/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat-square)](../LICENSE)

[English](../README.md) ·
[简体中文](./README.zh-CN.md) ·
[繁體中文](./README.zh-TW.md) ·
[日本語](./README.ja.md) ·
[한국어](./README.ko.md) ·
[Español](./README.es.md) ·
[Português](./README.pt-BR.md) ·
**Français** ·
[Deutsch](./README.de.md) ·
[Русский](./README.ru.md)

[Télécharger](https://opencli.ai/download.html) ·
[Documentation](https://docs.opencli.ai) ·
[Démarrer](https://docs.opencli.ai/getting-started/install) ·
[Fournisseurs](https://docs.opencli.ai/getting-started/providers) ·
[Limites](https://docs.opencli.ai/reference/limits)

</div>

OpenCLI est un agent qui tourne sur votre propre ordinateur et fonctionne avec n'importe quel modèle compatible avec l'API OpenAI — un sur la machine devant vous, un sur votre propre serveur, ou un fournisseur hébergé quand cela vous arrange. Il lit vos fichiers, exécute vos commandes et modifie votre travail, dans un terminal et dans une application de bureau qui partagent les mêmes conversations.

**Rien n'est intégré.** Ni modèles, ni comptes, ni clés, ni avis sur celui à qui vous achetez votre inférence. Pointez-le vers un endpoint et ses modèles apparaissent d'eux-mêmes ; ce que vous tapez y va et nulle part ailleurs.

## Télécharger

| Plateforme | |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

L'application se met ensuite à jour toute seule. Ces versions ne portent aucun certificat Apple ou Microsoft, le premier lancement demande donc une étape de plus — [la marche à suivre](https://docs.opencli.ai/getting-started/install).

**Ligne de commande, macOS et Linux :**

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

Pointez-le ensuite vers un modèle.

## Ce qu'il fait

- 🗂 **Il travaille sur des fichiers, pas seulement du code.** Il lit un dossier de factures comme il lit un dépôt — et l'essentiel du travail que les gens ont vraiment est du premier type.

- 🏢 **Organisé comme un bureau.** Un **service** est un répertoire avec des consignes permanentes. Un **bot** est une conversation à l'intérieur, avec une fonction. Neuf services arrivent avec des données d'exemple, chacun peut donc être essayé avant d'être configuré.

- ⏰ **Les permanences reviennent toutes seules** — et **s'arrêtent pour vous demander** quand elles atteignent quelque chose qu'elles ne devraient pas trancher seules. Cette limite s'écrit en toutes lettres, à l'avance : *toute ligne au-dessus de 10 000*.

- 🤝 **Les bots se passent le travail,** avec ce qu'ils ont fait et les fichiers qu'ils ont produits. Plafonné à huit passages et trois apparitions chacun, pour qu'une chaîne ne s'emballe pas.

- 🧰 **Six procédures sont fournies comme compétences** et fonctionnent dans n'importe quel répertoire : vérifier des lignes au regard de leurs règles, rapporter ce qui a changé sur une semaine, trier une boîte de réception, comparer deux versions, transformer une transcription en décisions et responsables, et lire des dossiers pour ce qui mérite vérification.

- 🔌 **Les connecteurs sont des serveurs MCP** — GitHub, Postgres, Slack, Notion, un navigateur. Les clés sont tenues à l'écart du fichier de configuration, qui finit par être partagé.

- 🚦 **Un bac à sable dont on voit le bord.** Une exécution peut écrire dans son propre répertoire et nulle part ailleurs, et une exécution pointée vers un endroit inhabituel est retenue jusqu'à ce que vous autorisiez cet endroit nommément.

- 🌍 **Dix langues,** et toute autre tient dans un fichier JSON que vous ajoutez sans rien recompiler.

- 💻 **Terminal, bureau et une interface web locale** sur la même passerelle : une conversation commencée dans l'un se poursuit dans l'autre.

## Fonctionne avec

Pas trente intégrations — **un protocole**. Tout ce qui répond à `/v1/chat/completions` et `/v1/models` comme le fait OpenAI peut être visé, et ses modèles apparaissent d'eux-mêmes. On a demandé sa liste de modèles à chaque endpoint ci-dessous avant de l'inscrire ici.

**Sur votre machine** — Ollama · LM Studio · llama.cpp · LocalAI · Jan ·
Xinference · KoboldCpp · llamafile

**Sur votre serveur** — vLLM · SGLang · Text Generation Inference · NVIDIA NIM ·
LiteLLM

**Hébergeant des modèles ouverts** — Fireworks · Together · Groq · DeepInfra · Baseten ·
Novita · Hyperbolic · Nebius · Cerebras · SambaNova · Featherless · Chutes ·
NVIDIA · Hugging Face · OpenRouter · Vercel AI Gateway · Perplexity

**En Chine** — 硅基流动 · 无问芯穹 · PPIO · 七牛云 · 魔搭 · 阿里云百炼 ·
火山方舟 / 豆包 · 百度千帆 · 讯飞星火 · 小米 MiMo · DeepSeek · 智谱 ·
月之暗面 · MiniMax · 阶跃星辰 · 腾讯混元 · 百川

**Modèles fermés, si vous en voulez un** — OpenAI · Anthropic · Mistral · xAI

**Plusieurs offrent un quota gratuit**, ce qui est la façon la moins chère d'essayer un modèle plus gros que ce que votre machine peut contenir. Les endpoints, et qui sert quel modèle : [Fournisseurs](https://docs.opencli.ai/getting-started/providers).

> **Être joignable n'est pas la même chose qu'être bon à cela.** L'appel d'outils sépare un modèle capable de faire ce travail d'un modèle qui sait seulement en parler, et la fiche du modèle ne le dit jamais.
> [Vérifiez le vôtre](https://docs.opencli.ai/reference/checking-a-model) —
> une tâche fixe, cinq minutes. Le tableau a une ligne parce qu'un seul modèle a été essayé — **y ajouter une ligne est la contribution la plus utile qui soit.**

## Ce qu'il ne sait pas faire

- **Les modèles ouverts généralistes se rabattent sur `grep` même avec un outil de fichiers.** C'est un manque des modèles ; aucune interface ne le comble.
- **Les jetons sont estimés, jamais comptés.** Le tokeniseur appartient au modèle, et ceci fait tourner des modèles qu'il n'a jamais vus.
- **Le travail planifié ne tourne que tant qu'OpenCLI est ouvert.** C'est un agent local, pas un serveur.
- **Une exécution en arrière-plan peut écrire n'importe quoi dans le répertoire où elle tourne.**
- **Les versions bureau ne sont pas signées.** Votre système d'exploitation a raison de vous avertir.
- **Les langues écrites de droite à gauche ne sont pas encore mises en page.**

[Limites](https://docs.opencli.ai/reference/limits) explique le pourquoi de chacun.

## D'où cela vient

Un fork de [Codex CLI d'OpenAI](https://github.com/openai/codex), Copyright 2025 OpenAI, Apache-2.0. **Sans lien avec OpenAI.**

Codex est fait pour les modèles d'OpenAI et ceci est fait pour ceux de tous les autres, ce qui change plus qu'un nom. Les services, les bots, les permanences, les exécutions en arrière-plan et les procédures sont de notre fait, tout comme une bonne part du travail sur ce qui casse quand le modèle est petit — une boucle de compactage qui résumait une fois par tour pendant onze tours en jetant le fil à chaque fois, et une estimation de jetons qui lisait une page de chinois pour les trois quarts de son coût réel.

[Apache-2.0](../LICENSE) · [NOTICE](../NOTICE) ·
[Contribuer](https://docs.opencli.ai/reference/contributing)
