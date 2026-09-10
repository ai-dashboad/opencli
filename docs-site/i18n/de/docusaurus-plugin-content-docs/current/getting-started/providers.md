---
title: Anbieter
sidebar_position: 4
---

# Woher das Modell kommt

**Das ist keine Liste von Integrationen. Es ist ein Protokoll:** Alles, was auf
`/v1/chat/completions` und `/v1/models` so antwortet wie OpenAI, kann angesprochen
werden, und seine Modelle erscheinen in der Auswahl, **ohne einzeln deklariert zu
werden**.

Die Liste unten ist also nicht „wofür wir Unterstützung gebaut haben“. Sie ist,
**worauf Leute es richten** — und jeder Endpunkt darin **wurde am 2026-09-06 ohne
Schlüssel nach seiner Modellliste gefragt**. Ein `401` ist der Beweis: der Pfad
existiert, er will einen Schlüssel, und er hat die Form der OpenAI-API.

**Auf Ihrem eigenen Rechner**

[Ollama](https://ollama.com) · [LM Studio](https://lmstudio.ai) ·
[llama.cpp](https://github.com/ggml-org/llama.cpp) ·
[LocalAI](https://localai.io) · [Jan](https://jan.ai) ·
[Xinference](https://inference.readthedocs.io) ·
[KoboldCpp](https://github.com/LostRuins/koboldcpp) ·
[llamafile](https://github.com/Mozilla-Ocho/llamafile)

**Auf Ihrem eigenen Server**

[vLLM](https://docs.vllm.ai) · [SGLang](https://docs.sglang.ai) ·
[Text Generation Inference](https://huggingface.co/docs/text-generation-inference) ·
[NVIDIA NIM](https://developer.nvidia.com/nim) ·
[LiteLLM](https://docs.litellm.ai) als Gateway vor jedem von ihnen

**Offene Modelle im Hosting**

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

**In China**

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

**Geschlossene Modelle, wenn Sie eines wollen**

[OpenAI](https://openai.com) · [Anthropic](https://anthropic.com) ·
[Mistral](https://mistral.ai) · [xAI](https://x.ai)

**Ein Modell ist oft auf mehr als einem Weg erreichbar**

Xiaomi und ByteDance **betreiben einen eigenen Endpunkt *und* lassen ihre Modelle von
anderen führen** — was zählt, sobald der eine billiger, schneller oder näher an Ihnen
ist als der andere.

| Modell | Vom Hersteller | Außerdem geführt von |
| --- | --- | --- |
| Xiaomi MiMo | [`api.xiaomimimo.com/v1`](https://mimo.mi.com/docs/zh-CN/api/chat/openai-api) | OpenRouter · Novita · DeepInfra · PPIO · Featherless · Hugging Face |
| Doubao 豆包 | [Volcengine Ark `ark.cn-beijing.volces.com/api/v3`](https://volcengine.com/product/ark) | Qiniu 七牛云 |
| ByteDance Seed | Volcengine Ark | OpenRouter · DeepInfra |

**Die rechte Spalte stammt daher, jeden Anbieter am 2026-09-10 nach seiner Modellliste
gefragt und hineingesehen zu haben.** Die linke stammt aus deren eigener Dokumentation,
bestätigt mit einer Anfrage ohne Schlüssel.

**Dokumentiert, aber hier nicht verifiziert**

[Google Gemini](https://ai.google.dev/gemini-api/docs/openai),
[GitHub Models](https://docs.github.com/github-models) und
[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai) dokumentieren alle
einen OpenAI-kompatiblen Endpunkt, und **keiner der drei ließ sich mit einer Anfrage ohne
Schlüssel bestätigen**. Sie stehen hier statt oben, **damit der Unterschied sichtbar ist**.

**Kostenlose Kontingente**

Mehrere davon geben etwas her — Groq, Cerebras, ModelScope, NVIDIA, die kostenlosen
Modelle von OpenRouter, die Flash-Stufe von 智谱, SiliconFlow, 百度千帆, Google und GitHub
unter ihnen. **Was kostenlos ist, ändert sich von Monat zu Monat und ist nichts, was diese
Datei wahr halten kann**, deshalb werden keine Beträge genannt: sehen Sie auf der Preisseite
des Anbieters nach. **Es ist der billigste Weg, das hier mit einem Modell zu probieren, das
größer ist, als Ihr Rechner es fassen kann.**

Zwei ehrliche Anmerkungen. **Erreichbar zu sein heißt nicht, darin gut zu sein** — dafür ist
die Modelltabelle oben da, und **sie hat eine Zeile, weil ein Modell ausprobiert wurde**. Und
**ein Anbieter, der die OpenAI-API beantwortet, aber ihren Werkzeugaufruf-Teil nicht, wird sich
unterhalten und wenig sonst**.
