---
title: Contribuir
sidebar_position: 3
---

# Contribuir

**Los pull requests son bienvenidos, y no hay que esperar ninguna invitación.**
Este es un proyecto pequeño; **lo útil no suele ser una funcionalidad grande**,
sino una fila en una tabla, una frase en una traducción, o **un informe de error
lo bastante detallado como para poder actuar**.

## Las contribuciones más útiles

**Una fila en la tabla de modelos.**
[Comprobar un modelo](/reference/checking-a-model) es una tarea fija de cinco
minutos. **La tabla es corta porque solo contiene modelos que alguien ejecutó**, y
**un resultado negativo vale tanto como uno positivo**: **nadie publica sobre el
modelo que no funcionó, así que todo el mundo lo redescubre**.

**Una traducción, o una línea de corrección a una.** Vienen diez. Cualquiera se
puede **corregir frase a frase sin tocar el resto** — ver
[Idiomas](/configuration/languages). **Un idioma nuevo es un único archivo JSON.**

**Un informe de error con las cuatro cosas.** El modelo y el proveedor escritos
con exactitud (`qwen3-coder:30b` en Ollama, no «un modelo local»), qué pediste,
qué pasó, y cincuenta líneas de `~/.opencli/log` alrededor del fallo.
**Revisa esas líneas por si llevan claves antes de pegarlas.**

**Contarnos qué querías hacer de verdad.** Los departamentos y habilidades
incluidos **se escribieron a partir de conjeturas sobre lo que la gente
necesita**. **Lo que buscaste y no encontraste es lo más útil que puedes decir.**

## Antes de escribir código

**Abre una incidencia primero para cualquier cosa mayor que un arreglo.** No como
barrera, **sino para acordar el enfoque antes de que te gastes una tarde en él**.
**Un PR que llega sin incidencia detrás igualmente se lee.**

## Preparar el entorno

Rust y pnpm; el workspace es `opencli-rs/`, la interfaz web es `web/` y la
carcasa de escritorio es `desktop/`.

```shell
git clone https://github.com/ai-dashboad/opencli
cd opencli
pnpm install
cargo build -p opencli-cli
```

`just` desde la raíz del repositorio ejecuta los ayudantes del workspace;
`just help` los lista.

## Antes de abrir el PR

```shell
just fmt
just fix -p <crate>
cargo test -p <crate>
```

**No ejecutes un `cargo fmt` a secas.** El árbol está formateado con
`imports_granularity=Item`, que es **una opción solo de nightly**. En stable esa
opción **se ignora en silencio**, así que `cargo fmt` **reescribe el bloque de
imports de casi todos los archivos del workspace** y **entierra tu cambio bajo
cientos de diferencias sin relación**. **`just fmt` invoca nightly precisamente
por eso.** Sin una toolchain nightly (`rustup toolchain install nightly`),
**formatea solo los archivos que tocaste y deja que CI confirme el resto**.

Si tocaste la interfaz web, `python3 scripts/i18n-check.py` **encuentra el inglés
que nunca se envolvió para traducir**, incluidos los casos fáciles de pasar por
alto, como **texto partido por una etiqueta en línea** y **etiquetas construidas en
tiempo de importación**.

## Qué hace fácil de fusionar un PR

- **Una sola cosa.** Los arreglos sin relación van en PRs separados.
- **Un test que falla antes de tu cambio y pasa después.** No cobertura total:
  **una aserción que habría cazado el error**.
- **Commits que compilan cada uno.** Es lo que hace posibles la revisión y la
  reversión.
- **Documentación, si cambió el comportamiento.** El README, `opencli --help`, o
  la página de aquí que ahora está mal.
- **Qué, por qué y cómo** en la descripción. **El *por qué* es la parte que no se
  lee en el diff.**

## Sin CLA

**No hay nada que firmar.** Las contribuciones van bajo
[Apache-2.0](https://github.com/ai-dashboad/opencli/blob/main/LICENSE), como el
resto del árbol.

## Informar de una vulnerabilidad

**No abras una incidencia pública para un fallo de seguridad.** Usa el
[formulario de aviso privado](https://github.com/ai-dashboad/opencli/security/advisories/new)
de GitHub, que **llega a los mantenedores sin publicar nada**.

**Las partes que más merecen mirarse**: la política del sandbox, la ruta de
aprobación, y **todo lo que decide qué puede tocar una llamada a herramienta**.
**Un agente que lee tus archivos y ejecuta comandos en tu máquina tiene mucha
superficie, y es mejor que lo encuentres tú a que lo encuentre otro.**

## Comportarse con decencia

**Trata a la gente con respeto**; seguimos el
[Contributor Covenant](https://www.contributor-covenant.org/). **Presume buena
intención**: **la comunicación escrita es difícil, así que inclínate hacia la
generosidad.** Si algo resulta confuso, eso ya merece su propia incidencia:
**una documentación confusa es un error de la documentación**.
