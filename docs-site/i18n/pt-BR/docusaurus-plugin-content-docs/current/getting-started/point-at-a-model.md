---
title: Aponte para um modelo
sidebar_position: 2
---

# Aponte para um modelo

**O OpenCLI não vem com modelo nem com chave.** Numa instalação nova, a
primeira tela diz isso e oferece os dois caminhos abaixo.

**Isto não é uma lista de integrações: é um protocolo só.** Qualquer coisa que
responda a `/v1/chat/completions` e `/v1/models` do jeito que a OpenAI responde
pode ser apontada, e **os modelos dela aparecem sozinhos no seletor**. Você não
precisa declarar um por um.

## Nesta máquina

O aplicativo de desktop pode instalar um para você: abra **Models** e ele olha
**o que já existe na máquina** antes de se oferecer para baixar qualquer coisa.

Na mão, com o [Ollama](https://ollama.com) já rodando:

```toml
model = "qwen3-coder"

[model_providers.ollama]
name = "Ollama"
base_url = "http://localhost:11434/v1"
wire_api = "chat"

[[models]]
slug = "qwen3-coder"
model = "qwen3-coder:30b"
provider = "ollama"
context_window = 32768
```

Coloque isso em `~/.opencli/config.toml` e rode `opencli`.

**Nada sai da máquina, e não há chave nenhuma para guardar.**

## Um provedor

**Todos funcionam do mesmo jeito.** O padrão é uma URL base e o nome de uma
variável de ambiente com a chave:

```toml
model = "my-model"

[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

```shell
export MY_PROVIDER_API_KEY=...
opencli
```

No aplicativo de desktop a mesma coisa é feita em **Settings**, onde a chave
**é guardada e nunca mais mostrada**.

### Cotas gratuitas são o jeito mais barato de testar um modelo grande

Vários provedores dão alguma coisa, e é assim que se roda um modelo **bem maior
do que a sua máquina aguentaria**. O que é gratuito muda de mês para mês, então
esta página não cita valores: **veja as páginas de preço deles**.

O [README](https://github.com/ai-dashboad/opencli#where-the-model-comes-from)
traz a lista completa de provedores, **cada um verificado pedindo a sua lista
de modelos**.

## Um modelo pode não vir da empresa que o fez

A Xiaomi publica o MiMo, a ByteDance publica o Seed, e **nenhuma das duas mantém
um endpoint público compatível com a OpenAI**. Os dois são carregados por
terceiros — então você chega ao MiMo pela OpenRouter, Novita, DeepInfra, PPIO
ou Hugging Face, não pela Xiaomi.

## Ser alcançável não é a mesma coisa que ser bom nisto

**Um provedor que responde à API da OpenAI mas não à parte de chamada de
ferramentas vai conversar e pouco mais**: este agente trabalha chamando
ferramentas. Antes de se comprometer com um modelo,
[teste-o](/reference/checking-a-model) — **cinco minutos, uma tarefa fixa**.

## Próximo

[Sua primeira conversa](/getting-started/first-conversation).
