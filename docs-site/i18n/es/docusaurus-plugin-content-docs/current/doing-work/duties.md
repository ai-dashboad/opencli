---
title: Turnos
sidebar_position: 2
---

# Turnos

**Un turno es un trabajo que un bot ejecuta cada cierto tiempo**, y que **se
detiene a preguntarte cuando llega a algo que no debería decidir solo**.

**Esa última parte es lo importante.** Cualquier cosa puede lanzar un prompt con
un temporizador; lo que hace esto útil para trabajo de verdad es que **se le
dice de antemano qué no tiene permitido zanjar**.

## Los cuatro campos

```
Qué             Compara ledger.csv con statement.csv, línea a línea,
                y lista lo que no cuadra con su referencia y su importe.

Reglas          Una diferencia menor de 1,00 es redondeo. Ignórala.

Escalar cuando  Cualquier línea individual por encima de 10.000.

Cada            24 horas
```

**«Qué» y «Reglas» se mantienen aparte a propósito.** El trabajo es el mismo
cada mañana; **el tope de reembolso es una política que alguien revisa**.
Fundidos en un solo prompt, cambiar ese número obliga a **releer la instrucción
entera para encontrarlo**.

**«Escalar cuando» se escribe con palabras, no como una condición.** Se le da al
modelo **como una obligación, no lo evalúa el producto** — lo que significa que
**es tan fiable como el modelo que lo lee**. Escríbelo como algo comprobable:
*cualquier línea individual por encima de 10.000*, no *cualquier cosa rara*.

## Qué pasa cuando escala

**El turno se detiene.** Aparece en **Bots → Esperándote** con la pregunta que
no pudo responder, y **no volverá a ejecutarse hasta que contestes**.

**Tu respuesta se lleva a la siguiente ejecución**, así que el bot no pregunta
dos veces lo mismo.

**Un turno que ya ha preguntado no abrirá una segunda pregunta**: repite la que
sigue abierta.

## Qué recuerda

**Un turno guarda notas entre ejecuciones.** Una ejecución que aprendió una cosa
**escribe esa cosa**; no tiene que repetir lo que ya sabía, y **una ejecución que
falló a mitad no se lleva por delante el resto de las notas**.

**Escribir un valor vacío es como se olvida algo a propósito.**

## Dónde se ejecuta

**En el directorio del departamento del bot**, que es **todo aquello en lo que la
ejecución puede escribir**. Un turno apuntado a otro sitio **queda retenido hasta
que autorices ese sitio por su nombre** — ver
[Sandbox y aprobaciones](/configuration/sandbox-and-approvals).

## Turnos y tareas programadas

**Ambos lanzan un prompt con un temporizador.** La diferencia es **a qué
pertenecen**.

| | Pertenece a | Escala | Recuerda |
| --- | --- | --- | --- |
| **Turno** | un bot, en un departamento | sí | sí |
| **Tarea programada** | nada | no | no |

Usa una tarea programada para *cada mañana a las nueve, dime qué cambió*. Usa un
turno para **trabajo que lleva una política pegada**.
