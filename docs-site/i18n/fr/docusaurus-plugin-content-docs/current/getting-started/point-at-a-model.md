---
title: Le pointer vers un modèle
sidebar_position: 2
---

# Le pointer vers un modèle

**OpenCLI ne contient ni modèle ni clé.** Sur une installation neuve, le
premier écran le dit et propose les deux voies ci-dessous.

**Ce n'est pas une liste d'intégrations, c'est un seul protocole.** Tout ce qui
répond à `/v1/chat/completions` et `/v1/models` comme le fait OpenAI peut être
visé, et **ses modèles apparaissent tout seuls dans le sélecteur**. Vous n'avez
pas à les déclarer un par un.

## Sur cette machine

L'application de bureau peut en installer un pour vous : ouvrez **Models**, et
elle regarde **ce qui est déjà sur la machine** avant de proposer d'aller
chercher quoi que ce soit.

À la main, avec [Ollama](https://ollama.com) déjà lancé :

```toml
model = "qwen3-coder"

[model_providers.ollama]
name = "Ollama"
base_url = "http://localhost:11434/v1"
wire_api = "chat"

[[models]]
slug = "qwen3-coder"
model = "qwen3-coder:30b"
provider = "ollama"
context_window = 32768
```

Mettez cela dans `~/.opencli/config.toml` et lancez `opencli`.

**Rien ne quitte la machine, et il n'y a aucune clé à conserver.**

## Un fournisseur

**Ils fonctionnent tous pareil.** Le motif est une URL de base et le nom d'une
variable d'environnement contenant la clé :

```toml
model = "my-model"

[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

```shell
export MY_PROVIDER_API_KEY=...
opencli
```

Dans l'application de bureau, la même chose se fait dans **Settings**, où la
clé **est enregistrée et jamais réaffichée**.

### Les quotas gratuits sont le moyen le moins cher d'essayer un gros modèle

Plusieurs fournisseurs donnent quelque chose, et c'est ainsi qu'on fait tourner
un modèle **bien plus gros que ce que votre machine pourrait contenir**. Ce qui
est gratuit change d'un mois à l'autre, donc cette page ne cite aucun montant :
**allez voir leurs propres pages de tarifs**.

Le [README](https://github.com/ai-dashboad/opencli#where-the-model-comes-from)
porte la liste complète des fournisseurs, **chacun vérifié en lui demandant sa
liste de modèles**.

## Un modèle ne vient pas forcément de l'entreprise qui l'a fait

Xiaomi publie MiMo, ByteDance publie Seed, et **ni l'une ni l'autre n'expose
d'endpoint public compatible OpenAI**. Les deux sont portés par d'autres : on
atteint MiMo via OpenRouter, Novita, DeepInfra, PPIO ou Hugging Face, pas via
Xiaomi.

## Être joignable n'est pas la même chose qu'être bon à cela

**Un fournisseur qui répond à l'API OpenAI mais pas à sa partie appel d'outils
discutera, et guère plus** : cet agent travaille en appelant des outils. Avant
de vous engager sur un modèle, [testez-le](/reference/checking-a-model) —
**cinq minutes, une tâche fixe**.

## Ensuite

[Votre première conversation](/getting-started/first-conversation).
