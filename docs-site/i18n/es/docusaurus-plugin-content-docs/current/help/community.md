---
title: Pedir ayuda
sidebar_position: 4
---

# Pedir ayuda, y dónde decir algo

## Antes de preguntar

**Casi todo lo que se tuerce la primera semana está en**
[Solución de problemas](/help/troubleshooting), y la respuesta a *¿está soportado
mi proveedor?* está en [Proveedores](/getting-started/providers).

**Si el agente habla pero nunca toca tus archivos, eso casi siempre es el modelo y
no la instalación** — [compruébalo](/reference/checking-a-model) antes de
dedicarle una tarde a la configuración.

## Dónde preguntar

**[GitHub Issues](https://github.com/ai-dashboad/opencli/issues)** — errores, y
**cualquier cosa que se haya comportado distinto de lo que dice la
documentación**.

**[GitHub Discussions](https://github.com/ai-dashboad/opencli/discussions)** —
preguntas, ideas y «¿esto se supone que funciona así?».

**Todavía no hay servidor de chat.** Lo habrá **cuando haya gente suficiente para
que merezca la pena estar en él**; **una sala vacía no ayuda a nadie**.

## Qué hace que un informe sea fácil de atender

**Cuatro líneas**, y **la mayoría de los informes no las tiene**:

1. **El modelo y el proveedor, con su nombre exacto** — `qwen3-coder:30b` en
   Ollama, no «un modelo local».
2. **Qué le pediste**, literalmente.
3. **Qué pasó**, y **qué esperabas en su lugar**.
4. **Las últimas cincuenta líneas de `~/.opencli/log`** alrededor del fallo.

**Revisa esas líneas por si llevan claves antes de pegarlas.**

## Qué es lo que más ayuda

**Una fila en la tabla de modelos.**
[Comprobar un modelo](/reference/checking-a-model) es una tarea fija y unos cinco
minutos. **La tabla es corta porque solo contiene lo que se ha ejecutado**, y
**un resultado negativo vale tanto como uno positivo** — **nadie publica sobre el
modelo que no funcionó, así que todo el mundo lo redescubre**.

**Una traducción, o una corrección a una.** Vienen diez. Cualquiera de ellas se
puede **corregir línea a línea sin tocar el resto** — ver
[Idiomas](/configuration/languages).

**Contarnos qué intentabas hacer de verdad.** Los departamentos y flujos que
vienen incluidos **se escribieron a partir de conjeturas sobre lo que la gente
necesita**. **Lo que buscaste y no encontraste es lo más útil que puedes decir.**

## Contribuir código

[Contribuir](/reference/contributing) tiene el montaje y el proceso de pull
request.
