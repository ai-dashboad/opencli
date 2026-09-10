---
title: Solución de problemas
sidebar_position: 2
---

# Solución de problemas

## Dice que las credenciales fueron rechazadas

```
The model provider would not accept the request without credentials.
(status 401 Unauthorized)
```

**O no hay clave puesta para el proveedor que has seleccionado, o la que hay no
vale para él.** Tres cosas que comprobar, **en orden**:

1. **Qué proveedor está seleccionado de verdad** — `model` en `config.toml`, o el
   selector del campo de escritura. **Apuntar a un modelo cuyo proveedor nunca
   configuraste** es la causa habitual.
2. **La variable de entorno que nombra `env_key`** está puesta en el shell donde
   se ejecuta el agente. **La aplicación de escritorio la lee de donde guarda tus
   claves, no de tu shell.**
3. **La clave pertenece a ese proveedor.** La clave de uno no es la clave de otro.

**Un 401 no se reintenta, a propósito**: **unas credenciales no se vuelven válidas
por ofrecerlas otra vez.**

## La lista de modelos está vacía

El panel **Models** y el selector del campo de escritura vienen ambos del
`/v1/models` del proveedor. **Una lista vacía significa que esa petición falló**, y
el motivo está en `~/.opencli/log`.

**Un proveedor que exige clave no devuelve nada sin ella**, así que esto y el 401
de arriba **suelen ser el mismo problema**.

## Responde, pero nunca toca mis archivos

**Tu modelo no está llamando a herramientas.** Es **la decepción más frecuente**, y
**no es un error de configuración**: **hay modelos que simplemente no lo hacen**.

[Compruébalo](/reference/checking-a-model). Cinco minutos, una tarea fija. **Si
falla, el modelo es la herramienta equivocada para esto y ningún ajuste va a
cambiarlo.**

## Ejecuta `grep` en vez de leer el archivo como es debido

**La misma carencia de fondo, en forma más suave**: un modelo no entrenado hacia
el trabajo agéntico **echa mano del shell aunque tenga delante una herramienta de
archivos**. **Nada en la interfaz cierra esa brecha.**

## Una ejecución en segundo plano dice que me está esperando

**Su directorio de trabajo no es uno que este producto conozca**: ni el espacio de
trabajo, ni el directorio de un departamento, ni **un sitio que hayas autorizado
por su nombre**.

O bien **Autorizar este directorio** en el panel Dispatch, o **Mover** la tarea a
un departamento. **Se retiene en lugar de ejecutarse porque una ejecución puede
escribir en cualquier punto de su directorio.**

## Una tarea programada nunca se ejecutó

**Dos posibilidades**:

- **OpenCLI estaba cerrado.** El trabajo programado se ejecuta **solo mientras
  está abierto**.
- **Está retenida**, como arriba. Las tareas retenidas aparecen bajo
  *Esperándote*.

## La conversación se resume una y otra vez

**Si resume y enseguida vuelve a necesitarlo, la longitud no viene de la
conversación**: viene de **la parte fija de cada petición**, que es sobre todo
**los esquemas de herramientas de tus conectores**. **Cuatro conectores pueden ser
diez mil tokens antes de que hayas dicho nada.**

**Lo dice una vez, en lugar de hacerlo en cada turno.** La solución es **apagar los
conectores que no estés usando en esa conversación**.

## La aplicación de escritorio no abre

**macOS**: ejecuta `xattr -dr com.apple.quarantine /Applications/OpenCLI.app`, o
clic derecho → **Abrir**.

**Windows**: SmartScreen → **Más información** → **Ejecutar de todas formas**.

Si aun así se niega, **puede que la descarga esté incompleta**: compara el tamaño
del archivo con el de la página de la versión.

## El agente hizo algo que no vi

**Artifacts lista solo las ediciones hechas con la herramienta de edición de
archivos del agente.** Los archivos escritos por un comando de shell que él
ejecutó —un heredoc, un script, `git checkout`— **son cambios reales que no van a
aparecer ahí**.

**`git status` en el directorio de trabajo es la respuesta fiable.**

## La interfaz está en inglés aunque elegí otro idioma

**El diccionario se descarga al elegir su idioma**, así que hay **un momento en el
que se ve el inglés**. Si se queda en inglés, **el fragmento no se cargó**:
mira la consola del navegador en las herramientas de desarrollo de la app de
escritorio.

**Una frase sin traducción muestra siempre el inglés por diseño**; eso es **una
traducción parcial, no un fallo**.

## Dónde están los registros

```
~/.opencli/log
```

**Settings → About → Logs** abre el directorio. Al informar de un problema, **las
últimas cincuenta líneas alrededor del fallo casi siempre bastan** — y **revísalas
por si llevan claves antes de pegarlas**.
