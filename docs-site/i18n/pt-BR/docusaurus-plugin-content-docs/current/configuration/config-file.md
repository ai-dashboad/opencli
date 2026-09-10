---
title: O arquivo de configuração
sidebar_position: 1
---

# O arquivo de configuração

`~/.opencli/config.toml`. **Tudo aqui tem um valor padrão**; o arquivo só guarda
**o que você mudou**.

**O aplicativo de desktop escreve o mesmo arquivo, preservando seus comentários e
sua formatação**, então **editar na mão e editar em Settings são o mesmo ato**.

## Provedores e modelos

**Um provedor é uma URL base e o nome de uma variável de ambiente com a chave**:

```toml
[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

Os modelos declarados abaixo dele aparecem no seletor:

```toml
model = "my-model"

[[models]]
slug = "my-model"
model = "provider-side-model-id"
provider = "my-provider"
display_name = "My Model"
context_window = 128000
reasoning_efforts = ["low", "medium", "high"]
```

`slug` é **o que você digita**; `model` é **como o provedor chama aquilo**.
**Eles divergem com frequência suficiente para valer a separação.**

**Você não precisa declará-los.** Os modelos são buscados no `/v1/models` do
provedor. Declarar um serve para **fixar uma janela de contexto, um nome de
exibição ou os níveis de esforço que ele aceita**.

## Aprovações e sandbox

```toml
approval_policy = "on-failure"   # untrusted | on-failure | never
sandbox_mode = "workspace-write" # read-only | workspace-write | danger-full-access
```

Explicado em [Sandbox e aprovações](/configuration/sandbox-and-approvals).

## Saída das ferramentas

```toml
tool_output_token_limit = 10000
```

**Um orçamento para o que a saída de uma ferramenta pode acrescentar à conversa.**

**Tokens são estimados, não contados.** O tokenizador pertence ao modelo, e
**isto roda modelos que ele nunca viu**. A estimativa é **quatro bytes ASCII por
token e um token por caractere nos demais casos** — perto tanto para o inglês
quanto para o chinês, **errando para o lado de contar demais no resto**. Colocar
500 aqui **não corta exatamente em 500 tokens**; **corta por perto, nas mesmas
unidades em que o número está escrito**.

## Ver o que está valendo

**Settings** mostra **todo valor em vigor e de onde ele veio**, inclusive
**os que você nunca definiu**. `Show raw config` é o arquivo em si.

## A referência completa

Toda chave que este arquivo aceita, com o padrão dela:
[Referência completa de configuração](/configuration/reference).
