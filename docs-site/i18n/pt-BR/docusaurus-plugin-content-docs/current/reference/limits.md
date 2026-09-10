---
title: Limitações
sidebar_position: 2
---

# Limitações

**Dito aqui em vez de descoberto depois.**

## Os modelos

**Um modelo local pequeno não é tão bom nisto quanto um de fronteira.** A
interface é a mesma; **o raciocínio não é**.

**Modelos abertos generalistas apelam para o `grep` mesmo tendo uma ferramenta de
arquivo.** Dado um jeito estruturado de ler um arquivo, um modelo não treinado
para trabalho agêntico **ainda vai sair para o shell**. **É uma lacuna dos
modelos, e nenhuma interface a fecha.** **O que este projeto pode mudar é o
alcance, não a inteligência.**

**Um modelo que não chama ferramentas não consegue fazer este trabalho de jeito
nenhum.** Ele vai conversar. [Teste o seu](/reference/checking-a-model) antes de
se comprometer — cinco minutos, uma tarefa fixa.

## A contagem

**Contagens de tokens são estimadas, nunca contadas.** O tokenizador pertence ao
modelo, e **isto roda modelos que ele nunca viu**. Quatro bytes ASCII por token,
um token por caractere nos demais casos: **perto tanto para o inglês quanto para o
chinês**, **errando para o lado de contar demais no resto**.

**Tudo o que vem depois é, portanto, aproximado**: quando uma conversa é resumida,
quando a saída de uma ferramenta é cortada, e o que a linha de uso diz.

## O agendamento

**Tarefas agendadas e plantões rodam só enquanto o OpenCLI está aberto.** **Isto é
um agente local, não um servidor.** Qualquer coisa que precise disparar com a
máquina dormindo pertence **ao agendador do sistema operacional**.

## O sandbox

**Uma execução em segundo plano pode escrever qualquer coisa dentro do diretório
em que roda.** **A raiz gravável *é* aquele diretório.** Execuções fora do
diretório de um departamento **ficam retidas até você liberar o lugar pelo nome** —
**a menos que as aprovações estejam em never**, e aí nada fica retido.

**Leituras nunca são restringidas**, em modo de sandbox nenhum.

## O registro do que mudou

**Artifacts lista só as edições feitas com a ferramenta de edição de arquivos do
agente.** Arquivos escritos por um comando de shell que ele rodou — um heredoc, um
script, `git checkout` — não são rastreados e não vão aparecer. **A mudança é
real; a lista é que está incompleta.**

## As compilações de desktop

**Elas não são assinadas** com certificado da Apple nem da Microsoft. O seu
sistema operacional vai avisar, **e faz bem**: **ele não tem como saber quem as
compilou**. [Instalação](/getting-started/install) diz o que fazer.

## A interface

**Idiomas da direita para a esquerda não são suportados.** Árabe, hebraico e persa
podem ser adicionados como arquivos de tradução, e **a página vai continuar
diagramada da esquerda para a direita**. **Isso é uma mudança na folha de estilo,
não numa tradução.**

## Escalar é uma instrução, não uma garantia

O *escalar quando* de um plantão **é dado ao modelo como uma obrigação**. **Não é
avaliado por este produto**, o que quer dizer que é **exatamente tão confiável
quanto o modelo que o lê**. Escreva como algo verificável — *qualquer linha
isolada acima de 10.000* — em vez de *qualquer coisa estranha*.
