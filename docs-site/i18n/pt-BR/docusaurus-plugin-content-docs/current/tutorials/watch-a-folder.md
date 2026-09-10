---
title: Vigiar uma pasta
sidebar_position: 2
---

# Vigiar uma pasta e relatar o que mudou

**Dez minutos.** No fim, você tem **algo que escreve um relatório curto do que se
mexeu num diretório, na periodicidade que você escolher**: um projeto, um drive
compartilhado, **uma pasta onde outra pessoa fica colocando coisas**.

## 1. Aponte uma conversa para a pasta

Abra uma conversa nova e use o botão de pasta acima do campo de escrever para
escolher o diretório.

**Isso importa mais do que parece**: **o agente pode escrever em qualquer lugar
dentro do diretório em que a conversa está aberta**, e em lugar nenhum fora dele.
**Escolher a pasta é escolher o raio da explosão.**

## 2. Peça o relatório uma vez

```
Use a habilidade weekly-report nesta pasta.
```

A habilidade `weekly-report` vem com o produto. **Ela descobre o que mudou** — do
git se a pasta for um repositório, das datas de modificação se não for — e
escreve três seções: **o que terminou, o que está em andamento e o que precisa de
uma decisão**.

**Essa última seção é o motivo para ler.**

## 3. Coloque num horário

**Execuções em segundo plano → agende uma repetitiva:**

| Campo | |
| --- | --- |
| **O que ele deve fazer** | Use a habilidade weekly-report nesta pasta. Salve como `report-<date>.md`. |
| **Nome** | Relatório semanal |
| **De quanto em quanto** | 7 dias |
| **Onde rodar** | a pasta que você escolheu |

## 4. Confira onde ele vai rodar

**Se a pasta não estiver dentro do seu espaço de trabalho e não for um
departamento, a primeira execução fica retida** em vez de começar, e aparece em
*Esperando por você*.

**É de propósito.** Libere o diretório, ou mova a tarefa para dentro de um
departamento.

## 5. Leia o primeiro

**Run now**, e então abra a execução para **ler a saída conforme ela é
produzida**.

**Se o relatório sair magro, a pasta teve uma semana magra**: a habilidade é
instruída a **dizer isso em uma linha em vez de encher linguiça**, porque **um
relatório inflado a partir de uma semana vazia ensina as pessoas a pular
relatórios**.

## Fazer isso na pasta de outra pessoa

**Duas coisas que vale a pena cuidar.**

**O agente lê tudo para onde é apontado**, e **as leituras não são restringidas
pelo sandbox em modo nenhum**. **Uma pasta com coisas que você não mandaria para o
seu provedor de modelo não deveria ser a pasta para onde você aponta** — **a menos
que o seu modelo esteja na sua própria máquina**, e aí nada sai dela.

**Um agendamento sobrevive à sua atenção.** Algo que roda semanalmente por um ano
são **cinquenta e duas execuções que você não assistiu**. **Mantenha o diretório
apertado.**
