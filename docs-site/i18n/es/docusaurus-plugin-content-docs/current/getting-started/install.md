---
title: Instalación
sidebar_position: 1
---

# Instalación

## Aplicación de escritorio

Descárgala desde [opencli.ai/download](https://opencli.ai/download.html), o
tómala directamente de la última versión:

| Plataforma | Descarga |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

**Cada enlace apunta siempre a la versión más reciente**, así que sigue
funcionando conforme cambian las versiones.

A partir de ahí, **la aplicación se actualiza sola**.

### Tu ordenador te avisará la primera vez

Estas compilaciones **no están firmadas** con un certificado de Apple ni de
Microsoft. Esos certificados cuestan dinero cada año y este proyecto no lo ha
gastado. **La descarga no tiene nada malo**: el sistema operativo no puede
saber quién la construyó.

**macOS** — tras arrastrar OpenCLI a Aplicaciones, ejecuta una vez:

```shell
xattr -dr com.apple.quarantine /Applications/OpenCLI.app
```

o haz clic derecho sobre la app, elige **Abrir** y confirma. **Solo el primer
arranque.**

**Windows** — SmartScreen muestra un recuadro azul. Pulsa **Más información** y
luego **Ejecutar de todas formas**.

## Línea de comandos

Un binario, macOS y Linux:

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

**Detecta tu plataforma**, descarga la compilación correspondiente y deja
`opencli` en `/usr/local/bin` — o en `~/.local/bin` si no puede escribir ahí,
diciéndote que lo añadas a tu `PATH`.

**El paquete de npm todavía no está publicado**: el ámbito `@ai-dashboad` no
está registrado. Hasta que lo esté, **el instalador de arriba y las
compilaciones de escritorio son las dos vías**.

## Desde el código

Una cadena de herramientas de Rust reciente:

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

El binario queda en `opencli-rs/target/release/opencli`.

## Qué escribió y dónde

| | |
| --- | --- |
| `~/.opencli/config.toml` | proveedores, modelos, ajustes de aprobación y de sandbox |
| `~/.opencli/workspace/` | donde empieza una conversación cuando nada indica otra cosa |
| `~/.opencli/skills/` | habilidades, incluidas las que vienen de serie |
| `~/.opencli/locales/` | los idiomas que añadas |
| `~/.opencli/log/` | registros |

**No se escribe nada fuera de `~/.opencli` hasta que apuntas el agente a un
directorio.**

## Siguiente

[Apúntalo a un modelo](/getting-started/point-at-a-model) — no trae ninguno, y
**no responderá mientras no tenga a quién preguntar**.
