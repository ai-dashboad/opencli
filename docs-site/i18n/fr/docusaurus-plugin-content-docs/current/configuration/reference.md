---
title: Référence complète de configuration
sidebar_position: 4
---

# Référence complète de configuration

Toutes les clés que `~/.opencli/config.toml` accepte. Pour **la poignée que la
plupart des gens touchent**,
[le fichier de configuration](/configuration/config-file) est plus court.

### Le plus rapide : laissez OpenCLI trouver vos modèles

Si vous faites déjà tourner Ollama, LM Studio, vLLM ou llama.cpp en local :

```shell
opencli provider scan
```

**Cela sonde les ports localhost habituels**, demande à chaque serveur trouvé
quels modèles il sert, et écrit les sections `[model_providers.*]` et
`[[models]]` correspondantes dans votre `config.toml` — **vos commentaires et
réglages existants sont préservés**. Ajoutez `--dry-run` pour voir d'abord ce
qu'il écrirait.

Pour les fournisseurs hébergés, installez-en un depuis le catalogue et donnez sa
clé :

```shell
opencli provider list          # le catalogue, plus ce qui est déjà configuré
opencli provider add openrouter
export OPENROUTER_API_KEY=...
```

**Le catalogue ne contient que des informations de connexion** : aucune clé n'est
livrée avec le binaire, et **rien n'est actif tant que vous ne l'ajoutez pas**.
Pour configurer quelque chose d'absent du catalogue, écrivez les sections à la
main comme décrit ci-dessous.

#### Renseigner les capacités d'un modèle

**La fenêtre de contexte d'un modèle local et sa prise en charge des appels
d'outils ne sont publiées nulle part**, et **deviner est pire que de laisser
vide** : une fenêtre de contexte trop grande, et le fournisseur **refuse** les
tours au lieu de compacter automatiquement. **Demandez au modèle** :

```shell
opencli model probe <slug>            # ajoutez --dry-run pour prévisualiser
```

**Cela lit les métadonnées du moteur lui-même quand elles existent** (**Ollama
indique la vraie longueur de contexte et la liste des capacités**) et, en plus,
**effectue une requête réelle** pour voir si le modèle appelle un outil qu'on lui
propose et s'il renvoie son raisonnement dans un champ `reasoning` distinct. Les
constatations sont écrites dans l'entrée `[[models]]` du modèle.

**Les modèles incapables de discuter** — ceux d'embeddings, par exemple — **sont
ignorés par `provider scan`**, ils n'atteignent donc jamais le sélecteur
`/model`.

### Choisir modèles et fournisseurs

Cette build fournit des préréglages pour plusieurs passerelles, mais **tout modèle
joignable par une API compatible OpenAI peut être configuré** dans
`~/.opencli/config.toml` **sans recompiler**.

#### Ajouter un fournisseur

Les entrées de `[model_providers.<id>]` **remplacent un fournisseur intégré du
même id** : **c'est donc aussi ainsi qu'on redirige une passerelle fournie vers un
proxy ou un miroir** :

```toml
[model_providers.my-gateway]
name = "My Gateway"
base_url = "https://gateway.example.com/v1"
env_key = "MY_GATEWAY_API_KEY"
wire_api = "chat"
# Facultatif : à augmenter si cette passerelle est lente à sortir le premier token.
stream_idle_timeout_ms = 90000
```

**Les clés d'API sont toujours lues dans l'environnement ; elles ne sont jamais
stockées dans le fichier de configuration.**

#### Ajouter un modèle

Déclarez des modèles avec `[[models]]`. Ils apparaissent dans le sélecteur
`/model` à côté des préréglages intégrés, et **une entrée dont le `model`
correspond à un préréglage intégré le remplace** :

```toml
[[models]]
model = "qwen3-max"
provider = "my-gateway"
display_name = "Qwen3 Max"     # facultatif, par défaut le slug
description = "Auto-hébergé."  # facultatif
show_in_picker = true          # facultatif, true par défaut
```

`provider` est obligatoire et doit nommer un fournisseur défini plus haut ou un
fournisseur intégré ; **un modèle pointant vers un fournisseur non défini est
rejeté au démarrage** plutôt que d'échouer plus tard avec une erreur sans rapport.

Pour choisir un modèle sans l'ajouter au sélecteur, réglez directement `model` et
`model_provider` :

```toml
model = "qwen3-max"
model_provider = "my-gateway"
```

Si `model` nomme quelque chose qui n'est ni un préréglage intégré ni une entrée
`[[models]]` et que `model_provider` n'est pas renseigné, les requêtes **retombent
sur le fournisseur `openai`** et un avertissement est journalisé.

#### Fenêtres de contexte

**Les modèles dont cette build n'a pas les métadonnées démarrent avec une fenêtre
prudente de 131 072 tokens** et **apprennent la vraie au premier refus pour
dépassement de fenêtre** renvoyé par la passerelle. Réglez
`model_context_window` pour la figer explicitement.

### Se connecter à des serveurs MCP

OpenCLI peut se connecter à des serveurs MCP déclarés dans
`~/.opencli/config.toml`.

```toml
[mcp_servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env_vars = ["GITHUB_PERSONAL_ACCESS_TOKEN"]

[mcp_servers.internal]
url = "https://mcp.example.com/mcp"
```

`env_vars` nomme les variables dont le serveur a besoin ; **les valeurs sont
conservées avec vos autres clés, et non dans ce fichier, qui se partage**. Un
serveur déclaré ici démarre **avec la prochaine conversation que vous ouvrez**,
pas avec celle qui est devant vous.

L'application de bureau écrit la même table depuis **Abilities → Connectors**,
qui **teste aussi la poignée de main** et liste les outils proposés par chaque
serveur.

### Apps (Connectors)

Utilisez `$` dans la zone de saisie pour insérer un connecteur ChatGPT ; la
liste déroulante affiche les apps accessibles. La commande `/apps` liste les apps
disponibles et installées. **Les apps connectées apparaissent en premier et sont
marquées comme connectées** ; les autres sont marquées comme installables.

### Notifications

OpenCLI peut lancer un hook de notification quand l'agent termine un tour.

```toml
notify = ["/path/to/your/script.sh"]
```

Le programme est appelé avec un argument : **un objet JSON décrivant ce qui s'est
passé**. **Il est lancé détaché, un script lent ne retient donc pas le tour
suivant**, et un script qui échoue est journalisé plutôt que remonté à l'écran.

### Schéma JSON

Le schéma JSON généré pour `config.toml` se trouve dans
[`opencli-rs/core/config.schema.json`](https://github.com/ai-dashboad/opencli/blob/main/opencli-rs/core/config.schema.json),
et **est publié à chaque version sous le nom `config-schema.json`**. Pointez-y
votre éditeur pour avoir complétion et validation en éditant le fichier à la
main.

**Il est généré à partir des types Rust, et la CI échoue s'il s'en écarte** — c'est
donc **la seule description de ce fichier qui ne peut pas devenir obsolète**.

### Avis

OpenCLI enregistre les indicateurs « ne plus afficher » de certaines invites
d'interface dans la table `[notice]`.

Quitter par Ctrl+C/Ctrl+D utilise un indice de double appui d'environ une seconde
(`ctrl + c again to quit`).
