<div align="center">

<img src="../website/public/favicon.svg" width="80" alt="OpenCLI" />

# OpenCLI

**Un agente de código abierto para los modelos que ejecutas tú**

[![CI](https://img.shields.io/github/actions/workflow/status/ai-dashboad/opencli/rust-ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/ai-dashboad/opencli/actions/workflows/rust-ci.yml)
[![Release](https://img.shields.io/github/v/release/ai-dashboad/opencli?style=flat-square)](https://github.com/ai-dashboad/opencli/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ai-dashboad/opencli/total?style=flat-square)](https://github.com/ai-dashboad/opencli/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat-square)](../LICENSE)

[English](../README.md) ·
[简体中文](./README.zh-CN.md) ·
[繁體中文](./README.zh-TW.md) ·
[日本語](./README.ja.md) ·
[한국어](./README.ko.md) ·
**Español** ·
[Português](./README.pt-BR.md) ·
[Français](./README.fr.md) ·
[Deutsch](./README.de.md) ·
[Русский](./README.ru.md)

[Descargar](https://opencli.ai/download.html) ·
[Documentación](https://docs.opencli.ai) ·
[Primeros pasos](https://docs.opencli.ai/getting-started/install) ·
[Proveedores](https://docs.opencli.ai/getting-started/providers) ·
[Límites](https://docs.opencli.ai/reference/limits)

</div>

OpenCLI es un agente que se ejecuta en tu propio ordenador y funciona con cualquier modelo compatible con la API de OpenAI — uno en la máquina que tienes delante, uno en tu propio servidor, o un proveedor alojado cuando te convenga. Lee tus archivos, ejecuta tus comandos y edita tu trabajo, en una terminal y en una aplicación de escritorio que comparten las mismas conversaciones.

**No trae nada dentro.** Ni modelos, ni cuentas, ni claves, ni opinión sobre a quién le compras la inferencia. Apúntalo a un endpoint y sus modelos aparecen solos; lo que escribes va allí y a ningún otro sitio.

## Descargar

| Plataforma | |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

La aplicación se actualiza sola después. Estas compilaciones no llevan certificado de Apple ni de Microsoft, así que el primer arranque necesita un paso más — [qué hacer](https://docs.opencli.ai/getting-started/install).

**Línea de comandos, macOS y Linux:**

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

Después apúntalo a un modelo.

## Qué hace

- 🗂 **Trabaja con archivos, no solo con código.** Lee una carpeta de facturas igual que lee un repositorio — y la mayor parte del trabajo que la gente tiene de verdad es del primer tipo.

- 🏢 **Organizado como una oficina.** Un **departamento** es un directorio con instrucciones permanentes. Un **bot** es una conversación dentro de uno, con un cometido. Vienen nueve departamentos con datos de ejemplo, así que cada uno se puede probar antes de configurarlo.

- ⏰ **Las guardias llegan solas** — y **se detienen a preguntarte** cuando llegan a algo que no deberían decidir por su cuenta. Ese límite se escribe con palabras, por adelantado: *cualquier línea que pase de 10.000*.

- 🤝 **Los bots se pasan el trabajo entre ellos,** con lo que hicieron y los archivos que produjeron. Con un tope de ocho saltos y tres apariciones cada uno, para que una cadena no se desboque.

- 🧰 **Seis flujos de trabajo vienen como habilidades** y funcionan en cualquier directorio: revisar filas contra sus reglas, informar de qué cambió en una semana, clasificar una bandeja de entrada, comparar dos borradores, convertir una transcripción en decisiones y responsables, y leer registros buscando lo que merece una comprobación.

- 🔌 **Los conectores son servidores MCP** — GitHub, Postgres, Slack, Notion, un navegador. Las claves se guardan aparte del archivo de configuración, que acaba compartiéndose.

- 🚦 **Un entorno aislado con un borde visible.** Una ejecución puede escribir dentro de su propio directorio y en ningún otro sitio, y una apuntada a un lugar desconocido queda retenida hasta que autorices ese lugar por su nombre.

- 🌍 **Diez idiomas,** y cualquier otro es un archivo JSON que puedes añadir sin recompilar nada.

- 💻 **Terminal, escritorio y una interfaz web local** sobre la misma pasarela, así que una conversación empezada en una continúa en otra.

## Funciona con

No son treinta integraciones — es **un protocolo**. Todo lo que responda a `/v1/chat/completions` y `/v1/models` como lo hace OpenAI se puede apuntar, y sus modelos aparecen solos. A cada endpoint de abajo se le pidió su lista de modelos antes de ponerlo aquí.

**En tu máquina** — Ollama · LM Studio · llama.cpp · LocalAI · Jan ·
Xinference · KoboldCpp · llamafile

**En tu servidor** — vLLM · SGLang · Text Generation Inference · NVIDIA NIM ·
LiteLLM

**Alojando modelos abiertos** — Fireworks · Together · Groq · DeepInfra · Baseten ·
Novita · Hyperbolic · Nebius · Cerebras · SambaNova · Featherless · Chutes ·
NVIDIA · Hugging Face · OpenRouter · Vercel AI Gateway · Perplexity

**En China** — 硅基流动 · 无问芯穹 · PPIO · 七牛云 · 魔搭 · 阿里云百炼 ·
火山方舟 / 豆包 · 百度千帆 · 讯飞星火 · 小米 MiMo · DeepSeek · 智谱 ·
月之暗面 · MiniMax · 阶跃星辰 · 腾讯混元 · 百川

**Modelos cerrados, cuando quieras uno** — OpenAI · Anthropic · Mistral · xAI

**Varios dan una cuota gratuita**, que es la forma más barata de probar un modelo más grande de lo que cabe en tu máquina. Endpoints, y qué proveedor sirve qué modelo: [Proveedores](https://docs.opencli.ai/getting-started/providers).

> **Que se pueda alcanzar no es lo mismo que que sirva para esto.** Llamar a herramientas es lo que separa un modelo que puede hacer este trabajo de uno que solo sabe hablar de él, y la ficha del modelo nunca lo dice.
> [Comprueba el tuyo](https://docs.opencli.ai/reference/checking-a-model) —
> una tarea fija, cinco minutos. La tabla tiene una fila porque se ha probado un modelo — **añadir una fila es la contribución más útil que puedes hacer.**

## Lo que no puede hacer

- **Los modelos abiertos generalistas tiran de `grep` aunque tengan una herramienta de archivos.** Es una carencia de los modelos; ninguna interfaz la cierra.
- **Los tokens se estiman, nunca se cuentan.** El tokenizador pertenece al modelo, y esto ejecuta modelos que nunca ha visto.
- **El trabajo programado solo corre mientras OpenCLI está abierto.** Es un agente local, no un servidor.
- **Una ejecución en segundo plano puede escribir cualquier cosa dentro del directorio en el que corre.**
- **Las compilaciones de escritorio no están firmadas.** Tu sistema operativo hace bien en avisarte.
- **Los idiomas de derecha a izquierda todavía no se maquetan.**

[Límites](https://docs.opencli.ai/reference/limits) dice el porqué de cada uno.

## De dónde viene esto

Un fork de [Codex CLI de OpenAI](https://github.com/openai/codex), Copyright 2025 OpenAI, Apache-2.0. **Sin relación con OpenAI.**

Codex está hecho para los modelos de OpenAI y esto está hecho para los de todos los demás, lo que cambia más que un nombre. Los departamentos, los bots, las guardias, las ejecuciones en segundo plano y los flujos de trabajo son nuestros, igual que buena parte del trabajo sobre qué se rompe cuando el modelo es pequeño — un bucle de compactación que resumía una vez por turno durante once turnos y tiraba el hilo cada vez, y una estimación de tokens que leía una página de chino como tres cuartas partes de su coste real.

[Apache-2.0](../LICENSE) · [NOTICE](../NOTICE) ·
[Contribuir](https://docs.opencli.ai/reference/contributing)
