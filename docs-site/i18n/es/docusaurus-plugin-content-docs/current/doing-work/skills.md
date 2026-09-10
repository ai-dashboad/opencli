---
title: Habilidades
sidebar_position: 4
---

# Habilidades

**Una habilidad es un conjunto de instrucciones al que el agente recurre cuando
una tarea lo pide**: un procedimiento escrito una vez, **en lugar de pegado en
un prompt cada vez**.

## Lo que viene de serie

**Seis flujos vienen con el producto y funcionan en cualquier directorio**:

| Habilidad | Qué hace |
| --- | --- |
| `spreadsheet-review` | Comprueba un archivo de filas contra sus reglas declaradas e informa de las filas que las incumplen **con su número de fila** |
| `weekly-report` | Lo que **realmente cambió** aquí durante un periodo: hecho, en curso, y lo que necesita una decisión |
| `inbox-triage` | Ordena los mensajes por lo que están pidiendo y **marca los que debe contestar una persona** |
| `document-compare` | Qué cambió **en sustancia** entre dos borradores, separado de **lo que solo cambió de redacción** |
| `meeting-notes` | Una transcripción convertida en decisiones, acciones con responsable y preguntas abiertas |
| `records-review` | Levanta lo que merece comprobarse en un conjunto de registros, **citando la nota de la que salió cada cosa** |

Dos más, heredadas, tratan de **escribir e instalar habilidades**:
`skill-creator` y `skill-installer`.

## De dónde vienen

| Ámbito | Directorio |
| --- | --- |
| De serie | `~/.opencli/skills/.system` — se reescribe al actualizar la app |
| Tuyas | `~/.opencli/skills` |
| De este proyecto | `.opencli/skills` en el directorio de trabajo |

## Escribir una

Un directorio con un `SKILL.md` cuyo front matter dice qué es y **cuándo
usarla**:

```markdown
---
name: invoice-check
description: Check invoices against our payment rules and report what breaks
  them. Use when asked to review, check or audit a file of invoices.
metadata:
  short-description: Find invoices that break the rules
---

# Invoice check

## Find the rules before reading the rows
...
```

**La `description` es contra lo que el agente compara una petición.** Una
descripción que solo dice lo que la habilidad ***es*** **deja que el modelo
adivine cuándo aplica**: **todas las habilidades de serie nombran sus ocasiones**,
y las tuyas deberían hacerlo también.

## Qué hace que una funcione

**Leer las seis que vienen es la vía más rápida para ver la forma**, pero hay
tres cosas que se repiten:

- **Di qué hay que leer, y en qué orden.** «Lo más antiguo primero» es una
  instrucción de verdad; «revisa los registros» no lo es.
- **Di qué hay que producir.** Un archivo con nombre, o una estructura
  declarada. No «un resumen».
- **Di qué no debe hacer nunca.** La habilidad clínica que viene de serie
  **dedica a esto un tercio de su longitud**, y por eso puede existir.

**Una aprendida a golpes**: si un número importa, **di de dónde tiene que salir
ese número**. La habilidad de hoja de cálculo pide un recuento de filas, y **la
primera ejecución lo dijo de memoria y falló por uno**. Ahora **exige que el
recuento venga del script que hizo la comprobación**.

## Apagar una

Cada habilidad tiene un interruptor en **Abilities → Skills**. Un cambio se
aplica **al siguiente chat que abras**, no al que ya está en marcha.
