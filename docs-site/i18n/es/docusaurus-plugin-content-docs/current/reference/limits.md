---
title: Limitaciones
sidebar_position: 2
---

# Limitaciones

**Dicho aquí en lugar de descubierto después.**

## Los modelos

**Un modelo local pequeño no es tan bueno en esto como uno de frontera.** La
interfaz es la misma; **el razonamiento no**.

**Los modelos abiertos generalistas echan mano de `grep` aunque tengan una
herramienta de archivos.** Dada una forma estructurada de leer un archivo, un
modelo no entrenado hacia el trabajo agéntico **seguirá saliendo al shell**. **Es
una carencia de los modelos, y ninguna interfaz la cierra.** **Lo que este
proyecto puede cambiar es el alcance, no la inteligencia.**

**Un modelo que no llame a herramientas no puede hacer este trabajo en
absoluto.** Conversará. [Comprueba el tuyo](/reference/checking-a-model) antes de
apostar por él — cinco minutos, una tarea fija.

## El recuento

**Los recuentos de tokens se estiman, nunca se cuentan.** El tokenizador
pertenece al modelo, y **esto ejecuta modelos que nunca ha visto**. Cuatro bytes
ASCII por token, un token por carácter en los demás casos: **ajustado tanto para
el inglés como para el chino**, e **inclinado a contar de más en el resto**.

**Todo lo que viene después es, por tanto, aproximado**: cuándo se resume una
conversación, cuándo se corta la salida de una herramienta, y lo que dice la
línea de uso.

## La planificación

**Las tareas programadas y los turnos se ejecutan solo mientras OpenCLI está
abierto.** **Esto es un agente local, no un servidor.** Todo lo que deba
dispararse con la máquina dormida corresponde **al planificador del sistema
operativo**.

## El sandbox

**Una ejecución en segundo plano puede escribir cualquier cosa dentro del
directorio en el que se ejecuta.** **La raíz escribible *es* ese directorio.** Las
ejecuciones fuera del directorio de un departamento **quedan retenidas hasta que
autorices el sitio por su nombre** — **salvo que las aprobaciones estén en never**,
en cuyo caso no se retiene nada.

**Las lecturas no están restringidas nunca**, en ningún modo de sandbox.

## El registro de lo que cambió

**Artifacts lista solo las ediciones hechas con la herramienta de edición de
archivos del agente.** Los archivos escritos por un comando de shell que él
ejecutó —un heredoc, un script, `git checkout`— no se registran y no van a
aparecer. **El cambio es real; la lista es incompleta.**

## Las compilaciones de escritorio

**No están firmadas** con un certificado de Apple ni de Microsoft. Tu sistema
operativo te avisará, **y hace bien**: **no puede saber quién las construyó**.
[Instalación](/getting-started/install) dice qué hacer.

## La interfaz

**Los idiomas de derecha a izquierda no están soportados.** El árabe, el hebreo y
el persa se pueden añadir como archivos de traducción, y **la página se seguirá
maquetando de izquierda a derecha**. **Eso es un cambio en la hoja de estilos, no
en una traducción.**

## La escalada es una instrucción, no una garantía

El *escalar cuando* de un turno **se le da al modelo como una obligación**. **No lo
evalúa este producto**, lo que significa que es **exactamente tan fiable como el
modelo que lo lee**. Escríbelo como algo comprobable —*cualquier línea individual
por encima de 10.000*— en vez de *cualquier cosa rara*.
