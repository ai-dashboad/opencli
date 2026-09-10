<div align="center">

<img src="../website/public/favicon.svg" width="80" alt="OpenCLI" />

# OpenCLI

**Um agente de código aberto para os modelos que você mesmo roda**

[![CI](https://img.shields.io/github/actions/workflow/status/ai-dashboad/opencli/rust-ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/ai-dashboad/opencli/actions/workflows/rust-ci.yml)
[![Release](https://img.shields.io/github/v/release/ai-dashboad/opencli?style=flat-square)](https://github.com/ai-dashboad/opencli/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ai-dashboad/opencli/total?style=flat-square)](https://github.com/ai-dashboad/opencli/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat-square)](../LICENSE)

[English](../README.md) ·
[简体中文](./README.zh-CN.md) ·
[繁體中文](./README.zh-TW.md) ·
[日本語](./README.ja.md) ·
[한국어](./README.ko.md) ·
[Español](./README.es.md) ·
**Português** ·
[Français](./README.fr.md) ·
[Deutsch](./README.de.md) ·
[Русский](./README.ru.md)

[Baixar](https://opencli.ai/download.html) ·
[Documentação](https://docs.opencli.ai) ·
[Primeiros passos](https://docs.opencli.ai/getting-started/install) ·
[Provedores](https://docs.opencli.ai/getting-started/providers) ·
[Limites](https://docs.opencli.ai/reference/limits)

</div>

O OpenCLI é um agente que roda no seu próprio computador e funciona com qualquer modelo compatível com a API da OpenAI — um na máquina à sua frente, um no seu próprio servidor, ou um provedor hospedado quando você quiser. Ele lê seus arquivos, executa seus comandos e edita seu trabalho, num terminal e num aplicativo de desktop que compartilham as mesmas conversas.

**Nada vem embutido.** Sem modelos, sem contas, sem chaves e sem opinião sobre de quem você compra inferência. Aponte para um endpoint e os modelos dele aparecem sozinhos; o que você digita vai para lá e para mais lugar nenhum.

## Baixar

| Plataforma | |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

Depois disso o aplicativo se atualiza sozinho. Estas builds não têm certificado da Apple nem da Microsoft, então a primeira abertura pede um passo a mais — [o que fazer](https://docs.opencli.ai/getting-started/install).

**Linha de comando, macOS e Linux:**

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

Depois aponte para um modelo.

## O que ele faz

- 🗂 **Trabalha com arquivos, não só com código.** Ele lê uma pasta de notas fiscais do mesmo jeito que lê um repositório — e a maior parte do trabalho que as pessoas realmente têm é do primeiro tipo.

- 🏢 **Organizado como um escritório.** Um **setor** é um diretório com instruções permanentes. Um **bot** é uma conversa dentro dele, com uma função. Nove setores vêm com dados de exemplo, então dá para experimentar cada um antes de configurar.

- ⏰ **Os plantões chegam sozinhos** — e **param para te perguntar** quando chegam em algo que não deveriam decidir sozinhos. Esse limite é escrito em palavras, de antemão: *qualquer linha acima de 10.000*.

- 🤝 **Os bots passam trabalho entre si,** junto com o que fizeram e os arquivos que produziram. Com teto de oito repasses e três aparições cada, para que a cadeia não desande.

- 🧰 **Seis fluxos de trabalho vêm como habilidades** e funcionam em qualquer diretório: conferir linhas contra suas regras, relatar o que mudou na semana, triar uma caixa de entrada, comparar dois rascunhos, virar uma transcrição em decisões e responsáveis, e ler registros atrás do que merece conferência.

- 🔌 **Conectores são servidores MCP** — GitHub, Postgres, Slack, Notion, um navegador. As chaves ficam longe do arquivo de configuração, que acaba sendo compartilhado.

- 🚦 **Um ambiente isolado com borda visível.** Uma execução pode escrever dentro do próprio diretório e em nenhum outro, e uma apontada para um lugar desconhecido fica retida até você liberar aquele lugar pelo nome.

- 🌍 **Dez idiomas,** e qualquer outro é um arquivo JSON que dá para acrescentar sem recompilar nada.

- 💻 **Terminal, desktop e uma interface web local** sobre o mesmo gateway, então uma conversa começada num continua no outro.

## Funciona com

Não são trinta integrações — é **um protocolo**. Qualquer coisa que responda `/v1/chat/completions` e `/v1/models` do jeito que a OpenAI responde pode ser apontada, e os modelos dela aparecem sozinhos. Cada endpoint abaixo foi consultado pela sua lista de modelos antes de entrar aqui.

**Na sua máquina** — Ollama · LM Studio · llama.cpp · LocalAI · Jan ·
Xinference · KoboldCpp · llamafile

**No seu servidor** — vLLM · SGLang · Text Generation Inference · NVIDIA NIM ·
LiteLLM

**Hospedando modelos abertos** — Fireworks · Together · Groq · DeepInfra · Baseten ·
Novita · Hyperbolic · Nebius · Cerebras · SambaNova · Featherless · Chutes ·
NVIDIA · Hugging Face · OpenRouter · Vercel AI Gateway · Perplexity

**Na China** — 硅基流动 · 无问芯穹 · PPIO · 七牛云 · 魔搭 · 阿里云百炼 ·
火山方舟 / 豆包 · 百度千帆 · 讯飞星火 · 小米 MiMo · DeepSeek · 智谱 ·
月之暗面 · MiniMax · 阶跃星辰 · 腾讯混元 · 百川

**Modelos fechados, quando você quiser** — OpenAI · Anthropic · Mistral · xAI

**Vários dão uma cota gratuita**, que é o jeito mais barato de experimentar um modelo maior do que cabe na sua máquina. Endpoints, e qual provedor serve qual modelo: [Provedores](https://docs.opencli.ai/getting-started/providers).

> **Dar para alcançar não é a mesma coisa que dar conta disto.** Chamar ferramentas é o que separa um modelo que consegue fazer este trabalho de um que só sabe falar dele, e a ficha do modelo nunca diz.
> [Teste o seu](https://docs.opencli.ai/reference/checking-a-model) —
> uma tarefa fixa, cinco minutos. A tabela tem uma linha porque um modelo foi testado — **acrescentar uma linha é a contribuição mais útil que você pode fazer.**

## O que ele não faz

- **Modelos abertos genéricos apelam para o `grep` mesmo tendo uma ferramenta de arquivos.** É uma lacuna dos modelos; nenhuma interface fecha isso.
- **Os tokens são estimados, nunca contados.** O tokenizador é do modelo, e isto roda modelos que nunca viu.
- **O trabalho agendado só roda enquanto o OpenCLI estiver aberto.** É um agente local, não um servidor.
- **Uma execução em segundo plano pode escrever qualquer coisa dentro do diretório onde roda.**
- **As builds de desktop não são assinadas.** O seu sistema operacional está certo em avisar.
- **Idiomas da direita para a esquerda ainda não têm layout.**

[Limites](https://docs.opencli.ai/reference/limits) diz o porquê de cada um.

## De onde isto veio

Um fork do [Codex CLI da OpenAI](https://github.com/openai/codex), Copyright 2025 OpenAI, Apache-2.0. **Sem vínculo com a OpenAI.**

O Codex é feito para os modelos da OpenAI e este é feito para os de todo mundo, o que muda mais do que um nome. Setores, bots, plantões, execuções em segundo plano e os fluxos de trabalho são nossos, assim como boa parte do trabalho sobre o que quebra quando o modelo é pequeno — um laço de compactação que resumia uma vez por turno durante onze turnos e jogava o fio fora toda vez, e uma estimativa de tokens que lia uma página em chinês como três quartos do custo real.

[Apache-2.0](../LICENSE) · [NOTICE](../NOTICE) ·
[Contribuir](https://docs.opencli.ai/reference/contributing)
