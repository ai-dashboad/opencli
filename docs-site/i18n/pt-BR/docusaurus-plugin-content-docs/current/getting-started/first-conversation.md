---
title: Primeira conversa
sidebar_position: 3
---

# Primeira conversa

## Onde ela começa

Uma conversa nova abre em `~/.opencli/workspace`, a menos que pertença a um
departamento — aí ela abre no diretório daquele departamento.

**Isso importa mais do que parece.** O sandbox do agente pode escrever em
qualquer lugar dentro do diretório de trabalho, então **o diretório em que uma
conversa está aberta é tudo o que ela pode mudar**. Antes o padrão era a sua
pasta pessoal; não é mais, e o motivo está em
[Sandbox e aprovações](/configuration/sandbox-and-approvals).

Troque pelo botão de pasta acima do campo de escrever.

## Pedir alguma coisa

Frases comuns. Ele tem os seus arquivos, um shell e os
[conectores](/doing-work/connectors) que você tiver adicionado:

```
Leia invoices.csv e liste toda linha que quebra as regras de rules.md
```

```
O que mudou neste repositório na última semana?
```

```
Compare their-draft.md com our-terms.md e liste toda cláusula que difere
```

## O que acontece antes de qualquer coisa ser mudada

Por padrão o agente **mostra um comando que não é sabidamente seguro antes de
executá-lo**, e **mostra uma escrita em arquivo antes de fazê-la**. Você aprova
ou nega cada uma.

Três ajustes, em **Customize**:

| | |
| --- | --- |
| **Perguntar diante de qualquer coisa desconhecida** | todo comando que não é sabidamente seguro é mostrado antes |
| **Perguntar só depois que algo falha** | os comandos rodam sem supervisão; você é consultado quando um precisa de mais acesso |
| **Nunca perguntar** | nada é mostrado antes de rodar |

O último é para um diretório **onde você soltaria um script à vontade**. Está
explicado direito em
[Sandbox e aprovações](/configuration/sandbox-and-approvals).

## Ver o que ele fez

**Artifacts** lista os arquivos que o agente editou nesta conversa, com os
diffs. Um limite honesto: **só aparecem as edições feitas com a ferramenta de
edição de arquivos do agente**. Arquivos escritos por um comando de shell que
ele rodou — um heredoc, um script, `git checkout` — não são rastreados e não
vão aparecer.

## Quando deixa de caber

Uma conversa que ficou longa **é resumida para continuar cabendo**. Você verá
**Summarising the conversation…**, e depois a linha continua com um resumo no
lugar das trocas mais antigas.

**Se resumir não resolver** — porque o tamanho vem dos esquemas das ferramentas
e não da conversa — **ele diz isso uma vez, em vez de refazer a cada rodada**.

## Próximo

**Uma conversa é uma conversa.** Para o trabalho acontecer sem você estar lá,
[monte um departamento](/doing-work/departments-and-bots).
