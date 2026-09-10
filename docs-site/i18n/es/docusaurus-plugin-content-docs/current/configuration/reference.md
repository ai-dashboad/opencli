---
title: Referencia completa de configuración
sidebar_position: 4
---

# Referencia completa de configuración

Todas las claves que acepta `~/.opencli/config.toml`. Para **el puñado que toca
casi todo el mundo**, [el archivo de configuración](/configuration/config-file)
es más corto.

### La vía más rápida: deja que OpenCLI encuentre tus modelos

Si ya ejecutas Ollama, LM Studio, vLLM o llama.cpp en local:

```shell
opencli provider scan
```

**Sondea los puertos habituales de localhost**, pregunta a cada servidor que
encuentra qué modelos sirve y escribe las secciones `[model_providers.*]` y
`[[models]]` correspondientes en tu `config.toml` — **se conservan los
comentarios y ajustes existentes**. Añade `--dry-run` para ver antes qué
escribiría.

Para proveedores alojados, instala uno del catálogo y pon su clave:

```shell
opencli provider list          # el catálogo, más lo ya configurado
opencli provider add openrouter
export OPENROUTER_API_KEY=...
```

**El catálogo solo lleva datos de conexión**: no se distribuye ninguna clave con
el binario, y **nada está activo hasta que tú lo añades**. Para configurar algo
que no esté en el catálogo, escribe las secciones a mano como se describe abajo.

#### Rellenar las capacidades de un modelo

**La ventana de contexto de un modelo local y su soporte de llamada a
herramientas no están publicados en ninguna parte**, y **adivinarlos es peor que
dejarlos sin poner**: una ventana de contexto demasiado grande hace que el
proveedor **rechace** los turnos en lugar de auto-compactar. **Pregúntaselo al
modelo**:

```shell
opencli model probe <slug>            # añade --dry-run para previsualizar
```

**Lee los metadatos del propio runtime cuando los hay** (**Ollama informa de la
longitud de contexto real y de la lista de capacidades**) y además **hace una
petición en vivo** para ver si el modelo llama a una herramienta que se le ofrece
y si devuelve su razonamiento en un campo `reasoning` aparte. Lo hallado se
escribe en la entrada `[[models]]` del modelo.

**Los modelos que no pueden conversar** —los de embeddings, por ejemplo— **los
salta `provider scan`**, así que nunca llegan al selector `/model`.

### Elegir modelos y proveedores

Esta compilación trae ajustes preestablecidos para varias pasarelas, pero
**cualquier modelo alcanzable por una API compatible con OpenAI se puede
configurar** en `~/.opencli/config.toml` **sin recompilar**.

#### Añadir un proveedor

Las entradas de `[model_providers.<id>]` **sustituyen a un proveedor integrado
con el mismo id**, así que **esta es también la forma de reapuntar una pasarela
incluida a un proxy o a un espejo**:

```toml
[model_providers.my-gateway]
name = "My Gateway"
base_url = "https://gateway.example.com/v1"
env_key = "MY_GATEWAY_API_KEY"
wire_api = "chat"
# Opcional: súbelo si esta pasarela tarda en producir el primer token.
stream_idle_timeout_ms = 90000
```

**Las claves de API se leen siempre del entorno; nunca se guardan en el archivo
de configuración.**

#### Añadir un modelo

Declara modelos con `[[models]]`. Aparecen en el selector `/model` junto a los
preestablecidos, y **una entrada cuyo `model` coincide con un preestablecido lo
reemplaza**:

```toml
[[models]]
model = "qwen3-max"
provider = "my-gateway"
display_name = "Qwen3 Max"     # opcional, por defecto el slug
description = "Autoalojado."   # opcional
show_in_picker = true          # opcional, por defecto true
```

`provider` es obligatorio y debe nombrar a un proveedor definido arriba o a uno
integrado; **un modelo que apunte a un proveedor no definido se rechaza al
arrancar** en lugar de fallar más tarde con un error que no viene a cuento.

Para elegir un modelo sin añadirlo al selector, pon `model` y `model_provider`
directamente:

```toml
model = "qwen3-max"
model_provider = "my-gateway"
```

Si `model` nombra algo que no es ni un preestablecido ni una entrada `[[models]]`
y `model_provider` está sin poner, las peticiones **caen al proveedor `openai`** y
se registra un aviso.

#### Ventanas de contexto

**Los modelos de los que esta compilación no tiene metadatos empiezan con una
ventana conservadora de 131.072 tokens** y **aprenden la real del primer rechazo
por ventana de contexto** que devuelva la pasarela. Pon `model_context_window`
para fijarla explícitamente.

### Conectar con servidores MCP

OpenCLI puede conectarse a servidores MCP declarados en
`~/.opencli/config.toml`.

```toml
[mcp_servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env_vars = ["GITHUB_PERSONAL_ACCESS_TOKEN"]

[mcp_servers.internal]
url = "https://mcp.example.com/mcp"
```

`env_vars` nombra las variables que el servidor necesita; **los valores se
guardan con tus otras claves y no en este archivo, que se comparte**. Un servidor
declarado aquí arranca **con el siguiente chat que abras**, no con el que tienes
delante.

La aplicación de escritorio escribe la misma tabla desde
**Abilities → Connectors**, que además **prueba el saludo** y lista las
herramientas que ofrece cada servidor.

### Apps (Connectors)

Usa `$` en el campo de escritura para insertar un conector de ChatGPT; el
desplegable lista las apps accesibles. El comando `/apps` lista las apps
disponibles e instaladas. **Las conectadas aparecen primero y se marcan como
conectadas**; las demás se marcan como instalables.

### Notificaciones

OpenCLI puede ejecutar un gancho de notificación cuando el agente termina un
turno.

```toml
notify = ["/path/to/your/script.sh"]
```

El programa se llama con un argumento: **un objeto JSON que describe lo que ha
pasado**. **Se ejecuta desacoplado, así que un script lento no retrasa el
siguiente turno**, y un script que falla se registra en lugar de saltar a la
cara.

### Esquema JSON

El esquema JSON generado para `config.toml` vive en
[`opencli-rs/core/config.schema.json`](https://github.com/ai-dashboad/opencli/blob/main/opencli-rs/core/config.schema.json),
y **se sube con cada versión como `config-schema.json`**. Apunta tu editor ahí
para tener autocompletado y validación mientras editas el archivo a mano.

**Se genera a partir de los tipos de Rust, y CI falla si se desvía de ellos** —
así que **es la única descripción de este archivo que no puede quedarse
obsoleta**.

### Avisos

OpenCLI guarda las marcas de «no volver a mostrar» de algunos avisos de la
interfaz bajo la tabla `[notice]`.

Salir con Ctrl+C/Ctrl+D usa una pista de doble pulsación de ~1 segundo
(`ctrl + c again to quit`).
