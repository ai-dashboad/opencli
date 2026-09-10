---
title: Habilidades
sidebar_position: 4
---

# Habilidades

**Uma habilidade é um conjunto de instruções ao qual o agente recorre quando uma
tarefa pede**: um procedimento escrito uma vez, **em vez de colado num prompt
toda vez**.

## O que já vem

**Seis fluxos vêm com o produto e funcionam em qualquer diretório**:

| Habilidade | O que faz |
| --- | --- |
| `spreadsheet-review` | Confere um arquivo de linhas contra as regras declaradas e relata as linhas que as quebram **com o número da linha** |
| `weekly-report` | O que **de fato mudou** aqui num período: feito, em andamento, e o que precisa de decisão |
| `inbox-triage` | Separa mensagens pelo que estão pedindo e **marca as que uma pessoa precisa responder** |
| `document-compare` | O que mudou **em substância** entre duas minutas, separado **do que só mudou de redação** |
| `meeting-notes` | Uma transcrição virando decisões, ações com responsáveis e perguntas em aberto |
| `records-review` | Levanta o que vale conferir num conjunto de registros, **citando a nota de onde cada coisa veio** |

Mais duas, herdadas, são sobre **escrever e instalar habilidades**:
`skill-creator` e `skill-installer`.

## De onde elas vêm

| Escopo | Diretório |
| --- | --- |
| De fábrica | `~/.opencli/skills/.system` — reescrito quando o app atualiza |
| Suas | `~/.opencli/skills` |
| Deste projeto | `.opencli/skills` no diretório de trabalho |

## Escrever uma

Um diretório com um `SKILL.md` cujo front matter diz o que ela é e **quando
usá-la**:

```markdown
---
name: invoice-check
description: Check invoices against our payment rules and report what breaks
  them. Use when asked to review, check or audit a file of invoices.
metadata:
  short-description: Find invoices that break the rules
---

# Invoice check

## Find the rules before reading the rows
...
```

**A `description` é contra o que o agente compara um pedido.** Uma descrição que
só diz o que a habilidade ***é*** **deixa o modelo adivinhar quando ela se
aplica**: **toda habilidade de fábrica nomeia as suas ocasiões**, e a sua deveria
também.

## O que faz uma funcionar

**Ler as seis que vêm é o jeito mais rápido de ver o formato**, mas três coisas
se repetem:

- **Diga o que ler, e em que ordem.** «Do mais antigo primeiro» é uma instrução
  de verdade; «revise os registros» não é.
- **Diga o que produzir.** Um arquivo com nome, ou uma estrutura declarada. Não
  «um resumo».
- **Diga o que ela nunca deve fazer.** A habilidade clínica que vem de fábrica
  **gasta um terço do comprimento nisso**, e é por isso que ela pode existir.

**Uma aprendida na marra**: se um número importa, **diga de onde esse número
precisa vir**. A habilidade de planilha pede uma contagem de linhas, e **a
primeira execução declarou de memória e errou por um**. Agora ela **exige que a
contagem venha do script que fez a conferência**.

## Desligar uma

Cada habilidade tem um interruptor em **Abilities → Skills**. Uma mudança vale
para **a próxima conversa que você abrir**, não para a que já está rodando.
