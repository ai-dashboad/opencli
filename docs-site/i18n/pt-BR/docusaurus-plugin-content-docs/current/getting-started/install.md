---
title: Instalação
sidebar_position: 1
---

# Instalação

## Aplicativo de desktop

Baixe em [opencli.ai/download](https://opencli.ai/download.html), ou pegue
direto da versão mais recente:

| Plataforma | Download |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

**Cada link aponta sempre para a versão mais nova**, então continua
funcionando conforme as versões mudam.

Depois disso, **o aplicativo se atualiza sozinho**.

### Seu computador vai avisar na primeira vez

Estas compilações **não são assinadas** com certificado da Apple nem da
Microsoft. Esses certificados custam dinheiro por ano e este projeto não gastou
esse dinheiro. **Não há nada de errado com o download**: o sistema operacional
não tem como saber quem compilou.

**macOS** — depois de arrastar o OpenCLI para Aplicativos, rode uma vez:

```shell
xattr -dr com.apple.quarantine /Applications/OpenCLI.app
```

ou clique com o botão direito no app, escolha **Abrir** e confirme. **Só na
primeira abertura.**

**Windows** — o SmartScreen mostra uma caixa azul. Clique em **Mais
informações** e depois em **Executar assim mesmo**.

## Linha de comando

Um binário, macOS e Linux:

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

**Descobre a sua plataforma**, busca a compilação correspondente e coloca o
`opencli` em `/usr/local/bin` — ou em `~/.local/bin` se não conseguir escrever
lá, avisando você para adicioná-lo ao `PATH`.

**O pacote npm ainda não foi publicado**: o escopo `@ai-dashboad` não está
registrado. Até que esteja, **o instalador acima e as compilações de desktop
são os dois caminhos**.

## Do código-fonte

Uma toolchain recente de Rust:

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

O binário fica em `opencli-rs/target/release/opencli`.

## O que ele escreveu e onde

| | |
| --- | --- |
| `~/.opencli/config.toml` | provedores, modelos, ajustes de aprovação e de sandbox |
| `~/.opencli/workspace/` | onde uma conversa começa quando nada diz o contrário |
| `~/.opencli/skills/` | habilidades, incluindo as que já vêm |
| `~/.opencli/locales/` | os idiomas que você adicionar |
| `~/.opencli/log/` | logs |

**Nada é escrito fora de `~/.opencli` até você apontar o agente para um
diretório.**

## Próximo

[Aponte para um modelo](/getting-started/point-at-a-model) — ele não vem com
nenhum e **não vai responder enquanto não tiver onde perguntar**.
