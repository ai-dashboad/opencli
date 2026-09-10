---
title: Поставщики
sidebar_position: 4
---

# Откуда берётся модель

**Это не список интеграций. Это один протокол:** всё, что отвечает на
`/v1/chat/completions` и `/v1/models` так же, как OpenAI, можно указать, и его модели
появляются в списке выбора **без того, чтобы объявлять их по одной**.

Поэтому список ниже — не «для кого мы написали поддержку». Это **то, на что люди
указывают** — и у каждой точки доступа в нём **2026-09-06 без ключа запросили список
моделей**. `401` и есть доказательство: путь существует, он требует ключ и по форме
это OpenAI API.

**На вашей машине**

[Ollama](https://ollama.com) · [LM Studio](https://lmstudio.ai) ·
[llama.cpp](https://github.com/ggml-org/llama.cpp) ·
[LocalAI](https://localai.io) · [Jan](https://jan.ai) ·
[Xinference](https://inference.readthedocs.io) ·
[KoboldCpp](https://github.com/LostRuins/koboldcpp) ·
[llamafile](https://github.com/Mozilla-Ocho/llamafile)

**На вашем сервере**

[vLLM](https://docs.vllm.ai) · [SGLang](https://docs.sglang.ai) ·
[Text Generation Inference](https://huggingface.co/docs/text-generation-inference) ·
[NVIDIA NIM](https://developer.nvidia.com/nim) ·
[LiteLLM](https://docs.litellm.ai) как шлюз перед любым из перечисленного

**Хостинг открытых моделей**

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

**В Китае**

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

**Закрытые модели, когда нужна одна из них**

[OpenAI](https://openai.com) · [Anthropic](https://anthropic.com) ·
[Mistral](https://mistral.ai) · [xAI](https://x.ai)

**До модели часто ведёт больше одного пути**

Xiaomi и ByteDance **держат собственную точку доступа *и* при этом их модели раздают
другие** — это важно, когда один путь дешевле, быстрее или ближе к вам, чем другой.

| Модель | От создателя | Также раздают |
| --- | --- | --- |
| Xiaomi MiMo | [`api.xiaomimimo.com/v1`](https://mimo.mi.com/docs/zh-CN/api/chat/openai-api) | OpenRouter · Novita · DeepInfra · PPIO · Featherless · Hugging Face |
| Doubao 豆包 | [Volcengine Ark `ark.cn-beijing.volces.com/api/v3`](https://volcengine.com/product/ark) | Qiniu 七牛云 |
| ByteDance Seed | Volcengine Ark | OpenRouter · DeepInfra |

**Правый столбец получен запросом списка моделей у каждого поставщика 2026-09-10.**
Левый взят из их собственной документации и подтверждён запросом без ключа.

**Задокументировано, но здесь не проверено**

[Google Gemini](https://ai.google.dev/gemini-api/docs/openai),
[GitHub Models](https://docs.github.com/github-models) и
[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai) — все трое описывают
OpenAI-совместимую точку доступа, и **ни одного не удалось подтвердить запросом без ключа**.
Они здесь, а не выше, **чтобы эта разница была видна**.

**Бесплатные квоты**

Некоторые из них что-то отдают даром — Groq, Cerebras, ModelScope, NVIDIA, бесплатные модели
OpenRouter, уровень Flash у 智谱, SiliconFlow, 百度千帆, Google и GitHub среди них.
**Что именно бесплатно, меняется от месяца к месяцу, и этот файл не в состоянии удерживать это
в истинном виде**, поэтому суммы здесь не названы: смотрите страницу цен самого поставщика.
**Это самый дешёвый способ попробовать всё это с моделью крупнее, чем поместилась бы у вас.**

Две честные оговорки. **Быть доступным — не то же самое, что быть в этом хорошим**: для этого
есть таблица моделей выше, и **в ней одна строка, потому что запускали одну модель**. И
**поставщик, который отвечает на OpenAI API, но не на его часть с вызовом инструментов, будет
разговаривать — и почти ничего больше**.
