---
title: Cuadrar un libro mayor
sidebar_position: 1
---

# Cuadrar un libro mayor, de principio a fin

**Veinte minutos, con un modelo local.** Al final tendrás **un departamento que
compara dos archivos cada mañana y se detiene a preguntarte cuando encuentra
algo por encima de un umbral que tú fijas**.

**Todo lo de aquí usa los datos de ejemplo que vienen incluidos**, así que **no
hay que preparar nada**.

## 1. Crear el departamento

**Projects → o empieza con uno que ya funciona → Finance.**

Crea `~/.opencli/workspace/finance`, escribe tres archivos dentro y contrata dos
bots.

**Los archivos llevan problemas plantados a propósito**:

| Archivo | Qué lleva |
| --- | --- |
| `ledger.csv` | lo que dicen tus libros |
| `statement.csv` | lo que dice el banco |
| `overdue.csv` | facturas pasadas de fecha |

## 2. Pedírselo una vez, a mano

Abre el departamento y escribe:

```
Compara ledger.csv con statement.csv. Lista todas las líneas que no cuadran,
con la referencia y el importe, y di qué crees que pasó.
```

**Fíjate en lo que hace.** Un modelo apto para esto **leerá ambos archivos con
una herramienta** y **responderá con filas y referencias**. Uno que no lo sea
**te pedirá que pegues el contenido o responderá con generalidades**: si eso
ocurre, **el problema es el modelo, no la instalación**.
[Compruébalo](/reference/checking-a-model).

## 3. Convertirlo en un turno

**El bot lo hizo una vez.** Un turno hace que **vuelva por su cuenta**.

Abre el bot **Reconciler** y define su turno:

| Campo | Qué poner |
| --- | --- |
| **Qué** | Compara `ledger.csv` con `statement.csv` línea a línea. Lista lo que no cuadra, con la referencia y el importe. |
| **Reglas** | Una diferencia menor de 1,00 es redondeo. Ignórala. |
| **Escalar cuando** | Cualquier línea individual por encima de 10.000. |
| **Cada** | 24 horas |

**«Reglas» y «Qué» están separados por un motivo**: el trabajo es el mismo cada
mañana, y **el umbral es una política que alguien revisa**. Fundidos en un solo
prompt, cambiar el número obliga a **releer la instrucción entera para
encontrarlo**.

## 4. Verlo detenerse

**Run now.** **Los datos de ejemplo contienen un descuadre por encima del
umbral**, así que el turno no llegará al final: **aparecerá en Bots →
Esperándote con la pregunta que no pudo responder**.

**En eso consiste toda la función.** Hizo el trabajo, **llegó a la raya que
trazaste y se detuvo en lugar de decidir**.

Contéstale. **Tu respuesta se lleva a la siguiente ejecución**, así que no
pregunta dos veces lo mismo.

## 5. Pasar el resultado

El departamento Finance viene con un segundo bot, **Chaser**. En la lista **puede
pasar a** del Reconciler, márcalo.

Ahora una ejecución que encuentre líneas descuadradas puede pasarlas —**junto con
lo que hizo y los archivos que produjo**— y el Chaser **redacta un correo de
reclamación por cliente sin que se le cuente el contexto**.

**Bots → Trabajo pasado entre bots** muestra la cadena después, y **marca la que
se detuvo por quedarse sin saltos** en lugar de por haber terminado.

## Lo que tienes ahora

- **un directorio en el que el agente puede escribir, y en ningún otro sitio**
- **trabajo que ocurre sin que tú lo lances**
- **un umbral escrito en el que se detiene y pregunta**
- **un segundo bot que recoge donde el primero lo dejó**

## Qué cambiar primero

**El umbral.** 10.000 **es un número de un ejemplo. El tuyo no lo es.**

**Las reglas.** «Una diferencia menor de 1,00 es redondeo» **es cierto en unos
libros y no en otros**.

**El intervalo.** Cada 24 horas **es una costumbre, no una ley**. **Un turno que
se ejecuta después de que el banco contabilice es más útil que uno que se
ejecuta a medianoche.**
