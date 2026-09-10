---
title: Ejecuciones en segundo plano
sidebar_position: 3
---

# Ejecuciones en segundo plano

**Trabajo enviado para que se ejecute por su cuenta.** Cada ejecución es **un
agente aparte en su propio directorio**, así que **sigue adelante después de que
cierres el chat que la lanzó**.

## Cuatro formas de que empiece una

| Origen | La inicia |
| --- | --- |
| **Dispatch** | tú, a mano, en el panel Dispatch |
| **Programada** | una tarea recurrente que vence |
| **Turno** | el turno de un bot que vence |
| **Cowork** | enviar un mensaje en modo Cowork |

**Las cuatro acaban en la misma lista**, y por eso vale la pena leer el panel
aunque nunca despaches nada a mano.

## Solo se ejecutan mientras OpenCLI está abierto

**Esto es un agente local, no un servidor.** Todo lo que deba dispararse con la
máquina dormida corresponde **al planificador del sistema operativo**: `cron`,
`launchd`, el Programador de tareas.

Se dice sin rodeos porque la alternativa es **una tarea que en silencio no se
ejecutó nunca**.

## Cuántas a la vez

**Tres por defecto.** Cada una es un agente entero con sus propias llamadas al
modelo, así que **más de las que tu máquina puede alimentar las vuelve a todas
más lentas en lugar de acabar antes**. El número es un control del panel y
**surte efecto sin reiniciar**.

**El techo es dieciséis**, y no por gusto: pasado ese punto, **las ejecuciones
dejan de avanzar y empiezan a competir por los mismos pesos**.

## Directorios, y por qué una ejecución puede quedar retenida

El sandbox de una ejecución puede escribir **en cualquier punto de su directorio
de trabajo**. Ese directorio no es, por tanto, una comodidad: es **todo lo que la
ejecución puede cambiar**.

Así que una ejecución puede arrancar cuando su directorio es **uno que este
producto ya conoce**:

- dentro del espacio de trabajo
- dentro del directorio propio de un departamento
- **en un sitio que hayas autorizado por su nombre**

Cualquier otro queda **retenido**, y aparece bajo **Esperándote** con un botón
*Autorizar este directorio*. **Autorizar un sitio libera todas las ejecuciones
que lo esperaban.**

Si tu ajuste de aprobación es **No preguntar nunca**, **no se retiene nada**.
Quien ha desactivado las aprobaciones ya lo ha dicho, y **el producto no
contradice el ajuste que él mismo ofreció**.

## Mirar una

**La salida aparece según el agente la produce**, no cuando la ejecución termina.
Una ejecución de diez minutos **se puede leer los diez**.

## Retomarla

**Una ejecución terminada puede continuarse como una conversación normal**:
**Continue in a chat** abre un hilo nuevo en el mismo directorio, con **lo que se
le pidió y lo que informó ya en el contexto**.

**A la ejecución en sí no se le puede hablar.** Esta es la vía de vuelta.
