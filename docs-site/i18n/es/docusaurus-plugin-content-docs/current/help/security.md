---
title: Seguridad
sidebar_position: 3
---

# Seguridad

**Qué hace este producto con tu máquina y con tus datos**, dicho **para que
puedas decidir en lugar de suponer**.

## Qué sale de tu máquina

Tus prompts, y los archivos que el agente lea en tu nombre, van **al endpoint
que hayas configurado** y a ningún otro sitio. **No hay ninguna pasarela nuestra
en medio.**

Si ese endpoint se ejecuta en tu propia máquina, **no sale nada de ella**.

**Dos excepciones**, ambas **fallan en silencio sin conexión** y **ninguna lleva
nada de lo que hayas escrito**:

- la aplicación de escritorio pregunta a su endpoint de actualización si hay una
  versión más nueva
- el panel Models descarga de Hugging Face una lista de modelos populares al
  abrirse

## Qué puede hacerle el agente a tu máquina

**Dos ajustes, con trabajos distintos.**

**El sandbox** decide qué *puede* hacer. Con `workspace-write` —el valor por
defecto— puede escribir **en cualquier punto de su directorio de trabajo** y en
ningún otro sitio. **Las lecturas no están restringidas en ningún modo.**

**Las aprobaciones** deciden qué tiene que preguntar antes, desde todo comando
desconocido hasta nada en absoluto.

**La combinación con la que conviene tener cuidado es `danger-full-access` junto
con `never`**: un agente **ejecutando comandos arbitrarios sin mostrar nada y sin
preguntar nada**. **Hay directorios donde eso es lo correcto. Tu carpeta personal
no es uno de ellos.**

[Sandbox y aprobaciones](/configuration/sandbox-and-approvals) tiene el detalle.

## Dónde puede arrancar una ejecución en segundo plano

**Una ejecución cuyo directorio no es el espacio de trabajo, ni un departamento,
ni un sitio que autorizaste por su nombre, queda retenida** en lugar de
arrancar.

Esto existe porque **una tarea programada creada antes de que existieran los
departamentos llevaba una carpeta personal y había corrido cuarenta y dos
veces**: **cada ejecución con acceso a `.ssh` y a `Documents`, sin preguntar a
nadie**.

**Poner las aprobaciones en `never` apaga esto junto con todo lo demás**, que es
lo que significa ese ajuste.

## Claves

**Las claves de API se guardan fuera de `config.toml`**, porque **ese archivo se
comparte y se pega en incidencias**. Se escriben donde están tus otros secretos y
**no se vuelven a mostrar una vez guardadas**.

**Las claves de los conectores funcionan igual**: tú nombras las variables de
entorno que necesita un servidor, y **los valores se guardan aparte de la
configuración de ese servidor**.

## La pasarela

La aplicación de escritorio y la interfaz web hablan con **una pasarela local**.
Esta:

- **se ata al loopback** salvo que se le diga expresamente lo contrario, de modo
  que **no queda expuesta a la red por accidente**
- **exige un token en cada conexión**, generado por ejecución y mostrado una sola
  vez, para que **ni otro usuario local ni una página web de tu navegador puedan
  manejarla**

**Un cliente de esta pasarela puede hacer que el agente ejecute comandos en la
máquina que la aloja.** Ese es todo el propósito, **y por eso existe el token**.

**Es de un solo usuario por diseño.** Servir a varias personas no confiables
exigiría **aislamiento por usuario**, y eso queda fuera del alcance.

## Teléfonos emparejados

**Emparejar entrega a un dispositivo un token que le permite manejar el agente de
esta máquina.** La dirección se muestra una sola vez. **Empareja solo tus propios
dispositivos y revoca cualquier cosa que no reconozcas.**

## Las compilaciones no están firmadas

**Sin certificado de Apple ni de Microsoft**, tu sistema operativo **no puede
saber quién las construyó y lo dice**. **Esa advertencia es correcta y deberías
leerla como correcta.**

Si prefieres no fiarte de nuestra palabra en nada de esto, el código está
[aquí](https://github.com/ai-dashboad/opencli) y es **un `cargo build`**.

## Informar de algo

**No abras una incidencia pública para un fallo de seguridad.** Usa el
[formulario de aviso privado](https://github.com/ai-dashboad/opencli/security/advisories/new)
de GitHub, que **llega a los mantenedores sin publicar nada**.

**Lo que más merece la pena mirar es lo que hay en esta página**: la política del
sandbox, la ruta de aprobación, la comprobación de directorio de las ejecuciones
en segundo plano y el token de la pasarela.

**No incluyas tus claves, ni registros que las contengan.**
