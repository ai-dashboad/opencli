---
title: Preguntas frecuentes
sidebar_position: 1
---

# Preguntas que la gente hace de verdad

## ¿Se envían mis datos a algún sitio?

**Al endpoint que hayas configurado, y a ningún otro sitio.** **No hay ninguna
pasarela nuestra en medio**, ni cuenta de telemetría, ni **clave alguna metida
dentro del binario**.

Si ese endpoint es un modelo de tu propia máquina, **no sale nada de la máquina**.

## ¿Funciona sin conexión?

**Sí, con un modelo local.** La aplicación de escritorio busca sus propias
actualizaciones y el panel Models descarga una lista de modelos populares —
**ambas fallan en silencio sin red y ninguna hace falta para mantener una
conversación**.

## ¿Necesito una clave de API?

**No, si ejecutas un modelo en local.** Ollama, LM Studio, llama.cpp y los demás
no piden nada. Un proveedor alojado necesita su clave, que **se guarda aparte del
archivo de configuración y no se vuelve a mostrar**.

## ¿Qué modelo debería usar?

**El que quepa en tu máquina**, con **un requisito innegociable: tiene que llamar
a herramientas.** Un modelo que no lo haga **queda limitado a conversar** aquí.

[Comprobar un modelo](/reference/checking-a-model) es una **prueba de cinco
minutos** que responde a esto. La tabla que hay allí es corta porque **solo
contiene lo que se ha ejecutado**.

## ¿Por qué es peor que Claude Code / Codex?

**Porque un modelo de 27B cuantizado para caber en un portátil no es GPT-5.** La
interfaz es la misma; **el razonamiento no**.

**Lo que este proyecto cambia es el alcance** —si el modelo que tienes puede
usarse así siquiera— **no lo listo que es**.

## ¿Puede usar GPT-5 o Claude?

**Sí.** Configura OpenAI o Anthropic como cualquier otro proveedor. **Nada en el
producto prefiere a uno sobre otro.**

## ¿Dónde empieza una conversación?

En `~/.opencli/workspace`, salvo que pertenezca a un departamento, en cuyo caso
empieza en el directorio de ese departamento.

**Antes era tu carpeta personal. Ya no lo es**, porque la raíz escribible del
sandbox **es** el directorio de trabajo — ver
[Sandbox y aprobaciones](/configuration/sandbox-and-approvals).

## ¿Pueden usar varias personas una sola instalación?

**No.** La pasarela es **de un solo usuario por diseño** y **lo dice en su propio
código**. **Cada persona ejecuta su copia**; lo normal es tener detrás **un
servidor de modelos compartido**.

## ¿El trabajo programado se ejecuta con el portátil dormido?

**No.** Las tareas programadas y los turnos se ejecutan **solo mientras OpenCLI
está abierto**, porque **esto es un agente local, no un servidor**. Todo lo que
deba dispararse con la máquina dormida corresponde a `cron`, `launchd` o al
Programador de tareas.

## ¿En qué se diferencia de Open WebUI o Jan?

**Esos son interfaces de chat para modelos locales, y buenos.** **Esto es un
agente**: lee y edita tus archivos, ejecuta comandos y **sigue trabajando en
segundo plano**. **Es otro trabajo, y no hay razón para no usar ambos.**

## ¿En qué se diferencia de Codex, del que se bifurcó?

**Codex está hecho para los modelos de OpenAI.** Los departamentos, los bots, los
turnos, las ejecuciones en segundo plano, los traspasos entre bots, los flujos
incluidos y los diez idiomas de la interfaz **vienen de este lado de la
bifurcación**, junto con **bastante trabajo sobre qué se rompe cuando el modelo
es pequeño**.

## ¿Por qué dice que la app está dañada o no verificada?

**Porque las compilaciones no llevan certificado de Apple ni de Microsoft** —esos
**cuestan dinero cada año y este proyecto no lo ha gastado**.
[Instalación](/getting-started/install) dice exactamente qué hay que pulsar.

## ¿Puedo cambiar cómo se llama?

**Todavía no.** La marca está compilada dentro.

## Algo no funciona. ¿Dónde miro?

[Solución de problemas](/help/troubleshooting), luego los registros de
`~/.opencli/log`, y luego
[una incidencia](https://github.com/ai-dashboad/opencli/issues).
