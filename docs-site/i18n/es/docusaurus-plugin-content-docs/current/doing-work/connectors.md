---
title: Conectores
sidebar_position: 5
---

# Conectores

**Un conector es un servidor MCP a través del cual el agente puede llamar
herramientas**: GitHub, una base de datos, un navegador, tus archivos. Es **cómo
el agente alcanza algo que no es un archivo de esta máquina**.

## Añadir uno

**Abilities → Connectors** lista lo que está configurado y lo que se puede
añadir. Añadir desde el catálogo es un clic; añadir el tuyo requiere un nombre y
un comando o una URL:

| | |
| --- | --- |
| **Comando local** | un programa de esta máquina, arrancado por OpenCLI |
| **Servidor HTTP** | un servidor accesible por HTTP |

## Claves

**La mayoría de los conectores necesita una.** Nombra las variables de entorno
que el servidor espera —**solo los nombres**, separados por espacios— y **pon los
valores después**.

**Los valores se guardan con tus otras claves, no en la configuración del
conector**, y **no vuelven a mostrarse una vez guardados**. Es deliberado: **el
archivo de configuración se comparte y se pega en incidencias, y una clave que
esté ahí se va con él.**

## Probar

**Test connections** arranca todos los servidores configurados y espera un
saludo. Es un botón, y no algo que ocurra al abrir el panel, porque **arrancarlos
tarda segundos** — medidos en **2,2** contra uno que falla al autenticarse.

El resultado aparece en cada fila, **con las herramientas que ofrece ese
servidor**.

## Cuándo surte efecto un cambio

**Los servidores arrancan con un chat.** Un conector añadido ahora se aplica a la
**siguiente** conversación que abras, no a la que tienes delante.

## Lo que un conector no es

**No es una capacidad que el modelo adquiera.** Un modelo que no llama
herramientas **no empieza a llamarlas porque se haya añadido un conector** — ver
[Limitaciones](/reference/limits).

## Departamentos

Las etiquetas sobre la lista filtran por departamento, así que a un departamento
de Finanzas recién creado se le puede preguntar *a qué debería estar conectado
esto* en lugar de *qué es Playwright*.

**Un conector sin etiqueta de departamento se muestra bajo todas**: **algo que
nadie ha clasificado no debería quedar oculto para todo el mundo.**
