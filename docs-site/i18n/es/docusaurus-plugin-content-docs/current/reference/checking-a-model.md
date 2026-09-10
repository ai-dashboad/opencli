---
title: Comprobar un modelo
sidebar_position: 1
---

# Comprobar un modelo

La tabla del README dice **qué modelos pueden hacer de verdad este trabajo**. Es
corta **porque solo contiene lo que se ha ejecutado**, y **crece porque hay gente que lo
ejecuta**. Esta es esa tarea. **Lleva unos cinco minutos.**

## Por qué esta tarea y no un benchmark

**La pregunta no es lo listo que es un modelo.** Es si **usará una herramienta cuando la
tenga**, si **leerá el archivo entero y no la primera pantalla**, y si **informará de un
hallazgo frente a una regla en vez de describir el archivo**.

**Un modelo que falle esto no es un mal modelo.** Es **un modelo que no se entrenó hacia el
trabajo agéntico**, y **saberlo antes de instalar 20 GB es de lo que se trata**.

## Prepararlo

Un directorio con dos archivos. **Seis filas, tres de ellas mal**:

`invoices.csv`

```csv
row,invoice,customer,amount,po_number,date
1,INV-2201,Northwind,4200,,2026-08-03
2,INV-2202,Contoso,11800,,2026-08-05
3,INV-2203,Fabrikam,900,PO-771,2026-08-09
4,INV-2204,Northwind,15400,PO-772,2026-08-11
5,INV-2205,Contoso,,PO-773,2026-08-12
6,INV-2206,Tailspin,7300,,2026-13-02
```

`rules.md`

```markdown
# Reglas de facturación

- Todo lo que pase de 10.000 necesita número de pedido.
- Toda factura debe llevar importe.
- Las fechas son YYYY-MM-DD y deben ser fechas reales.
```

**Los tres problemas plantados** son la fila 2 (pasa del límite, sin pedido), la fila 5 (sin
importe) y la fila 6 (mes 13). **La fila 4 pasa del límite *y* tiene pedido**: está ahí
**para que un modelo que informe de todos los importes grandes no puntúe como correcto**.

## Ejecutarlo

```shell
opencli exec --skip-git-repo-check --sandbox workspace-write \
  -m <your-model> "Use the spreadsheet-review skill on invoices.csv"
```

## Puntuarlo

| | |
| --- | --- |
| **Llama a herramientas** | ¿Leyó el archivo con una herramienta, o te pidió que pegaras el contenido? |
| **Encontró 3/3** | Las tres, y solo tres. Cuatro significa que se inventó una. |
| **Citó** | Cada hallazgo nombra su fila ***y*** cita la regla que incumple |
| **Contó** | La línea final dice seis filas. Cinco significa que contó de memoria |

**Un modelo que encuentra tres pero no sabe decir qué filas no ha hecho el trabajo**:
**todo el producto de una revisión es un sitio al que mirar**.

## Enviarlo

Abre un pull request añadiendo una fila a la tabla del README, o una incidencia con la
salida pegada. **Incluye**:

- el modelo, **exactamente como lo nombra su runtime** (`qwen3-coder:30b`, no «Qwen»)
- el runtime — Ollama, LM Studio, vLLM, llama.cpp, un endpoint alojado
- la ventana de contexto que configuraste
- cualquier cosa que hiciera y que las cuatro columnas no recojan

**Los resultados negativos valen tanto como los positivos**, y **son más difíciles de
conseguir**: **nadie publica sobre el modelo que no funcionó**. **Una fila que diga que un
modelo no puede llamar a herramientas le ahorra una descarga a todo el que la lea.**
