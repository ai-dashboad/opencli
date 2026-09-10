---
title: Departamentos y bots
sidebar_position: 1
---

# Departamentos y bots

**Un chat es una conversación.** El trabajo que vuelve a aparecer necesita algo
**que le sobreviva**.

| | Es | Vive en |
| --- | --- | --- |
| **Departamento** | un directorio más instrucciones permanentes | `~/.opencli/workspace/<nombre>` por defecto |
| **Bot** | un chat dentro de un departamento, con un trabajo | ese departamento |
| **Turno** | un trabajo que vuelve por su cuenta | un bot |

**Las palabras están tomadas de una oficina a propósito.** Un departamento no es
una carpeta con un nombre bonito: es **el límite de lo que el trabajo de dentro
puede tocar**.

## Empezar por uno que ya funciona

**Vienen nueve departamentos con datos de ejemplo** —archivos con problemas ya
plantados dentro— para que la primera ejecución **haga algo** en vez de explicar
que no hay nada que hacer.

| Departamento | Qué trae |
| --- | --- |
| Finanzas | Cuadrar `ledger.csv` contra `statement.csv`; perseguir lo vencido |
| Soporte | Contestar lo que ha entrado; agrupar preguntas por lo que realmente son |
| Operaciones | Listar todo pedido sin enviar, y cuánto lleva esperando |
| Marketing | Convertir notas en una semana de publicaciones; agrupar contactos por lo que compraron |
| Personas y administración | Leer candidaturas frente a un puesto; sacar decisiones y responsables de las notas |
| Legal | Comparar su borrador con nuestros términos, cláusula a cláusula, citando ambos |
| Investigación | Dónde coinciden los estudios, dónde se contradicen y por qué |
| Historias clínicas | Qué está registrado y qué debería mirar un clínico, con la cita |
| Ingeniería | Leer un servicio e informar de lo que daría una respuesta equivocada |

**Projects → o empieza con uno que ya funciona.** Crea el directorio, escribe
los archivos de ejemplo y contrata a los bots.

## Hacer el tuyo

**Projects → New**, y luego:

- **Nombre** — cómo se llama
- **Carpeta** — se crea si no existe
- **Instrucciones permanentes** — se le dan al agente en ***cada*** chat que se
  abra aquí

**Las instrucciones permanentes son donde va lo que si no tendrías que reescribir
cada vez**: cómo se compila, qué no se toca, qué números son política. Están
separadas de la descripción, que **solo lees tú**.

## Bots

**Un bot es un chat con un trabajo.** Ese trabajo vuelve a entrar **cada vez que
se despierta al bot**, así que no hay que recordarle para qué está.

Cuatro estados, en el panel **Bots**:

| | |
| --- | --- |
| **Inactivo** | nada que hacer |
| **Trabajando** | hay una ejecución en marcha |
| **Esperándote** | se detuvo y preguntó — ver [Turnos](/doing-work/duties) |
| **Con error** | la última ejecución falló |

## Bots que se pasan trabajo

Un bot puede pasar trabajo a otro **por su nombre**, con lo que hizo y los
archivos que produjo. El que recibe **arranca desde ahí y no desde cero**.

**Tres negativas** impiden que eso se desboque, y son la sustancia del asunto:

- **Profundidad.** Una cadena se corta a **ocho saltos**.
- **Repetición.** Ningún bot puede aparecer **más de tres veces** en una cadena.
- **Dirección.** A un bot **solo puede pasarle trabajo un departamento
  autorizado**. Dentro de un mismo departamento siempre está permitido.

El panel **Bots** muestra todas las cadenas y **marca las que pararon por
quedarse sin cuerda** en lugar de por haber terminado.

## Siguiente

[Turnos](/doing-work/duties) — trabajo que vuelve sin que tú lo lances.
