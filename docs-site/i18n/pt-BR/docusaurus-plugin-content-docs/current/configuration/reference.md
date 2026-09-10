---
title: Referência completa de configuração
sidebar_position: 4
---

# Referência completa de configuração

Toda chave que o `~/.opencli/config.toml` aceita. Para **o punhado que a maioria
das pessoas mexe**, [o arquivo de configuração](/configuration/config-file) é
mais curto.

### O caminho mais rápido: deixe o OpenCLI achar os seus modelos

Se você já roda Ollama, LM Studio, vLLM ou llama.cpp localmente:

```shell
opencli provider scan
```

**Ele sonda as portas habituais de localhost**, pergunta a cada servidor que
encontra quais modelos ele serve e escreve as seções `[model_providers.*]` e
`[[models]]` correspondentes no seu `config.toml` — **comentários e ajustes
existentes são preservados**. Adicione `--dry-run` para ver antes o que ele
escreveria.

Para provedores hospedados, instale um do catálogo e defina a chave:

```shell
opencli provider list          # o catálogo, mais o que já está configurado
opencli provider add openrouter
export OPENROUTER_API_KEY=...
```

**O catálogo só carrega dados de conexão**: nenhuma chave vai junto com o
binário, e **nada fica ativo até você adicionar**. Para configurar algo que não
está no catálogo, escreva as seções na mão como descrito abaixo.

#### Preencher as capacidades de um modelo

**A janela de contexto de um modelo local e o suporte a chamada de ferramentas
não são publicados em lugar nenhum**, e **chutar é pior do que deixar em
branco**: uma janela de contexto grande demais faz o provedor **recusar** os
turnos em vez de compactar sozinho. **Pergunte ao modelo**:

```shell
opencli model probe <slug>            # adicione --dry-run para pré-visualizar
```

**Isso lê os metadados do próprio runtime quando existem** (**o Ollama informa o
comprimento de contexto real e a lista de capacidades**) e, além disso, **faz uma
requisição ao vivo** para ver se o modelo chama uma ferramenta oferecida e se
devolve o raciocínio num campo `reasoning` separado. O que se descobre é escrito
na entrada `[[models]]` do modelo.

**Modelos que não conseguem conversar** — os de embedding, por exemplo — **são
pulados pelo `provider scan`**, então nunca chegam ao seletor `/model`.

### Escolher modelos e provedores

Esta compilação traz presets para algumas gateways, mas **qualquer modelo
alcançável por uma API compatível com a OpenAI pode ser configurado** em
`~/.opencli/config.toml` **sem recompilar**.

#### Adicionar um provedor

Entradas em `[model_providers.<id>]` **sobrescrevem um provedor embutido de mesmo
id**, então **é assim também que se reaponta uma gateway que já vem junto para um
proxy ou espelho**:

```toml
[model_providers.my-gateway]
name = "My Gateway"
base_url = "https://gateway.example.com/v1"
env_key = "MY_GATEWAY_API_KEY"
wire_api = "chat"
# Opcional: aumente se esta gateway demora para produzir o primeiro token.
stream_idle_timeout_ms = 90000
```

**Chaves de API são sempre lidas do ambiente; nunca ficam guardadas no arquivo de
configuração.**

#### Adicionar um modelo

Declare modelos com `[[models]]`. Eles aparecem no seletor `/model` ao lado dos
presets embutidos, e **uma entrada cujo `model` bate com um preset embutido
substitui esse preset**:

```toml
[[models]]
model = "qwen3-max"
provider = "my-gateway"
display_name = "Qwen3 Max"     # opcional, o padrão é o slug
description = "Auto-hospedado." # opcional
show_in_picker = true          # opcional, o padrão é true
```

`provider` é obrigatório e precisa nomear um provedor definido acima ou um
embutido; **um modelo apontando para um provedor não definido é rejeitado na
inicialização**, em vez de falhar depois com um erro sem relação.

Para escolher um modelo sem colocá-lo no seletor, defina `model` e
`model_provider` direto:

```toml
model = "qwen3-max"
model_provider = "my-gateway"
```

Se `model` nomeia algo que não é nem um preset embutido nem uma entrada
`[[models]]` e `model_provider` está em branco, as requisições **caem para o
provedor `openai`** e um aviso é registrado.

#### Janelas de contexto

**Modelos dos quais esta compilação não tem metadados começam com uma janela
conservadora de 131.072 tokens** e **aprendem a real na primeira recusa por
janela de contexto** vinda da gateway. Defina `model_context_window` para fixá-la
explicitamente.

### Conectar a servidores MCP

O OpenCLI pode se conectar a servidores MCP declarados em
`~/.opencli/config.toml`.

```toml
[mcp_servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env_vars = ["GITHUB_PERSONAL_ACCESS_TOKEN"]

[mcp_servers.internal]
url = "https://mcp.example.com/mcp"
```

`env_vars` nomeia as variáveis de que o servidor precisa; **os valores ficam com
as suas outras chaves e não neste arquivo, que é compartilhado**. Um servidor
declarado aqui começa **com a próxima conversa que você abrir**, não com a que
está na sua frente.

O aplicativo de desktop escreve a mesma tabela em **Abilities → Connectors**, que
também **testa o aperto de mão** e lista as ferramentas que cada servidor
oferece.

### Apps (Connectors)

Use `$` no campo de escrever para inserir um conector do ChatGPT; o popover lista
os apps acessíveis. O comando `/apps` lista os apps disponíveis e instalados.
**Os conectados aparecem primeiro e são marcados como conectados**; os demais são
marcados como instaláveis.

### Notificações

O OpenCLI pode rodar um gancho de notificação quando o agente termina um turno.

```toml
notify = ["/path/to/your/script.sh"]
```

O programa é chamado com um argumento: **um objeto JSON descrevendo o que
aconteceu**. **Ele roda desacoplado, então um script lento não segura o próximo
turno**, e um script que falha é registrado em vez de aparecer na cara.

### Esquema JSON

O esquema JSON gerado para o `config.toml` mora em
[`opencli-rs/core/config.schema.json`](https://github.com/ai-dashboad/opencli/blob/main/opencli-rs/core/config.schema.json),
e **é publicado a cada release como `config-schema.json`**. Aponte o seu editor
para ele e tenha autocompletar e validação enquanto edita o arquivo na mão.

**Ele é gerado a partir dos tipos em Rust, e a CI falha se ele se desviar deles**
— ou seja, **é a única descrição deste arquivo que não pode ficar
desatualizada**.

### Avisos

O OpenCLI guarda as marcas de «não mostrar de novo» de alguns avisos da interface
na tabela `[notice]`.

Sair com Ctrl+C/Ctrl+D usa uma dica de duplo toque de ~1 segundo
(`ctrl + c again to quit`).
