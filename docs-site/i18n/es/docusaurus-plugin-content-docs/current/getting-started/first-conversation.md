---
title: Primera conversación
sidebar_position: 3
---

# Primera conversación

## Dónde empieza

Un chat nuevo se abre en `~/.opencli/workspace`, salvo que pertenezca a un
departamento, en cuyo caso se abre en el directorio de ese departamento.

**Esto importa más de lo que parece.** El sandbox del agente puede escribir en
cualquier punto de su directorio de trabajo, así que **el directorio en el que
está abierta una conversación es todo lo que puede cambiar**. Antes el valor
por defecto era tu carpeta personal; ya no lo es, y el motivo está en
[Sandbox y aprobaciones](/configuration/sandbox-and-approvals).

Se cambia con el botón de carpeta que hay sobre el campo de escritura.

## Pedir algo

Frases normales. Tiene tus archivos, un shell y los
[conectores](/doing-work/connectors) que hayas añadido:

```
Lee invoices.csv y lista todas las filas que incumplan las reglas de rules.md
```

```
¿Qué cambió en este repositorio durante la última semana?
```

```
Compara their-draft.md con our-terms.md y lista todas las cláusulas que difieran
```

## Qué pasa antes de que se cambie nada

Por defecto, el agente **te enseña un comando que no consta como seguro antes
de ejecutarlo**, y **te enseña una escritura de archivo antes de hacerla**.
Apruebas o deniegas cada una.

Tres ajustes, en **Customize**:

| | |
| --- | --- |
| **Preguntar ante cualquier cosa desconocida** | todo comando que no conste como seguro se muestra antes |
| **Preguntar solo cuando algo falla** | los comandos se ejecutan sin vigilancia; se te pregunta cuando uno necesita más acceso |
| **No preguntar nunca** | no se muestra nada antes de ejecutarlo |

Lo último es para un directorio **en el que dejarías suelto un script**. Se
explica como es debido en
[Sandbox y aprobaciones](/configuration/sandbox-and-approvals).

## Ver lo que hizo

**Artifacts** lista los archivos que el agente editó en esta conversación, con
sus diferencias. Un límite honesto: **solo aparecen las ediciones hechas con la
herramienta de edición de archivos del agente**. Los archivos escritos por un
comando de shell que él ejecutó —un heredoc, un script, `git checkout`— no se
registran y no van a aparecer.

## Cuando deja de caber

Una conversación que se ha alargado **se resume para que siga cabiendo**. Verás
**Summarising the conversation…**, y después el hilo continúa con un resumen en
lugar de los turnos antiguos.

**Si resumir no puede ayudar** —porque la longitud viene de los esquemas de las
herramientas y no de la conversación— **lo dice una vez, en lugar de repetirlo
en cada turno**.

## Siguiente

**Una conversación es una conversación.** Para que el trabajo ocurra sin que tú
estés delante, [monta un departamento](/doing-work/departments-and-bots).
