---
title: Conectores
sidebar_position: 5
---

# Conectores

**Um conector é um servidor MCP pelo qual o agente pode chamar ferramentas**:
GitHub, um banco de dados, um navegador, os seus arquivos. É **como o agente
alcança algo que não é um arquivo desta máquina**.

## Adicionar um

**Abilities → Connectors** lista o que está configurado e o que dá para
adicionar. Adicionar do catálogo é um clique; adicionar o seu exige um nome e um
comando ou uma URL:

| | |
| --- | --- |
| **Comando local** | um programa desta máquina, iniciado pelo OpenCLI |
| **Servidor HTTP** | um servidor alcançável por HTTP |

## Chaves

**A maioria dos conectores precisa de uma.** Diga os nomes das variáveis de
ambiente que o servidor espera — **só os nomes**, separados por espaços — e
**preencha os valores depois**.

**Os valores ficam com as suas outras chaves, não na configuração do conector**,
e **nunca mais são mostrados depois de salvos**. Isso é de propósito: **o arquivo
de configuração é compartilhado e colado em issues, e uma chave que estiver nele
vai junto.**

## Testar

**Test connections** inicia todos os servidores configurados e espera um aperto
de mão. É um botão, e não algo que acontece ao abrir o painel, porque
**iniciá-los leva segundos** — medidos em **2,2** contra um que falha ao
autenticar.

O resultado aparece em cada linha, **com as ferramentas que aquele servidor
oferece**.

## Quando uma mudança vale

**Os servidores começam junto com uma conversa.** Um conector adicionado agora
vale para a **próxima** conversa que você abrir, não para a que está na sua
frente.

## O que um conector não é

**Não é uma capacidade que o modelo ganha.** Um modelo que não chama ferramentas
**não começa a chamar porque um conector foi adicionado** — veja
[Limitações](/reference/limits).

## Departamentos

As etiquetas acima da lista filtram por departamento, então a um departamento
Financeiro recém-criado dá para perguntar *a que isto deveria estar conectado*
em vez de *o que é Playwright*.

**Um conector sem etiqueta de departamento aparece sob todas**: **algo que
ninguém classificou não deveria ficar escondido de todo mundo.**
