---
title: Installation
sidebar_position: 1
---

# Installation

## Application de bureau

Téléchargez-la depuis [opencli.ai/download](https://opencli.ai/download.html),
ou prenez-la directement dans la dernière version :

| Plateforme | Téléchargement |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

**Chaque lien pointe toujours vers la version la plus récente**, il continue
donc de fonctionner au fil des versions.

Ensuite, **l'application se met à jour toute seule**.

### Votre ordinateur vous avertira la première fois

Ces builds ne sont **pas signés** avec un certificat Apple ou Microsoft. Ces
certificats coûtent de l'argent chaque année et ce projet ne l'a pas dépensé.
**Le téléchargement n'a rien d'anormal** : le système d'exploitation ne peut
pas savoir qui l'a construit.

**macOS** — après avoir glissé OpenCLI dans Applications, lancez une fois :

```shell
xattr -dr com.apple.quarantine /Applications/OpenCLI.app
```

ou faites un clic droit sur l'application, choisissez **Ouvrir** et confirmez.
**Uniquement au premier lancement.**

**Windows** — SmartScreen affiche un cadre bleu. Cliquez sur **Informations
complémentaires**, puis sur **Exécuter quand même**.

## Ligne de commande

Un binaire, macOS et Linux :

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

**Il détecte votre plateforme**, récupère la build correspondante et met
`opencli` dans `/usr/local/bin` — ou dans `~/.local/bin` s'il ne peut pas y
écrire, en vous disant de l'ajouter à votre `PATH`.

**Le paquet npm n'est pas encore publié** : le scope `@ai-dashboad` n'est pas
enregistré. En attendant, **l'installateur ci-dessus et les builds de bureau
sont les deux voies**.

## Depuis les sources

Une chaîne d'outils Rust récente :

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

Le binaire se trouve dans `opencli-rs/target/release/opencli`.

## Ce qu'il a écrit, et où

| | |
| --- | --- |
| `~/.opencli/config.toml` | fournisseurs, modèles, réglages d'autorisation et de bac à sable |
| `~/.opencli/workspace/` | là où démarre une conversation quand rien d'autre ne l'indique |
| `~/.opencli/skills/` | compétences, y compris celles fournies |
| `~/.opencli/locales/` | les langues que vous ajoutez |
| `~/.opencli/log/` | journaux |

**Rien n'est écrit en dehors de `~/.opencli` tant que vous n'avez pas pointé
l'agent vers un répertoire.**

## Ensuite

[Pointez-le vers un modèle](/getting-started/point-at-a-model) — il n'en
contient aucun et **ne répondra pas tant qu'il n'aura pas où demander**.
