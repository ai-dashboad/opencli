---
title: Execuções em segundo plano
sidebar_position: 3
---

# Execuções em segundo plano

**Trabalho enviado para rodar por conta própria.** Cada execução é **um agente
separado no próprio diretório**, então **continua depois que você fecha a conversa
que a começou**.

## Quatro jeitos de uma começar

| Origem | Quem começa |
| --- | --- |
| **Dispatch** | você, na mão, no painel Dispatch |
| **Agendada** | uma tarefa recorrente vencendo |
| **Plantão** | o plantão de um bot vencendo |
| **Cowork** | mandar uma mensagem no modo Cowork |

**As quatro caem na mesma lista**, e é por isso que vale ler o painel mesmo que
você nunca despache nada na mão.

## Elas só rodam enquanto o OpenCLI está aberto

**Isto é um agente local, não um servidor.** Qualquer coisa que precise disparar
com a máquina dormindo pertence **ao agendador do sistema operacional**: `cron`,
`launchd`, o Agendador de Tarefas.

Dito sem rodeios porque a alternativa é **uma tarefa que silenciosamente nunca
rodou**.

## Quantas de uma vez

**Três por padrão.** Cada uma é um agente inteiro com as próprias chamadas ao
modelo, então **mais do que a sua máquina consegue alimentar deixa todas mais
lentas em vez de terminar mais cedo**. O número é um controle no painel e
**vale sem reiniciar**.

**O teto é dezesseis**, e não por gosto: passando disso, **as execuções param de
avançar e começam a disputar os mesmos pesos**.

## Diretórios, e por que uma execução pode ficar retida

O sandbox de uma execução pode escrever **em qualquer lugar dentro do diretório de
trabalho**. Esse diretório não é, portanto, uma conveniência: é **tudo o que a
execução pode mudar**.

Então uma execução pode começar quando o diretório dela é **um que este produto
já conhece**:

- dentro do espaço de trabalho
- dentro do diretório próprio de um departamento
- **em algum lugar que você tenha liberado pelo nome**

Qualquer outro fica **retido**, e aparece em **Esperando por você** com um botão
*Liberar este diretório*. **Liberar um lugar solta todas as execuções que o
esperavam.**

Se o seu ajuste de aprovação é **Nunca perguntar**, **nada fica retido**. Quem
desligou as aprovações já disse isso, e **o produto não passa por cima do ajuste
que ele mesmo ofereceu**.

## Acompanhar uma

**A saída aparece conforme o agente a produz**, não quando a execução termina.
Uma execução de dez minutos **é legível nos dez**.

## Assumir uma

**Uma execução terminada pode continuar como uma conversa comum**:
**Continue in a chat** abre uma linha nova no mesmo diretório, com **o que foi
pedido a ela e o que ela relatou já no contexto**.

**Com a execução em si não dá para falar.** Este é o caminho de volta para dentro.
