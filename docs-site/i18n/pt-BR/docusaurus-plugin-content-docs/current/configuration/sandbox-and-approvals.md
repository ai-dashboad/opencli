---
title: Sandbox e aprovações
sidebar_position: 2
---

# Sandbox e aprovações

**Dois ajustes, fazendo trabalhos diferentes.** O sandbox decide **o que o agente
*pode* fazer**; as aprovações decidem **o que ele precisa perguntar antes**.

## O sandbox

```toml
sandbox_mode = "workspace-write"
```

| | O agente pode |
| --- | --- |
| `read-only` | olhar arquivos, não mudá-los |
| `workspace-write` | escrever dentro do diretório de trabalho |
| `danger-full-access` | tudo o que a sua conta puder |

**Leituras nunca são restringidas.** Só escrita e acesso à rede são, então
`read-only` quer dizer que **o agente enxerga o seu disco inteiro e não muda nada
dele**.

### A raiz gravável é o diretório de trabalho

Sob `workspace-write`, «o espaço de trabalho» quer dizer **o diretório em que a
conversa ou a execução está aberta**. Não o projeto, não o repositório — **aquele
diretório**.

**Esta é a frase mais importante da página.** Uma execução aberta na sua pasta
pessoal pode escrever em `.ssh`, `Documents` e `Library`.

**E isso não é hipotético.** Uma tarefa agendada criada antes de existirem
departamentos **carregava a pasta pessoal e já tinha rodado quarenta e duas vezes
assim**, cada execução alcançando tudo aquilo, **sem ninguém ser consultado e sem
nada ser dito**. Mudar o padrão para conversas novas não a tocou, porque **um
padrão não é retroativo**.

Por isso existe **uma segunda checagem, no momento em que uma execução começa**.

## Onde uma execução em segundo plano pode começar

Uma execução pode começar quando o diretório dela é **um que este produto já
conhece**:

- dentro do espaço de trabalho
- dentro do diretório de um departamento
- **em algum lugar que você liberou pelo nome**

Qualquer outro fica **retido**, e aparece em **Esperando por você** no painel
Dispatch com um botão *Liberar este diretório*. **Liberar um lugar solta todas as
execuções que o esperavam.**

**Perguntar é o ponto**: rodar num lugar incomum costuma ser **exatamente o que se
queria**, e a resposta é **uma pergunta, não uma recusa**.

## Aprovações

```toml
approval_policy = "on-failure"
```

| | |
| --- | --- |
| `untrusted` | todo comando que não é sabidamente seguro é mostrado antes |
| `on-failure` | os comandos rodam sem supervisão; você é consultado quando um precisa de mais acesso |
| `never` | nada é mostrado antes de rodar |

`never` também quer dizer que **nada fica retido**. Quem desligou as aprovações
**disse, com todas as letras, que não quer ser interrompido**, e **decidir que ele
quis dizer algo mais estreito seria o produto passar por cima do próprio ajuste**.

Use para um diretório **onde você soltaria um script à vontade**.

## A combinação que pega as pessoas

`sandbox_mode = "danger-full-access"` com `approval_policy = "never"` é **um agente
rodando comandos arbitrários na sua máquina sem mostrar nada e sem perguntar
nada**. **Há diretórios em que essa é a resposta certa. A sua pasta pessoal não é
um deles.**

## Duas coisas que o sandbox não faz

- **Ele não impede o modelo de ler os seus arquivos.** Leituras não são
  restringidas **em modo nenhum**.
- **Ele não cobre o que um comando que ele rodou faz depois.** Um script que o
  agente inicia herda o sandbox; **um serviço que ele inicia e que sobrevive à
  execução, não**.
