---
title: Contribuer
sidebar_position: 3
---

# Contribuer

**Les pull requests sont les bienvenues, et il n'y a aucune invitation à
attendre.** C'est un petit projet ; **ce qui est utile n'est généralement pas une
grosse fonctionnalité**, mais une ligne dans un tableau, une phrase dans une
traduction, ou **un rapport de bug assez détaillé pour qu'on puisse agir**.

## Les contributions les plus utiles

**Une ligne dans le tableau des modèles.**
[Tester un modèle](/reference/checking-a-model) est une tâche fixe de cinq
minutes. **Le tableau est court parce qu'il ne contient que des modèles que
quelqu'un a essayés**, et **un résultat négatif vaut autant qu'un positif** —
**personne ne publie sur le modèle qui n'a pas marché, alors tout le monde le
redécouvre**.

**Une traduction, ou une ligne de correction sur l'une d'elles.** Dix sont
fournies. Chacune peut être **corrigée phrase par phrase sans toucher au reste** —
voir [Langues](/configuration/languages). **Une nouvelle langue, c'est un seul
fichier JSON.**

**Un rapport de bug avec les quatre éléments.** Le modèle et le fournisseur écrits
exactement (`qwen3-coder:30b` sur Ollama, pas « un modèle local »), ce que vous
avez demandé, ce qui s'est passé, et cinquante lignes de `~/.opencli/log` autour
de l'échec. **Vérifiez que ces lignes ne contiennent pas de clés avant de les
coller.**

**Nous dire ce que vous vouliez faire réellement.** Les services et compétences
fournis **ont été écrits à partir de suppositions sur ce dont les gens ont
besoin**. **Ce que vous avez cherché sans le trouver est la chose la plus utile que
vous puissiez dire.**

## Avant d'écrire du code

**Ouvrez d'abord un ticket pour tout ce qui dépasse une simple correction.** Pas
comme un barrage — **mais pour que l'approche soit convenue avant que vous y
passiez une soirée**. **Une PR qui arrive sans ticket derrière est quand même
lue.**

## Mise en place

Rust et pnpm ; le workspace est `opencli-rs/`, l'interface web est `web/`, et
l'enveloppe de bureau est `desktop/`.

```shell
git clone https://github.com/ai-dashboad/opencli
cd opencli
pnpm install
cargo build -p opencli-cli
```

`just` depuis la racine du dépôt lance les utilitaires du workspace ;
`just help` les liste.

## Avant d'ouvrir la PR

```shell
just fmt
just fix -p <crate>
cargo test -p <crate>
```

**Ne lancez pas un `cargo fmt` nu.** L'arbre est formaté avec
`imports_granularity=Item`, qui est **une option réservée à nightly**. Sur stable,
cette option **est silencieusement ignorée** : `cargo fmt` **réécrit alors le bloc
d'imports de presque tous les fichiers du workspace** et **enterre votre
modification sous des centaines de diffs sans rapport**. **C'est exactement pour
cela que `just fmt` appelle nightly.** Sans toolchain nightly
(`rustup toolchain install nightly`), **ne formatez que les fichiers que vous avez
touchés et laissez la CI confirmer le reste**.

Si vous avez touché à l'interface web, `python3 scripts/i18n-check.py` **repère
l'anglais qui n'a jamais été enveloppé pour la traduction**, y compris les cas
faciles à manquer, comme **du texte coupé par une balise en ligne** et **des
libellés construits au moment de l'import**.

## Ce qui rend une PR facile à fusionner

- **Une seule chose.** Les corrections sans rapport font des PR séparées.
- **Un test qui échoue avant votre modification et passe après.** Pas une
  couverture complète — **une assertion qui aurait attrapé le bug**.
- **Des commits qui compilent chacun.** C'est ce qui rend possibles la revue et le
  retour arrière.
- **De la documentation, si le comportement a changé.** Le README,
  `opencli --help`, ou la page d'ici qui est désormais fausse.
- **Quoi, pourquoi, comment** dans la description. **Le *pourquoi* est la part qui
  ne se lit pas dans le diff.**

## Pas de CLA

**Il n'y a rien à signer.** Les contributions sont sous
[Apache-2.0](https://github.com/ai-dashboad/opencli/blob/main/LICENSE), comme le
reste de l'arbre.

## Signaler une faille

**N'ouvrez pas de ticket public pour une faille de sécurité.** Utilisez le
[formulaire d'avis privé](https://github.com/ai-dashboad/opencli/security/advisories/new)
de GitHub, qui **atteint les mainteneurs sans rien publier**.

**Les endroits qui méritent le plus d'être regardés** : la politique du bac à
sable, le chemin d'autorisation, et **tout ce qui décide de ce qu'un appel d'outil
a le droit de toucher**. **Un agent qui lit vos fichiers et exécute des commandes
sur votre machine a une grande surface, et il vaut mieux que ce soit vous qui la
trouviez plutôt que quelqu'un d'autre.**

## Se tenir correctement

**Traitez les gens avec respect** ; nous suivons le
[Contributor Covenant](https://www.contributor-covenant.org/). **Présumez la bonne
foi** — **la communication écrite est difficile, penchez du côté de la
générosité.** Si quelque chose prête à confusion, cela vaut un ticket à soi seul :
**une documentation confuse est un bug de la documentation**.
