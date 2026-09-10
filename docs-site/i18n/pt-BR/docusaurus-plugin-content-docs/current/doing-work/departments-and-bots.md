---
title: Departamentos e bots
sidebar_position: 1
---

# Departamentos e bots

**Uma conversa é uma conversa.** Trabalho que volta a aparecer precisa de algo
**que sobreviva a ela**.

| | É | Fica em |
| --- | --- | --- |
| **Departamento** | um diretório mais instruções permanentes | `~/.opencli/workspace/<nome>` por padrão |
| **Bot** | uma conversa dentro de um departamento, com um trabalho | aquele departamento |
| **Plantão** | um trabalho que volta sozinho | um bot |

**As palavras foram emprestadas de um escritório de propósito.** Um departamento
não é uma pasta com nome bonito: é **o limite do que o trabalho lá dentro pode
tocar**.

## Começar por um que já funciona

**Vêm nove departamentos com dados de exemplo** — arquivos com problemas já
plantados dentro — para que a primeira execução **faça alguma coisa** em vez de
explicar que não há nada a fazer.

| Departamento | O que vem junto |
| --- | --- |
| Financeiro | Conciliar `ledger.csv` com `statement.csv`; cobrar o que está vencido |
| Suporte | Responder o que chegou; agrupar perguntas pelo que elas realmente são |
| Operações | Listar todo pedido ainda não enviado, e há quanto tempo espera |
| Marketing | Virar anotações numa semana de posts; agrupar contatos pelo que compraram |
| Pessoas e administrativo | Ler candidaturas diante de uma vaga; tirar decisões e responsáveis das anotações |
| Jurídico | Comparar a minuta deles com os nossos termos, cláusula a cláusula, citando os dois |
| Pesquisa | Onde os estudos concordam, onde se contradizem, e por quê |
| Prontuários | O que está registrado, e o que um clínico deveria olhar, com a citação |
| Engenharia | Ler um serviço e relatar o que daria uma resposta errada |

**Projects → ou comece com um que já funciona.** Ele cria o diretório, escreve
os arquivos de exemplo e contrata os bots.

## Fazer o seu

**Projects → New**, e então:

- **Nome** — como se chama
- **Pasta** — criada se não existir
- **Instruções permanentes** — dadas ao agente em ***toda*** conversa aberta aqui

**As instruções permanentes são onde vai aquilo que você teria de redigitar toda
vez**: como compilar, no que não mexer, quais números são política. São
separadas da descrição, que **só você lê**.

## Bots

**Um bot é uma conversa com um trabalho.** Esse trabalho volta a entrar **toda
vez que o bot é acordado**, então não é preciso lembrá-lo do que ele serve.

Quatro estados, no painel **Bots**:

| | |
| --- | --- |
| **Ocioso** | nada a fazer |
| **Trabalhando** | há uma execução em andamento |
| **Esperando por você** | parou e perguntou — veja [Plantões](/doing-work/duties) |
| **Com erro** | a última execução falhou |

## Bots passando trabalho uns aos outros

Um bot pode passar trabalho a outro **pelo nome**, com o que fez e os arquivos
que produziu. Quem recebe **começa dali, e não do zero**.

**Três recusas** impedem que isso desande, e são a substância da coisa:

- **Profundidade.** Uma corrente para em **oito saltos**.
- **Repetição.** Nenhum bot pode aparecer **mais de três vezes** numa corrente.
- **Direção.** Um bot **só pode receber trabalho de um departamento
  autorizado**. Dentro do mesmo departamento é sempre permitido.

O painel **Bots** mostra todas as correntes e **marca as que pararam por falta de
corda** em vez de por terem terminado.

## Próximo

[Plantões](/doing-work/duties) — trabalho que volta sem você começar.
