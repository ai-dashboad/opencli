---
title: El archivo de configuración
sidebar_position: 1
---

# El archivo de configuración

`~/.opencli/config.toml`. **Todo lo de aquí tiene un valor por defecto**; el
archivo solo guarda **lo que has cambiado**.

**La aplicación de escritorio escribe el mismo archivo y conserva tus
comentarios y tu formato**, así que **editar a mano y editar en Settings son el
mismo acto**.

## Proveedores y modelos

**Un proveedor es una URL base y el nombre de una variable de entorno con la
clave**:

```toml
[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

Los modelos declarados debajo aparecen en el selector:

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

`slug` es **lo que tú escribes**; `model` es **como lo llama el proveedor**.
**Difieren lo bastante a menudo como para que valga la pena separarlos.**

**No hace falta declararlos.** Los modelos se obtienen del `/v1/models` del
proveedor. Declarar uno sirve para **fijar una ventana de contexto, un nombre
visible o los niveles de esfuerzo que acepta**.

## Aprobaciones y sandbox

```toml
approval_policy = "on-failure"   # untrusted | on-failure | never
sandbox_mode = "workspace-write" # read-only | workspace-write | danger-full-access
```

Explicado en [Sandbox y aprobaciones](/configuration/sandbox-and-approvals).

## Salida de las herramientas

```toml
tool_output_token_limit = 10000
```

**Un presupuesto para lo que la salida de una herramienta puede añadir a la
conversación.**

**Los tokens se estiman, no se cuentan.** El tokenizador pertenece al modelo, y
**esto ejecuta modelos que nunca ha visto**. La estimación es **cuatro bytes
ASCII por token y un token por carácter en los demás casos** — ajustada tanto
para el inglés como para el chino, y **inclinada a contar de más en el resto**.
Poner esto en 500 **no corta exactamente en 500 tokens**; **corta cerca, en las
mismas unidades en las que está escrito el número**.

## Ver qué está en vigor

**Settings** muestra **todos los valores que se aplican y de dónde vienen**,
incluidos **los que nunca has puesto**. `Show raw config` es el archivo mismo.

## La referencia completa

Todas las claves que este archivo acepta, con su valor por defecto:
[Referencia completa de configuración](/configuration/reference).
