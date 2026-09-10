---
title: Segurança
sidebar_position: 3
---

# Segurança

**O que este produto faz com a sua máquina e com os seus dados**, dito **para que
você possa decidir em vez de supor**.

## O que sai da sua máquina

Os seus prompts, e os arquivos que o agente ler em seu nome, vão **para o endpoint
que você configurou** e para lugar nenhum além dele. **Não há nenhuma gateway
nossa no meio.**

Se esse endpoint roda na sua própria máquina, **nada sai dela**.

**Duas exceções**, ambas **falham em silêncio offline** e **nenhuma carrega nada do
que você digitou**:

- o aplicativo de desktop pergunta ao próprio endpoint de atualização se há uma
  versão mais nova
- o painel Models busca no Hugging Face uma lista de modelos populares quando é
  aberto

## O que o agente pode fazer com a sua máquina

**Dois ajustes, fazendo trabalhos diferentes.**

**O sandbox** decide o que ele *pode* fazer. Sob `workspace-write` — o padrão — ele
pode escrever **em qualquer lugar dentro do diretório de trabalho** e em lugar
nenhum fora dele. **Leituras não são restringidas em modo nenhum.**

**As aprovações** decidem o que ele precisa perguntar antes, de todo comando
desconhecido até absolutamente nada.

**A combinação com que vale a pena ter cuidado é `danger-full-access` junto com
`never`**: um agente **rodando comandos arbitrários sem mostrar nada e sem
perguntar nada**. **Há diretórios em que isso é o certo. A sua pasta pessoal não é
um deles.**

[Sandbox e aprovações](/configuration/sandbox-and-approvals) tem o detalhe.

## Onde uma execução em segundo plano pode começar

**Uma execução cujo diretório não é o espaço de trabalho, nem um departamento, nem
algum lugar que você liberou pelo nome, fica retida** em vez de começar.

Isso existe porque **uma tarefa agendada criada antes de existirem departamentos
carregava uma pasta pessoal e já tinha rodado quarenta e duas vezes**: **cada
execução alcançando `.ssh` e `Documents`, sem ninguém ser consultado**.

**Colocar as aprovações em `never` desliga isso junto com todo o resto**, que é o
que aquele ajuste significa.

## Chaves

**As chaves de API ficam fora do `config.toml`**, porque **aquele arquivo é
compartilhado e colado em issues**. Elas são escritas onde estão os seus outros
segredos, e **nunca mais são mostradas depois de salvas**.

**As chaves dos conectores funcionam igual**: você nomeia as variáveis de ambiente
de que um servidor precisa, e **os valores ficam guardados separados da
configuração desse servidor**.

## A gateway

O aplicativo de desktop e a interface web falam com **uma gateway local**. Ela:

- **se prende ao loopback** a menos que seja explicitamente instruída de outro
  jeito, então **não fica exposta à rede por acidente**
- **exige um token em toda conexão**, gerado por execução e mostrado uma vez só,
  para que **nem outro usuário local nem uma página web no seu navegador consigam
  operá-la**

**Um cliente desta gateway pode fazer o agente executar comandos na máquina que a
hospeda.** É esse o propósito inteiro, **e é por isso que o token existe**.

**Ela é de um usuário só por projeto.** Servir várias pessoas não confiáveis
exigiria **sandbox por usuário**, e isso está fora do escopo.

## Telefones pareados

**Parear entrega a um dispositivo um token que permite operar o agente desta
máquina.** O endereço é mostrado uma vez só. **Pareie apenas os seus próprios
dispositivos e revogue qualquer coisa que não reconheça.**

## As compilações não são assinadas

**Sem certificado da Apple nem da Microsoft**, o seu sistema operacional **não tem
como saber quem as compilou e diz isso**. **Aquele aviso está certo e você deveria
lê-lo como certo.**

Se você preferir não acreditar na nossa palavra sobre nada disso, o código está
[aqui](https://github.com/ai-dashboad/opencli) e é **um `cargo build`**.

## Relatar alguma coisa

**Não abra um issue público para uma falha de segurança.** Use o
[formulário de aviso privado](https://github.com/ai-dashboad/opencli/security/advisories/new)
do GitHub, que **chega aos mantenedores sem publicar nada**.

**O que mais vale olhar é o que está nesta página**: a política do sandbox, o
caminho de aprovação, a checagem de diretório nas execuções em segundo plano e o
token da gateway.

**Não inclua as suas chaves, nem logs que as contenham.**
