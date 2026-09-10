---
title: Tester un modèle
sidebar_position: 1
---

# Tester un modèle

Le tableau du README dit **quels modèles savent réellement faire ce travail**. Il est court
**parce qu'il ne contient que ce qui a été essayé**, et **il s'allonge parce que des gens
l'essaient**. Voici cette tâche. **Elle prend environ cinq minutes.**

## Pourquoi cette tâche plutôt qu'un benchmark

**La question n'est pas l'intelligence d'un modèle.** C'est de savoir s'il **utilisera un
outil quand il en a un**, s'il **lira le fichier entier plutôt que le premier écran**, et
s'il **signalera un constat au regard d'une règle au lieu de décrire le fichier**.

**Un modèle qui échoue ici n'est pas un mauvais modèle.** C'est **un modèle qui n'a pas été
entraîné au travail d'agent**, et **le savoir avant d'installer 20 Go, c'est tout l'objet**.

## Le préparer

Un répertoire avec deux fichiers. **Six lignes, dont trois fautives** :

`invoices.csv`

```csv
row,invoice,customer,amount,po_number,date
1,INV-2201,Northwind,4200,,2026-08-03
2,INV-2202,Contoso,11800,,2026-08-05
3,INV-2203,Fabrikam,900,PO-771,2026-08-09
4,INV-2204,Northwind,15400,PO-772,2026-08-11
5,INV-2205,Contoso,,PO-773,2026-08-12
6,INV-2206,Tailspin,7300,,2026-13-02
```

`rules.md`

```markdown
# Règles de facturation

- Tout ce qui dépasse 10 000 exige un numéro de commande.
- Chaque facture doit porter un montant.
- Les dates sont au format YYYY-MM-DD et doivent être des dates réelles.
```

**Les trois problèmes plantés** sont la ligne 2 (au-dessus du plafond, sans commande), la
ligne 5 (sans montant) et la ligne 6 (mois 13). **La ligne 4 dépasse le plafond *et* porte
une commande** : elle est là **pour qu'un modèle signalant tous les gros montants ne soit
pas compté comme correct**.

## L'exécuter

```shell
opencli exec --skip-git-repo-check --sandbox workspace-write \
  -m <your-model> "Use the spreadsheet-review skill on invoices.csv"
```

## Le noter

| | |
| --- | --- |
| **Appelle les outils** | A-t-il lu le fichier avec un outil, ou vous a-t-il demandé d'en coller le contenu ? |
| **Trouve 3/3** | Les trois, et seulement trois. Quatre veut dire qu'il en a inventé un. |
| **Cite** | Chaque constat nomme sa ligne ***et*** cite la règle qu'il enfreint |
| **Compte** | La ligne de conclusion dit six lignes. Cinq veut dire qu'il a compté de mémoire |

**Un modèle qui en trouve trois mais ne sait pas dire lesquelles n'a pas fait le travail** :
**tout le produit d'une revue, c'est un endroit où regarder**.

## L'envoyer

Ouvrez une pull request ajoutant une ligne au tableau du README, ou un ticket avec la
sortie collée. **Précisez** :

- le modèle, **exactement tel que son moteur le nomme** (`qwen3-coder:30b`, pas « Qwen »)
- le moteur — Ollama, LM Studio, vLLM, llama.cpp, un endpoint hébergé
- la fenêtre de contexte que vous avez configurée
- tout ce qu'il a fait que les quatre colonnes ne capturent pas

**Les résultats négatifs valent autant que les positifs**, et **sont plus rares** —
**personne ne publie sur le modèle qui n'a pas marché**. **Une ligne disant qu'un modèle ne
sait pas appeler d'outils épargne un téléchargement à tous ceux qui la lisent.**
