---
title: Contribuir
sidebar_position: 3
---

# Contribuir

**Pull requests são bem-vindos, e não há convite nenhum para esperar.** Este é um
projeto pequeno; **o que é útil normalmente não é uma funcionalidade grande**, e
sim uma linha numa tabela, uma frase numa tradução, ou **um relato de bug
detalhado o bastante para se agir**.

## As contribuições mais úteis

**Uma linha na tabela de modelos.**
[Testar um modelo](/reference/checking-a-model) é uma tarefa fixa de cinco
minutos. **A tabela é curta porque só contém modelos que alguém executou**, e
**um resultado negativo vale tanto quanto um positivo** — **ninguém publica sobre o
modelo que não funcionou, então todo mundo redescobre**.

**Uma tradução, ou uma linha de correção em uma.** Vêm dez. Qualquer uma pode ser
**corrigida frase a frase sem tocar no resto** — veja
[Idiomas](/configuration/languages). **Um idioma novo é um único arquivo JSON.**

**Um relato de bug com as quatro coisas.** O modelo e o provedor escritos com
exatidão (`qwen3-coder:30b` no Ollama, não «um modelo local»), o que você pediu,
o que aconteceu, e cinquenta linhas de `~/.opencli/log` em volta da falha.
**Confira se há chaves nessas linhas antes de colar.**

**Contar para a gente o que você realmente queria fazer.** Os departamentos e
habilidades que já vêm **foram escritos a partir de palpites sobre o que as
pessoas precisam**. **O que você procurou e não achou é a coisa mais útil que você
pode dizer.**

## Antes de escrever código

**Abra um issue primeiro para qualquer coisa maior que uma correção.** Não como
portão — **e sim para combinar a abordagem antes de você gastar uma noite nela**.
**Um PR que chega sem issue por trás continua sendo lido.**

## Montar o ambiente

Rust e pnpm; o workspace é `opencli-rs/`, a interface web é `web/` e a casca de
desktop é `desktop/`.

```shell
git clone https://github.com/ai-dashboad/opencli
cd opencli
pnpm install
cargo build -p opencli-cli
```

`just` na raiz do repositório roda os auxiliares do workspace; `just help` lista
eles.

## Antes de abrir o PR

```shell
just fmt
just fix -p <crate>
cargo test -p <crate>
```

**Não rode um `cargo fmt` pelado.** A árvore é formatada com
`imports_granularity=Item`, que é **uma opção só de nightly**. No stable essa
opção é **silenciosamente ignorada**, então o `cargo fmt` **reescreve o bloco de
imports de quase todo arquivo do workspace** e **enterra a sua mudança em centenas
de diffs sem relação**. **O `just fmt` chama o nightly exatamente por isso.** Sem
uma toolchain nightly (`rustup toolchain install nightly`), **formate só os
arquivos que você tocou e deixe a CI confirmar o resto**.

Se você mexeu na interface web, `python3 scripts/i18n-check.py` **encontra o
inglês que nunca foi envolvido para tradução**, incluindo os casos fáceis de
passar batido, como **texto partido por uma tag inline** e **rótulos construídos na
hora do import**.

## O que faz um PR ser fácil de mesclar

- **Uma coisa só.** Correções sem relação vão em PRs separados.
- **Um teste que falha antes da sua mudança e passa depois.** Não cobertura total
  — **uma asserção que teria pego o bug**.
- **Commits que compilam um a um.** É o que torna revisão e reversão possíveis.
- **Documentação, se o comportamento mudou.** O README, o `opencli --help`, ou a
  página daqui que agora está errada.
- **O quê, por quê e como** na descrição. **O *por quê* é a parte que não se lê no
  diff.**

## Sem CLA

**Não há nada para assinar.** As contribuições ficam sob
[Apache-2.0](https://github.com/ai-dashboad/opencli/blob/main/LICENSE), como o
resto da árvore.

## Relatar uma vulnerabilidade

**Não abra um issue público para uma falha de segurança.** Use o
[formulário de aviso privado](https://github.com/ai-dashboad/opencli/security/advisories/new)
do GitHub, que **chega aos mantenedores sem publicar nada**.

**As partes que mais valem o olhar**: a política do sandbox, o caminho de
aprovação, e **tudo o que decide o que uma chamada de ferramenta pode tocar**.
**Um agente que lê os seus arquivos e executa comandos na sua máquina tem muita
superfície, e é melhor que você o encontre do que outra pessoa.**

## Ser decente com isso

**Trate as pessoas com respeito**; seguimos o
[Contributor Covenant](https://www.contributor-covenant.org/). **Presuma boa
intenção** — **comunicação escrita é difícil, então incline para a generosidade.**
Se alguma coisa está confusa, isso já merece um issue por si só: **documentação
confusa é um bug da documentação**.
