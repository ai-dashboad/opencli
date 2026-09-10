---
title: Apúntalo a un modelo
sidebar_position: 2
---

# Apúntalo a un modelo

**OpenCLI no trae modelo ni clave.** En una instalación nueva, la primera
pantalla lo dice y ofrece las dos vías de abajo.

**Esto no es una lista de integraciones: es un solo protocolo.** Cualquier cosa
que responda a `/v1/chat/completions` y `/v1/models` como lo hace OpenAI puede
recibir la conexión, y **sus modelos aparecen solos en el selector**. No hay
que declararlos uno a uno.

## En esta máquina

La aplicación de escritorio puede instalar uno por ti: abre **Models** y mira
**qué hay ya en la máquina** antes de ofrecerse a descargar nada.

A mano, con [Ollama](https://ollama.com) ya en marcha:

```toml
model = "qwen3-coder"

[model_providers.ollama]
name = "Ollama"
base_url = "http://localhost:11434/v1"
wire_api = "chat"

[[models]]
slug = "qwen3-coder"
model = "qwen3-coder:30b"
provider = "ollama"
context_window = 32768
```

Pon eso en `~/.opencli/config.toml` y ejecuta `opencli`.

**Nada sale de la máquina, y no hay ninguna clave que guardar.**

## Un proveedor

**Todos funcionan igual.** El patrón es una URL base y el nombre de una
variable de entorno con la clave:

```toml
model = "my-model"

[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

```shell
export MY_PROVIDER_API_KEY=...
opencli
```

En la aplicación de escritorio se hace lo mismo desde **Settings**, donde la
clave **se guarda y no vuelve a mostrarse**.

### Las cuotas gratuitas son la forma más barata de probar un modelo grande

Varios proveedores regalan algo, y así es como se ejecuta un modelo **mucho más
grande de lo que tu máquina podría alojar**. Lo que es gratis cambia de mes a
mes, así que esta página no cita cantidades: **consulta sus propias páginas de
precios**.

El [README](https://github.com/ai-dashboad/opencli#where-the-model-comes-from)
lleva la lista completa de proveedores, **cada uno verificado pidiéndole su
lista de modelos**.

## Un modelo puede no venir de la empresa que lo hizo

Xiaomi publica MiMo, ByteDance publica Seed, y **ninguna de las dos mantiene un
endpoint público compatible con OpenAI propio**. A ambos los llevan terceros:
llegas a MiMo por OpenRouter, Novita, DeepInfra, PPIO o Hugging Face, no por
Xiaomi.

## Ser alcanzable no es lo mismo que ser bueno en esto

**Un proveedor que responde a la API de OpenAI pero no a su parte de llamada a
herramientas conversará y poco más**: este agente trabaja llamando
herramientas. Antes de apostar por un modelo,
[compruébalo](/reference/checking-a-model) — **cinco minutos, una tarea fija**.

## Siguiente

[Tu primera conversación](/getting-started/first-conversation).
