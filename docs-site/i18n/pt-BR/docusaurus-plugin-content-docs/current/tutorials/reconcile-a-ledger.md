---
title: Conciliar um razão
sidebar_position: 1
---

# Conciliar um razão, do começo ao fim

**Vinte minutos, com um modelo local.** No fim você tem **um departamento que
compara dois arquivos toda manhã e para para te perguntar quando encontra algo
acima de um limite que você define**.

**Tudo aqui usa os dados de exemplo que já vêm junto**, então **não é preciso
preparar nada**.

## 1. Criar o departamento

**Projects → ou comece com um que já funciona → Finance.**

Ele cria `~/.opencli/workspace/finance`, escreve três arquivos ali dentro e
contrata dois bots.

**Os arquivos têm problemas plantados de propósito**:

| Arquivo | O que tem dentro |
| --- | --- |
| `ledger.csv` | o que os seus livros dizem |
| `statement.csv` | o que o banco diz |
| `overdue.csv` | faturas fora do prazo |

## 2. Pedir uma vez, na mão

Abra o departamento e digite:

```
Compare ledger.csv com statement.csv. Liste toda linha que não bate, com a
referência e o valor, e diga o que você acha que aconteceu.
```

**Repare no que ele faz.** Um modelo adequado a isto **vai ler os dois arquivos
com uma ferramenta** e **responder com linhas e referências**. Um que não for
**vai pedir para você colar o conteúdo ou responder em generalidades** — se isso
acontecer, **o problema é o modelo, não a instalação**.
[Teste-o](/reference/checking-a-model).

## 3. Transformar em plantão

**O bot fez uma vez.** Um plantão faz aquilo **voltar sozinho**.

Abra o bot **Reconciler** e defina o plantão dele:

| Campo | O que colocar |
| --- | --- |
| **O quê** | Compare `ledger.csv` com `statement.csv` linha a linha. Liste o que não bate, com a referência e o valor. |
| **Regras** | Diferença abaixo de 1,00 é arredondamento. Ignore. |
| **Escalar quando** | Qualquer linha isolada acima de 10.000. |
| **A cada** | 24 horas |

**«Regras» e «O quê» estão separados por um motivo**: o trabalho é o mesmo toda
manhã, e **o limite é uma política que alguém revisita**. Fundidos num prompt só,
mudar o número obriga a **reler a instrução inteira para achá-lo**.

## 4. Ver ele parar

**Run now.** **Os dados de exemplo contêm uma divergência acima do limite**,
então o plantão não vai terminar — **ele aparece em Bots → Esperando por você com
a pergunta que não conseguiu responder**.

**É nisso que a função inteira consiste.** Ele fez o trabalho, **chegou na linha
que você traçou e parou em vez de decidir**.

Responda. **Sua resposta é levada para a execução seguinte**, então ele não
pergunta duas vezes a mesma coisa.

## 5. Passar o resultado adiante

O departamento Financeiro vem com um segundo bot, o **Chaser**. Na lista **pode
passar para** do Reconciler, marque ele.

Agora uma execução que encontra linhas divergentes pode passá-las adiante — **junto
com o que fez e os arquivos que produziu** — e o Chaser **redige um e-mail de
cobrança por cliente sem que ninguém lhe conte o histórico**.

**Bots → Trabalho passado entre bots** mostra a corrente depois, e **marca a que
parou por ter acabado os saltos** em vez de por ter terminado.

## O que você tem agora

- **um diretório onde o agente pode escrever, e em nenhum outro lugar**
- **trabalho que acontece sem você começar**
- **um limite escrito no qual ele para e pergunta**
- **um segundo bot que pega de onde o primeiro parou**

## O que mudar primeiro

**O limite.** 10.000 **é um número de um exemplo. O seu não é.**

**As regras.** «Diferença abaixo de 1,00 é arredondamento» **é verdade em alguns
livros e não em outros**.

**O intervalo.** A cada 24 horas **é um hábito, não uma lei**. **Um plantão que
roda depois de o banco lançar é mais útil do que um que roda à meia-noite.**
