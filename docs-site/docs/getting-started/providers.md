---
title: Providers
sidebar_position: 4
---

# Where the model comes from

This is not a list of integrations. It is one protocol: anything that answers
`/v1/chat/completions` and `/v1/models` the way OpenAI does can be pointed at,
and its models appear in the picker without being declared one by one.

So the list below is not "what we built support for". It is where people point
it — and every endpoint in it was asked for its model list, without a key, on
2026-09-06. A `401` is the proof: the path exists, it wants a key, and it is
shaped like the OpenAI API.

**On your own machine**

[Ollama](https://ollama.com) · [LM Studio](https://lmstudio.ai) ·
[llama.cpp](https://github.com/ggml-org/llama.cpp) ·
[LocalAI](https://localai.io) · [Jan](https://jan.ai) ·
[Xinference](https://inference.readthedocs.io) ·
[KoboldCpp](https://github.com/LostRuins/koboldcpp) ·
[llamafile](https://github.com/Mozilla-Ocho/llamafile)

**On your own server**

[vLLM](https://docs.vllm.ai) · [SGLang](https://docs.sglang.ai) ·
[Text Generation Inference](https://huggingface.co/docs/text-generation-inference) ·
[NVIDIA NIM](https://developer.nvidia.com/nim) ·
[LiteLLM](https://docs.litellm.ai) as a gateway in front of any of them

**Hosting open models**

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

[硅基流动 SiliconFlow](https://siliconflow.cn) ·
[无问芯穹 Infinigence](https://cloud.infini-ai.com) ·
[PPIO 派欧云](https://ppinfra.com) · [七牛云 Qiniu](https://qiniu.com) ·
[魔搭 ModelScope](https://modelscope.cn) ·
[阿里云百炼 DashScope](https://bailian.console.aliyun.com) ·
[火山方舟 Volcengine · 豆包](https://volcengine.com/product/ark) ·
[百度千帆 Qianfan](https://cloud.baidu.com/product/wenxinworkshop) ·
[讯飞星火 iFlytek](https://xinghuo.xfyun.cn) ·
[DeepSeek](https://deepseek.com) · [智谱 Zhipu](https://bigmodel.cn) ·
[月之暗面 Moonshot](https://moonshot.cn) · [MiniMax](https://minimax.io) ·
[阶跃星辰 StepFun](https://stepfun.com) · [腾讯混元 Hunyuan](https://cloud.tencent.com/product/hunyuan) ·
[百川智能 Baichuan](https://baichuan-ai.com) ·
[小米 MiMo](https://mimo.mi.com)

**Closed models, when you want one**

[OpenAI](https://openai.com) · [Anthropic](https://anthropic.com) ·
[Mistral](https://mistral.ai) · [xAI](https://x.ai)

**A model can often be reached more than one way**

Xiaomi and ByteDance both run their own endpoint *and* have their models
carried by others, which matters when one is cheaper, faster or closer to you
than the other.

| Model | From its maker | Also carried by |
| --- | --- | --- |
| Xiaomi MiMo | [`api.xiaomimimo.com/v1`](https://mimo.mi.com/docs/zh-CN/api/chat/openai-api) | OpenRouter · Novita · DeepInfra · PPIO · Featherless · Hugging Face |
| Doubao 豆包 | [火山方舟 `ark.cn-beijing.volces.com/api/v3`](https://volcengine.com/product/ark) | 七牛云 |
| ByteDance Seed | 火山方舟 | OpenRouter · DeepInfra |

The right-hand column comes from asking each provider for its model list and
looking, on 2026-09-10. The left-hand one comes from their own documentation,
confirmed with a keyless request.

**Documented, but not verified here**

[Google Gemini](https://ai.google.dev/gemini-api/docs/openai),
[GitHub Models](https://docs.github.com/github-models) and
[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai) all
document an OpenAI-compatible endpoint, and none of them could be confirmed
with a keyless request. They are listed here rather than above so the
difference is visible.

**Free allowances**

Several of these give something away — Groq, Cerebras, ModelScope, NVIDIA,
OpenRouter's free models, 智谱's Flash tier, SiliconFlow, 百度千帆, Google and
GitHub among them. What is free changes month to month and is not something
this file can keep true, so no amounts are quoted: check the provider's own
pricing page. It is the cheapest way to try this with a model larger than
your machine can hold.

Two honest notes. Being reachable is not the same as being good at this — that
is what the model table above is for, and it has one row because one model has
been run. And a provider that answers the OpenAI API but not its tool-calling
part will chat and not much else.

