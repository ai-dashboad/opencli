---
title: Sandbox y aprobaciones
sidebar_position: 2
---

# Sandbox y aprobaciones

**Dos ajustes que hacen trabajos distintos.** El sandbox decide **qué *puede*
hacer** el agente; las aprobaciones deciden **qué tiene que preguntar antes**.

## El sandbox

```toml
sandbox_mode = "workspace-write"
```

| | El agente puede |
| --- | --- |
| `read-only` | mirar archivos, no cambiarlos |
| `workspace-write` | escribir dentro de su directorio de trabajo |
| `danger-full-access` | todo lo que pueda tu cuenta |

**Las lecturas nunca están restringidas.** Solo lo están la escritura y el
acceso a la red, así que `read-only` significa que **el agente ve todo tu disco
y no puede cambiar nada de él**.

### La raíz escribible es el directorio de trabajo

Bajo `workspace-write`, «el espacio de trabajo» significa **el directorio en el
que está abierta la conversación o la ejecución**. No el proyecto, no el
repositorio: **ese directorio**.

**Esta es la frase más importante de la página.** Una ejecución abierta en tu
carpeta personal puede escribir en `.ssh`, `Documents` y `Library`.

**Y no es hipotético.** Una tarea programada creada antes de que existieran los
departamentos **llevaba la carpeta personal y había corrido cuarenta y dos veces
así**, cada ejecución con acceso a todo ello, **sin preguntar a nadie y sin decir
nada**. Cambiar el valor por defecto para las conversaciones nuevas no la tocó,
porque **un valor por defecto no es retroactivo**.

Por eso existe **una segunda comprobación, en el momento en que arranca una
ejecución**.

## Dónde puede arrancar una ejecución en segundo plano

Una ejecución puede empezar cuando su directorio es **uno que este producto ya
conoce**:

- dentro del espacio de trabajo
- dentro del directorio de un departamento
- **en un sitio que autorizaste por su nombre**

Cualquier otro queda **retenido**, y aparece bajo **Esperándote** en el panel
Dispatch con un botón *Autorizar este directorio*. **Autorizar un sitio libera
todas las ejecuciones que lo esperaban.**

**Preguntar es el asunto**: ejecutar en un sitio poco habitual suele ser
**exactamente lo que se quería**, y la respuesta es **una pregunta, no una
negativa**.

## Aprobaciones

```toml
approval_policy = "on-failure"
```

| | |
| --- | --- |
| `untrusted` | todo comando que no conste como seguro se muestra antes |
| `on-failure` | los comandos se ejecutan sin vigilancia; se te pregunta cuando uno necesita más acceso |
| `never` | no se muestra nada antes de ejecutarlo |

`never` significa también que **no se retiene nada**. Quien ha desactivado las
aprobaciones **ha dicho, con todas las letras, que no quiere que se le detenga**,
y **decidir que quiso decir algo más estrecho sería que el producto pasara por
encima de su propio ajuste**.

Úsalo para un directorio **en el que dejarías suelto un script**.

## La combinación con la que se cae la gente

`sandbox_mode = "danger-full-access"` con `approval_policy = "never"` es **un
agente ejecutando comandos arbitrarios en tu máquina sin mostrar nada y sin
preguntar nada**. **Hay directorios donde esa es la respuesta correcta. Tu carpeta
personal no es uno de ellos.**

## Dos cosas que el sandbox no hace

- **No impide que el modelo lea tus archivos.** Las lecturas no están
  restringidas **en ningún modo**.
- **No cubre lo que hace después un comando que ejecutó.** Un script que el
  agente arranca hereda el sandbox; **un servicio que arranca y sobrevive a la
  ejecución, no**.
