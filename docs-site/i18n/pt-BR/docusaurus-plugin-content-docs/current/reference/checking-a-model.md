---
title: Testar um modelo
sidebar_position: 1
---

# Testar um modelo

A tabela do README diz **quais modelos conseguem de fato fazer este trabalho**. Ela é
curta **porque só contém o que foi executado**, e **cresce quando as pessoas executam**.
Esta é essa tarefa. **Leva uns cinco minutos.**

## Por que esta tarefa e não um benchmark

**A pergunta não é o quanto um modelo é esperto.** É se ele **vai usar uma ferramenta quando
tiver uma**, **ler o arquivo inteiro em vez da primeira tela**, e **relatar um achado diante
de uma regra em vez de descrever o arquivo**.

**Um modelo que falha nisto não é um modelo ruim.** É **um modelo que não foi treinado para
trabalho agêntico**, e **saber disso antes de baixar 20 GB é justamente o ponto**.

## Preparar

Um diretório com dois arquivos. **Seis linhas, três delas erradas**:

`invoices.csv`

```csv
row,invoice,customer,amount,po_number,date
1,INV-2201,Northwind,4200,,2026-08-03
2,INV-2202,Contoso,11800,,2026-08-05
3,INV-2203,Fabrikam,900,PO-771,2026-08-09
4,INV-2204,Northwind,15400,PO-772,2026-08-11
5,INV-2205,Contoso,,PO-773,2026-08-12
6,INV-2206,Tailspin,7300,,2026-13-02
```

`rules.md`

```markdown
# Regras de faturamento

- Qualquer coisa acima de 10.000 precisa de número de pedido.
- Toda fatura precisa ter valor.
- Datas são YYYY-MM-DD e precisam ser datas reais.
```

**Os três problemas plantados** são a linha 2 (acima do limite, sem pedido), a linha 5 (sem
valor) e a linha 6 (mês 13). **A linha 4 está acima do limite *e* tem pedido** — ela está
ali **para que um modelo que relata todo valor grande não seja pontuado como correto**.

## Executar

```shell
opencli exec --skip-git-repo-check --sandbox workspace-write \
  -m <your-model> "Use the spreadsheet-review skill on invoices.csv"
```

## Pontuar

| | |
| --- | --- |
| **Chama ferramentas** | Ele leu o arquivo com uma ferramenta, ou pediu para você colar o conteúdo? |
| **Achou 3/3** | Os três, e só três. Quatro quer dizer que ele inventou um. |
| **Citou** | Cada achado nomeia a linha dele ***e*** cita a regra que ele quebra |
| **Contou** | A linha final diz seis linhas. Cinco quer dizer que ele contou de memória |

**Um modelo que acha três mas não sabe dizer quais linhas não fez o trabalho**:
**todo o produto de uma revisão é um lugar para olhar**.

## Mandar

Abra um pull request acrescentando uma linha à tabela do README, ou um issue com a saída
colada. **Inclua**:

- o modelo, **exatamente como o runtime dele o nomeia** (`qwen3-coder:30b`, não «Qwen»)
- o runtime — Ollama, LM Studio, vLLM, llama.cpp, um endpoint hospedado
- a janela de contexto que você configurou
- qualquer coisa que ele fez e que as quatro colunas não capturam

**Resultados negativos valem tanto quanto os positivos**, e **são mais difíceis de
conseguir** — **ninguém publica sobre o modelo que não funcionou**. **Uma linha dizendo que
um modelo não chama ferramentas poupa um download de todo mundo que a ler.**
