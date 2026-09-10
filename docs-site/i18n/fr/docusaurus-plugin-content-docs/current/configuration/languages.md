---
title: Langues
sidebar_position: 3
---

# Ajouter une langue

**Dix traductions sont fournies avec OpenCLI** : English, 简体中文, 繁體中文,
日本語, 한국어, Español, Português (Brasil), Français, Deutsch et Русский.

**Toute autre langue tient dans un fichier** — et une correction à l'une de
celles-là aussi.

## Depuis l'interface

**Customize → Language → Add a language file…** prend un fichier `.json` et le
conserve. **Il apparaît aussitôt dans le sélecteur.**

## À la main

Le même fichier, dans `~/.opencli/locales`, nommé d'après la langue :

```
~/.opencli/locales/nl.json
```

**Les deux voies écrivent au même endroit** : ce qui a été ajouté depuis
l'interface peut ensuite être modifié à la main ou copié sur une autre machine.

## Ce qu'il contient

**Chaque entrée est une phrase anglaise exactement telle qu'elle apparaît dans
l'interface**, et ce qu'il faut afficher à la place :

```json
{
  "name": "Nederlands",
  "strings": {
    "Dispatch": "Verzenden",
    "Scheduled tasks": "Geplande taken",
    "Runs ({count})": "Uitvoeringen ({count})"
  }
}
```

`name` est ce qu'affiche le sélecteur de langues. Omis, c'est le nom du fichier
qui sert. **La table brute fonctionne aussi, sans l'enveloppe** :

```json
{ "Dispatch": "Verzenden" }
```

## Partir d'une langue fournie

Les traductions fournies sont le même genre de fichier, dans
[`web/src/locales/`](https://github.com/ai-dashboad/opencli/tree/main/web/src/locales).
**Copiez-en une, remplacez le côté droit de chaque ligne** et vous avez **un point
de départ complet** plutôt qu'une liste de phrases à traquer.

Pour voir toutes les phrases utilisées par l'interface :

```
python3 scripts/i18n-check.py
```

## Marqueurs

`{name}` dans une phrase est rempli. **Gardez les mêmes marqueurs, dans l'ordre
que votre langue préfère** — **ce réagencement est l'essentiel de leur raison
d'être** :

```json
{ "Allowed {count} of {total}": "{count} autorisés sur {total}" }
```

## Pluriels

`plural()` choisit **entre deux formes**. Cela suffit à l'anglais, à l'allemand, à
l'espagnol, au français et au portugais ; **il n'a pas la troisième forme que le
russe demande pour 2–4**. Lorsqu'une langue a besoin de plus de deux formes,
**écrivez la phrase de sorte que le nombre porte le sens à lui seul** :
`запусков: {count}` plutôt qu'un nom qui doive s'accorder avec lui.

**Le chinois, le japonais et le coréen prennent la forme du singulier et laissent
le nombre faire le travail** — c'est déjà pris en charge.

## Corriger une traduction fournie

**Un fichier nommé d'après une langue déjà fournie est fusionné avec elle, non
substitué à elle.** Pour changer une phrase, écrivez une entrée :

```json
{ "Dispatch": "Envoyer" }
```

**Tout le reste garde la formulation fournie.**

## Quand cela prend effet

Un fichier ajouté depuis l'interface s'applique **tout de suite**. Un fichier
déposé à la main dans le répertoire **est lu quand une fenêtre se connecte** :
rouvrez la fenêtre. **Un fichier illisible est ignoré**, avec une ligne dans le
journal de la passerelle — **les autres langues ne sont pas affectées**.

## Phrases non traduites

**Une phrase sans entrée s'affiche en anglais** : une traduction partielle se lit
donc comme un mélange et non comme **un écran de trous**. **Nul besoin de la
terminer pour qu'elle serve.**

## De droite à gauche

L'arabe, l'hébreu et le persan ne font pas partie des traductions fournies, et
**en ajouter une sous forme de fichier donnera une page composée de gauche à
droite**. L'interface ne gère pas encore `dir="rtl"` ; **c'est une modification de
la feuille de style, pas d'un fichier de traduction**.
