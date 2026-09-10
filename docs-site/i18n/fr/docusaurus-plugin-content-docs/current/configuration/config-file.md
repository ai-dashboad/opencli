---
title: Le fichier de configuration
sidebar_position: 1
---

# Le fichier de configuration

`~/.opencli/config.toml`. **Tout ce qui s'y trouve a une valeur par défaut** ; le
fichier ne contient que **ce que vous avez changé**.

**L'application de bureau écrit le même fichier en gardant vos commentaires et
votre mise en forme** : **modifier à la main et modifier dans Settings sont le
même geste**.

## Fournisseurs et modèles

**Un fournisseur, c'est une URL de base et le nom d'une variable d'environnement
contenant la clé** :

```toml
[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

Les modèles déclarés en dessous apparaissent dans le sélecteur :

```toml
model = "my-model"

[[models]]
slug = "my-model"
model = "provider-side-model-id"
provider = "my-provider"
display_name = "My Model"
context_window = 128000
reasoning_efforts = ["low", "medium", "high"]
```

`slug` est **ce que vous tapez** ; `model` est **le nom que lui donne le
fournisseur**. **Ils diffèrent assez souvent pour mériter d'être séparés.**

**Vous n'êtes pas obligé de les déclarer.** Les modèles sont récupérés depuis le
`/v1/models` du fournisseur. En déclarer un sert à **figer une fenêtre de
contexte, un nom d'affichage, ou les niveaux d'effort acceptés**.

## Autorisations et bac à sable

```toml
approval_policy = "on-failure"   # untrusted | on-failure | never
sandbox_mode = "workspace-write" # read-only | workspace-write | danger-full-access
```

Expliqué dans
[Bac à sable et autorisations](/configuration/sandbox-and-approvals).

## Sortie des outils

```toml
tool_output_token_limit = 10000
```

**Un budget pour ce que la sortie d'un outil peut ajouter à la conversation.**

**Les tokens sont estimés, pas comptés.** Le tokeniseur appartient au modèle, et
**ceci fait tourner des modèles qu'il n'a jamais vus**. L'estimation est de
**quatre octets ASCII par token, et d'un token par caractère sinon** — juste
aussi bien pour l'anglais que pour le chinois, **et penchant vers le
surcomptage** ailleurs. Mettre 500 ici **ne coupe pas exactement à 500 tokens** ;
**cela coupe près de là, dans les mêmes unités que celles du nombre écrit**.

## Voir ce qui s'applique

**Settings** affiche **chaque valeur en vigueur et d'où elle vient**, y compris
**celles que vous n'avez jamais définies**. `Show raw config` est le fichier
lui-même.

## La référence complète

Toutes les clés que ce fichier accepte, avec leur valeur par défaut :
[Référence complète de configuration](/configuration/reference).
