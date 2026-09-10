---
title: Idiomas
sidebar_position: 3
---

# Añadir un idioma

**Vienen diez traducciones con OpenCLI**: English, 简体中文, 繁體中文, 日本語,
한국어, Español, Português (Brasil), Français, Deutsch y Русский.

**Cualquier otro idioma es un archivo** — y también lo es una corrección a
cualquiera de esos.

## Desde la interfaz

**Customize → Language → Add a language file…** acepta un archivo `.json` y lo
guarda. **Aparece en el selector al instante.**

## A mano

El mismo archivo, en `~/.opencli/locales`, con el nombre del idioma:

```
~/.opencli/locales/nl.json
```

**Ambas vías escriben en el mismo sitio**, así que lo añadido desde la interfaz
se puede editar después a mano o copiar a otra máquina.

## Qué lleva dentro

**Cada entrada es una frase en inglés exactamente como aparece en la interfaz**,
y lo que hay que mostrar en su lugar:

```json
{
  "name": "Nederlands",
  "strings": {
    "Dispatch": "Verzenden",
    "Scheduled tasks": "Geplande taken",
    "Runs ({count})": "Uitvoeringen ({count})"
  }
}
```

`name` es lo que muestra el selector de idiomas. Si se omite, se usa el nombre
del archivo. **También funciona el mapa a secas, sin el envoltorio**:

```json
{ "Dispatch": "Verzenden" }
```

## Partir de una de las que vienen

Las traducciones incluidas son el mismo tipo de archivo, en
[`web/src/locales/`](https://github.com/ai-dashboad/opencli/tree/main/web/src/locales).
**Copia una, sustituye el lado derecho de cada línea** y tendrás **un punto de
partida completo** en vez de una lista de frases que hay que ir cazando.

Para ver todas las frases que usa la interfaz:

```
python3 scripts/i18n-check.py
```

## Marcadores

`{name}` dentro de una frase se rellena. **Conserva los mismos marcadores, en el
orden que tu idioma quiera** — **esa reordenación es la mayor parte de la razón
por la que existen**:

```json
{ "Allowed {count} of {total}": "Permitidos {count} de {total}" }
```

## Plurales

`plural()` elige **entre dos formas**. Eso basta para el inglés, el alemán, el
español, el francés y el portugués; **no tiene la tercera forma que el ruso pide
para 2–4**. Donde un idioma necesite más de dos formas, **escribe la frase de modo
que el número lleve el sentido por sí solo**: `запусков: {count}` en vez de un
sustantivo que tenga que concordar con él.

**El chino, el japonés y el coreano toman la forma singular y dejan que el número
haga el trabajo**, y de eso ya se encarga el producto.

## Corregir una traducción incluida

**Un archivo con el nombre de un idioma que ya viene se fusiona con él, no lo
sustituye.** Para cambiar una frase, escribe una entrada:

```json
{ "Dispatch": "Enviar" }
```

**Todo lo demás conserva la redacción incluida.**

## Cuándo surte efecto

Un archivo añadido desde la interfaz se aplica **de inmediato**. Uno colocado a
mano en el directorio **se lee cuando una ventana se conecta**, así que vuelve a
abrir la ventana. **Un archivo que no se puede analizar se omite**, con una línea
en el registro de la pasarela — **los demás idiomas no se ven afectados**.

## Frases sin traducir

**Una frase sin entrada se muestra en inglés**, así que una traducción parcial se
lee como una mezcla y no como **una pantalla de huecos**. **No hace falta
terminarla para que sirva.**

## De derecha a izquierda

El árabe, el hebreo y el persa no están entre las traducciones incluidas, y
**añadir uno como archivo dará una página maquetada de izquierda a derecha**. La
interfaz todavía no gestiona `dir="rtl"`; **eso es un cambio en la hoja de
estilos, no en un archivo de traducción**.
