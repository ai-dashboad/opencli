---
title: Plantões
sidebar_position: 2
---

# Plantões

**Um plantão é um trabalho que um bot faz de tempos em tempos**, e que **para
para te perguntar quando chega em algo que não deveria decidir sozinho.**

**Essa última parte é o ponto.** Qualquer coisa consegue disparar um prompt num
temporizador; o que torna isto útil para trabalho de verdade é que **fica dito,
de antemão, o que ele não tem permissão para resolver.**

## Os quatro campos

```
O quê           Compare ledger.csv com statement.csv, linha a linha,
                e liste o que não bate, com a referência e o valor.

Regras          Diferença abaixo de 1,00 é arredondamento. Ignore.

Escalar quando  Qualquer linha isolada acima de 10.000.

A cada          24 horas
```

**«O quê» e «Regras» ficam separados de propósito.** O trabalho é o mesmo toda
manhã; **o teto de reembolso é uma política que alguém revisita**. Fundidos num
prompt só, mudar o número obriga a **reler a instrução inteira para achá-lo**.

**«Escalar quando» é escrito em palavras, não como uma condição.** É entregue ao
modelo **como uma obrigação, não é avaliado pelo produto** — ou seja, **é tão
confiável quanto o modelo que o lê.** Escreva como algo verificável:
*qualquer linha isolada acima de 10.000*, não *qualquer coisa estranha*.

## O que acontece quando escala

**O plantão para.** Ele aparece em **Bots → Esperando por você** com a pergunta
que não conseguiu responder, e **não volta a rodar até você responder.**

**Sua resposta é levada para a execução seguinte**, então o bot não pergunta duas
vezes a mesma coisa.

**Um plantão que já perguntou não abre uma segunda pergunta** — ele repete a que
está em aberto.

## O que ele lembra

**Um plantão guarda anotações entre execuções.** Uma execução que aprendeu uma
coisa **anota aquela coisa**; não precisa repetir o que já sabia, e **uma
execução que falhou no meio não leva junto o resto das anotações.**

**Escrever um valor vazio é como se esquece algo de propósito.**

## Onde ele roda

**No diretório do departamento do bot**, que é **tudo aquilo em que a execução
pode escrever**. Um plantão apontado para outro lugar **fica retido até você
liberar aquele lugar pelo nome** — veja
[Sandbox e aprovações](/configuration/sandbox-and-approvals).

## Plantões e tarefas agendadas

**Os dois disparam um prompt num temporizador.** A diferença é **a que eles
pertencem**.

| | Pertence a | Escala | Lembra |
| --- | --- | --- | --- |
| **Plantão** | um bot, num departamento | sim | sim |
| **Tarefa agendada** | nada | não | não |

Use uma tarefa agendada para *toda manhã às nove, me diga o que mudou*. Use um
plantão para **trabalho que vem com uma política junto**.
