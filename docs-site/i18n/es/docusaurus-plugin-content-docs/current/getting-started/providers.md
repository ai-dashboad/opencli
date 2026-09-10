---
title: Proveedores
sidebar_position: 4
---

# De dónde viene el modelo

**Esto no es una lista de integraciones. Es un solo protocolo:** cualquier cosa
que responda a `/v1/chat/completions` y `/v1/models` como lo hace OpenAI puede
recibir la conexión, y sus modelos aparecen en el selector **sin declararlos uno
a uno**.

Así que la lista de abajo no es «para qué construimos soporte». Es **dónde apunta
la gente** — y a cada endpoint que aparece **se le pidió su lista de modelos, sin
clave, el 2026-09-06**. Un `401` es la prueba: la ruta existe, quiere una clave y
tiene la forma de la API de OpenAI.

**En tu propia máquina**

[Ollama](https://ollama.com) · [LM Studio](https://lmstudio.ai) ·
[llama.cpp](https://github.com/ggml-org/llama.cpp) ·
[LocalAI](https://localai.io) · [Jan](https://jan.ai) ·
[Xinference](https://inference.readthedocs.io) ·
[KoboldCpp](https://github.com/LostRuins/koboldcpp) ·
[llamafile](https://github.com/Mozilla-Ocho/llamafile)

**En tu propio servidor**

[vLLM](https://docs.vllm.ai) · [SGLang](https://docs.sglang.ai) ·
[Text Generation Inference](https://huggingface.co/docs/text-generation-inference) ·
[NVIDIA NIM](https://developer.nvidia.com/nim) ·
[LiteLLM](https://docs.litellm.ai) como pasarela por delante de cualquiera de ellos

**Alojando modelos abiertos**

[Fireworks AI](https://fireworks.ai) · [Together AI](https://together.ai) ·
[Groq](https://groq.com) · [DeepInfra](https://deepinfra.com) ·
[Baseten](https://baseten.co) · [Novita AI](https://novita.ai) ·
[Hyperbolic](https://hyperbolic.xyz) · [Nebius AI Studio](https://studio.nebius.com) ·
[Cerebras](https://cerebras.ai) · [SambaNova](https://sambanova.ai) ·
[Featherless](https://featherless.ai) · [Chutes](https://chutes.ai) ·
[NVIDIA NIM](https://build.nvidia.com) ·
[Hugging Face Inference](https://huggingface.co/docs/inference-providers) ·
[OpenRouter](https://openrouter.ai) · [Vercel AI Gateway](https://vercel.com/docs/ai-gateway) ·
[Perplexity](https://docs.perplexity.ai)

**En China**

[SiliconFlow 硅基流动](https://siliconflow.cn) ·
[Infinigence 无问芯穹](https://cloud.infini-ai.com) ·
[PPIO 派欧云](https://ppinfra.com) · [Qiniu 七牛云](https://qiniu.com) ·
[ModelScope 魔搭](https://modelscope.cn) ·
[Alibaba DashScope 阿里云百炼](https://bailian.console.aliyun.com) ·
[Volcengine Ark 火山方舟 · Doubao 豆包](https://volcengine.com/product/ark) ·
[Baidu Qianfan 百度千帆](https://cloud.baidu.com/product/wenxinworkshop) ·
[iFlytek Spark 讯飞星火](https://xinghuo.xfyun.cn) ·
[DeepSeek](https://deepseek.com) · [Zhipu 智谱](https://bigmodel.cn) ·
[Moonshot 月之暗面](https://moonshot.cn) · [MiniMax](https://minimax.io) ·
[StepFun 阶跃星辰](https://stepfun.com) ·
[Tencent Hunyuan 腾讯混元](https://cloud.tencent.com/product/hunyuan) ·
[Baichuan 百川智能](https://baichuan-ai.com) ·
[Xiaomi MiMo 小米](https://mimo.mi.com)

**Modelos cerrados, cuando quieras uno**

[OpenAI](https://openai.com) · [Anthropic](https://anthropic.com) ·
[Mistral](https://mistral.ai) · [xAI](https://x.ai)

**A un modelo se llega a menudo por más de un camino**

Xiaomi y ByteDance **mantienen su propio endpoint *y* tienen sus modelos
distribuidos por terceros**, lo cual importa cuando uno es más barato, más rápido
o está más cerca de ti que el otro.

| Modelo | De quien lo hizo | También distribuido por |
| --- | --- | --- |
| Xiaomi MiMo | [`api.xiaomimimo.com/v1`](https://mimo.mi.com/docs/zh-CN/api/chat/openai-api) | OpenRouter · Novita · DeepInfra · PPIO · Featherless · Hugging Face |
| Doubao 豆包 | [Volcengine Ark `ark.cn-beijing.volces.com/api/v3`](https://volcengine.com/product/ark) | Qiniu 七牛云 |
| ByteDance Seed | Volcengine Ark | OpenRouter · DeepInfra |

**La columna de la derecha sale de pedirle a cada proveedor su lista de modelos y
mirarla, el 2026-09-10.** La de la izquierda sale de su propia documentación,
confirmada con una petición sin clave.

**Documentado, pero no verificado aquí**

[Google Gemini](https://ai.google.dev/gemini-api/docs/openai),
[GitHub Models](https://docs.github.com/github-models) y
[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai) documentan
un endpoint compatible con OpenAI, y **ninguno de los tres pudo confirmarse con una
petición sin clave**. Están aquí y no arriba **para que la diferencia se vea**.

**Cuotas gratuitas**

Varios de estos regalan algo — Groq, Cerebras, ModelScope, NVIDIA, los modelos
gratuitos de OpenRouter, el nivel Flash de 智谱, SiliconFlow, 百度千帆, Google y
GitHub entre ellos. **Lo que es gratis cambia de mes a mes y no es algo que este
archivo pueda mantener cierto**, así que no se citan cantidades: consulta la página
de precios del proveedor. **Es la forma más barata de probar esto con un modelo más
grande de lo que tu máquina puede alojar.**

Dos apuntes honestos. **Ser alcanzable no es lo mismo que ser bueno en esto** — para
eso está la tabla de modelos de arriba, y **tiene una fila porque se ha ejecutado un
modelo**. Y **un proveedor que responde a la API de OpenAI pero no a su parte de
llamada a herramientas conversará y poco más**.
