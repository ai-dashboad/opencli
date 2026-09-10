---
title: Perguntas frequentes
sidebar_position: 1
---

# Perguntas que as pessoas realmente fazem

## Meus dados são enviados para algum lugar?

**Para o endpoint que você configurou, e para lugar nenhum além dele.** **Não há
nenhuma gateway nossa no meio**, nem conta de telemetria, nem **chave nenhuma
embutida no binário**.

Se esse endpoint for um modelo na sua própria máquina, **nada sai da máquina**.

## Funciona offline?

**Sim, com um modelo local.** O aplicativo de desktop procura as próprias
atualizações e o painel Models busca uma lista de modelos populares — **os dois
falham em silêncio sem rede e nenhum deles é necessário para conversar**.

## Preciso de uma chave de API?

**Não, se você roda um modelo localmente.** Ollama, LM Studio, llama.cpp e os
demais não pedem nada. Um provedor hospedado precisa da chave dele, que **fica
guardada longe do arquivo de configuração e nunca mais é mostrada**.

## Que modelo eu deveria usar?

**O que a sua máquina aguentar**, com **uma exigência inegociável: ele precisa
chamar ferramentas.** Um modelo que não chama **fica limitado a conversar** aqui.

[Testar um modelo](/reference/checking-a-model) é um **teste de cinco minutos**
que responde a isso. A tabela lá é curta porque **só contém o que foi executado**.

## Por que é pior que Claude Code / Codex?

**Porque um modelo de 27B quantizado para caber num laptop não é o GPT-5.** A
interface é a mesma; **o raciocínio não é**.

**O que este projeto muda é o alcance** — se o modelo que você tem pode sequer ser
usado assim — **não o quanto ele é esperto**.

## Dá para usar GPT-5 ou Claude?

**Sim.** Configure OpenAI ou Anthropic como qualquer outro provedor. **Nada no
produto prefere um ao outro.**

## Onde uma conversa começa?

Em `~/.opencli/workspace`, a menos que pertença a um departamento — aí ela começa
no diretório daquele departamento.

**Antes era a sua pasta pessoal. Não é mais**, porque a raiz gravável do sandbox
**é** o diretório de trabalho — veja
[Sandbox e aprovações](/configuration/sandbox-and-approvals).

## Várias pessoas podem usar uma instalação só?

**Não.** A gateway é **de um usuário só por projeto** e **diz isso no próprio
código**. **Cada pessoa roda a sua cópia**; o normal é ter atrás delas **um
servidor de modelos compartilhado**.

## O trabalho agendado roda com o laptop dormindo?

**Não.** Tarefas agendadas e plantões rodam **só enquanto o OpenCLI está aberto**,
porque **isto é um agente local e não um servidor**. Qualquer coisa que precise
disparar com a máquina dormindo pertence ao `cron`, ao `launchd` ou ao Agendador
de Tarefas.

## Qual a diferença para o Open WebUI ou o Jan?

**Aqueles são interfaces de chat para modelos locais, e boas.** **Este é um
agente**: lê e edita os seus arquivos, executa comandos e **continua trabalhando
em segundo plano**. **É outro trabalho, e não há motivo para não rodar os dois.**

## Qual a diferença para o Codex, de onde ele saiu?

**O Codex é feito para os modelos da OpenAI.** Departamentos, bots, plantões,
execuções em segundo plano, repasses entre bots, os fluxos que já vêm e os dez
idiomas da interface **vieram deste lado da bifurcação**, junto com **bastante
trabalho sobre o que quebra quando o modelo é pequeno**.

## Por que aparece que o app está danificado / não verificado?

**Porque as compilações não levam certificado da Apple nem da Microsoft** — eles
**custam dinheiro por ano e este projeto não gastou esse dinheiro**.
[Instalação](/getting-started/install) diz exatamente onde clicar.

## Posso mudar o nome dele?

**Ainda não.** A marca está compilada dentro.

## Alguma coisa quebrou. Onde eu olho?

[Solução de problemas](/help/troubleshooting), depois os logs em
`~/.opencli/log`, e depois
[um issue](https://github.com/ai-dashboad/opencli/issues).
