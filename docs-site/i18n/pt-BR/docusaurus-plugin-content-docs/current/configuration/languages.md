---
title: Idiomas
sidebar_position: 3
---

# Adicionar um idioma

**Dez traduções vêm com o OpenCLI**: English, 简体中文, 繁體中文, 日本語, 한국어,
Español, Português (Brasil), Français, Deutsch e Русский.

**Qualquer outro idioma é um arquivo** — e uma correção em qualquer um desses
também.

## Pela interface

**Customize → Language → Add a language file…** aceita um arquivo `.json` e o
guarda. **Ele aparece no seletor na hora.**

## Na mão

O mesmo arquivo, em `~/.opencli/locales`, com o nome do idioma:

```
~/.opencli/locales/nl.json
```

**Os dois caminhos escrevem no mesmo lugar**, então o que foi adicionado pela
interface pode depois ser editado na mão ou copiado para outra máquina.

## O que tem dentro

**Cada entrada é uma frase em inglês exatamente como ela aparece na interface**, e
o que mostrar no lugar:

```json
{
  "name": "Nederlands",
  "strings": {
    "Dispatch": "Verzenden",
    "Scheduled tasks": "Geplande taken",
    "Runs ({count})": "Uitvoeringen ({count})"
  }
}
```

`name` é o que o seletor de idiomas mostra. Sem ele, usa-se o nome do arquivo.
**O mapa puro também funciona, sem o envelope**:

```json
{ "Dispatch": "Verzenden" }
```

## Partir de uma que já vem

As traduções incluídas são o mesmo tipo de arquivo, em
[`web/src/locales/`](https://github.com/ai-dashboad/opencli/tree/main/web/src/locales).
**Copie uma, troque o lado direito de cada linha** e você terá **um ponto de
partida completo** em vez de uma lista de frases para caçar.

Para ver todas as frases que a interface usa:

```
python3 scripts/i18n-check.py
```

## Marcadores

`{name}` numa frase é preenchido. **Mantenha os mesmos marcadores, na ordem que o
seu idioma quiser** — **essa reordenação é a maior parte do motivo pelo qual eles
existem**:

```json
{ "Allowed {count} of {total}": "Permitidos {count} de {total}" }
```

## Plurais

`plural()` escolhe **entre duas formas**. Isso basta para inglês, alemão,
espanhol, francês e português; **ele não tem a terceira forma que o russo pede
para 2–4**. Onde um idioma precisar de mais de duas formas, **escreva a frase de
modo que o número carregue o sentido sozinho**: `запусков: {count}` em vez de um
substantivo que precise concordar com ele.

**Chinês, japonês e coreano tomam a forma singular e deixam o número trabalhar**,
e disso o produto já cuida.

## Corrigir uma tradução incluída

**Um arquivo com o nome de um idioma que já vem é mesclado a ele, não colocado no
lugar dele.** Para mudar uma frase, escreva uma entrada:

```json
{ "Dispatch": "Despachar" }
```

**Todo o resto mantém a redação original.**

## Quando vale

Um arquivo adicionado pela interface vale **na hora**. Um colocado na pasta na
mão **é lido quando uma janela se conecta**, então reabra a janela. **Um arquivo
que não dá para interpretar é pulado**, com uma linha no log do gateway — **os
outros idiomas não são afetados**.

## Frases não traduzidas

**Uma frase sem entrada aparece em inglês**, então uma tradução parcial se lê como
uma mistura e não como **uma tela de vazios**. **Não precisa terminar para já ser
útil.**

## Da direita para a esquerda

Árabe, hebraico e persa não estão entre as traduções incluídas, e **adicionar um
como arquivo vai produzir uma página diagramada da esquerda para a direita**. A
interface ainda não trata `dir="rtl"`; **isso é uma mudança na folha de estilo, não
num arquivo de tradução**.
