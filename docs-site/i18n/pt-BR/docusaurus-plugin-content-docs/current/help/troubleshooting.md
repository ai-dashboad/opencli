---
title: Solução de problemas
sidebar_position: 2
---

# Solução de problemas

## Diz que as credenciais foram recusadas

```
The model provider would not accept the request without credentials.
(status 401 Unauthorized)
```

**Ou não há chave definida para o provedor que você escolheu, ou a que existe não
vale para ele.** Três coisas para conferir, **nesta ordem**:

1. **Qual provedor está de fato selecionado** — `model` no `config.toml`, ou o
   seletor no campo de escrever. **Apontar para um modelo cujo provedor você nunca
   configurou** é a causa comum.
2. **A variável de ambiente nomeada por `env_key`** está definida no shell em que
   o agente roda. **O aplicativo de desktop lê isso de onde ele guarda as suas
   chaves, não do seu shell.**
3. **A chave pertence àquele provedor.** A chave de um não é a chave de outro.

**Um 401 não é repetido, de propósito**: **credenciais não ficam válidas por serem
oferecidas de novo.**

## A lista de modelos está vazia

O painel **Models** e o seletor do campo de escrever vêm ambos do `/v1/models` do
provedor. **Uma lista vazia quer dizer que aquela requisição falhou**, e o motivo
está em `~/.opencli/log`.

**Um provedor que exige chave não devolve nada sem ela**, então isto e o 401 acima
**costumam ser o mesmo problema**.

## Ele responde, mas nunca toca nos meus arquivos

**O seu modelo não está chamando ferramentas.** Essa é **a decepção mais comum**, e
**não é erro de configuração**: **alguns modelos simplesmente não chamam**.

[Teste-o](/reference/checking-a-model). Cinco minutos, uma tarefa fixa. **Se
falhar, o modelo é a ferramenta errada para isto e nenhum ajuste vai mudar
isso.**

## Ele roda `grep` em vez de ler o arquivo direito

**A mesma lacuna de fundo, numa forma mais branda**: um modelo não treinado para
trabalho agêntico **apela para o shell mesmo com uma ferramenta de arquivo na
frente dele**. **Nada na interface fecha essa lacuna.**

## Uma execução em segundo plano diz que está me esperando

**O diretório de trabalho dela não é um que este produto conheça** — não é o
espaço de trabalho, não é o diretório de um departamento e não é **algum lugar que
você tenha liberado pelo nome**.

Ou **Liberar este diretório** no painel Dispatch, ou **Mover** a tarefa para um
departamento. **Ela fica retida em vez de rodar porque uma execução pode escrever
em qualquer lugar dentro do diretório dela.**

## Uma tarefa agendada nunca rodou

**Duas possibilidades**:

- **O OpenCLI estava fechado.** Trabalho agendado roda **só enquanto ele está
  aberto**.
- **Ela está retida**, como acima. Tarefas retidas aparecem em
  *Esperando por você*.

## A conversa fica se resumindo

**Se ela resume e logo precisa de novo, o tamanho não vem da conversa**: vem da
**parte fixa de cada requisição**, que é sobretudo **os esquemas de ferramentas dos
seus conectores**. **Quatro conectores podem ser dez mil tokens antes de você ter
dito qualquer coisa.**

**Ele diz isso uma vez, em vez de refazer a cada rodada.** A solução é **desligar os
conectores que você não está usando naquela conversa**.

## O aplicativo de desktop não abre

**macOS**: rode `xattr -dr com.apple.quarantine /Applications/OpenCLI.app`, ou
clique com o botão direito → **Abrir**.

**Windows**: SmartScreen → **Mais informações** → **Executar assim mesmo**.

Se ainda assim recusar, **o download pode estar incompleto** — confira o tamanho
do arquivo com a página da release.

## O agente fez algo que eu não vi

**Artifacts lista só as edições feitas com a ferramenta de edição de arquivos do
agente.** Arquivos escritos por um comando de shell que ele rodou — um heredoc, um
script, `git checkout` — **são mudanças reais que não vão aparecer ali**.

**`git status` no diretório de trabalho é a resposta confiável.**

## A interface está em inglês mesmo eu tendo escolhido outro idioma

**O dicionário é buscado quando o idioma é escolhido**, então há **um momento em que
o inglês aparece**. Se continuar em inglês, **o pedaço não carregou** — veja o
console do navegador nas ferramentas de desenvolvedor do app de desktop.

**Uma frase sem tradução mostra o inglês sempre, por projeto**; isso é **uma
tradução parcial, não um defeito**.

## Onde ficam os logs

```
~/.opencli/log
```

**Settings → About → Logs** abre o diretório. Ao relatar um problema, **as últimas
cinquenta linhas em volta da falha quase sempre bastam** — e **confira se há chaves
nelas antes de colar**.
