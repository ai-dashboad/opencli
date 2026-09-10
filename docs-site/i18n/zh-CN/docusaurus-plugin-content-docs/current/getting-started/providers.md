---
title: 供应商
sidebar_position: 4
---

# 模型从哪来

**这不是一张集成清单。它是一个协议**:凡是能按 OpenAI 那样回答
`/v1/chat/completions` 和 `/v1/models` 的,都可以指过去,它的模型会出现在选择器里,
**不用一个一个声明**。

所以下面这张表不是「我们为谁做了支持」,而是**人们把它指向哪里** —— 而且里面的每一个
端点,都在 2026-09-06 被**不带密钥地问过一次模型列表**。`401` 就是证据:路径存在、
它要密钥、并且它长得像 OpenAI API。

**在你自己的机器上**

[Ollama](https://ollama.com) · [LM Studio](https://lmstudio.ai) ·
[llama.cpp](https://github.com/ggml-org/llama.cpp) ·
[LocalAI](https://localai.io) · [Jan](https://jan.ai) ·
[Xinference](https://inference.readthedocs.io) ·
[KoboldCpp](https://github.com/LostRuins/koboldcpp) ·
[llamafile](https://github.com/Mozilla-Ocho/llamafile)

**在你自己的服务器上**

[vLLM](https://docs.vllm.ai) · [SGLang](https://docs.sglang.ai) ·
[Text Generation Inference](https://huggingface.co/docs/text-generation-inference) ·
[NVIDIA NIM](https://developer.nvidia.com/nim) ·
[LiteLLM](https://docs.litellm.ai)(作为上面任意一个前面的网关)

**托管开源模型的**

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

**国内**

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

**闭源模型,想用的时候**

[OpenAI](https://openai.com) · [Anthropic](https://anthropic.com) ·
[Mistral](https://mistral.ai) · [xAI](https://x.ai)

**同一个模型常常不止一条路**

小米和字节**既自己跑一个端点,也有别家在承载它们的模型** ——
当其中一条更便宜、更快、或者离你更近的时候,这件事就有用了。

| 模型 | 出自它自己 | 也由这些承载 |
| --- | --- | --- |
| 小米 MiMo | [`api.xiaomimimo.com/v1`](https://mimo.mi.com/docs/zh-CN/api/chat/openai-api) | OpenRouter · Novita · DeepInfra · PPIO · Featherless · Hugging Face |
| 豆包 | [火山方舟 `ark.cn-beijing.volces.com/api/v3`](https://volcengine.com/product/ark) | 七牛云 |
| 字节 Seed | 火山方舟 | OpenRouter · DeepInfra |

**右边那栏是 2026-09-10 逐家问了模型列表看出来的。** 左边那栏来自它们自己的文档,
并用一次不带密钥的请求确认过。

**有文档,但这里没验证过**

[Google Gemini](https://ai.google.dev/gemini-api/docs/openai)、
[GitHub Models](https://docs.github.com/github-models)、
[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai)
都写了 OpenAI 兼容端点,**而三家都没能用不带密钥的请求确认**。它们列在这里而不是上面,
**就是为了让这个差别看得见**。

**免费额度**

其中有几家是给东西的 —— Groq、Cerebras、魔搭、NVIDIA、OpenRouter 的免费模型、
智谱的 Flash 档、硅基流动、百度千帆、Google 和 GitHub 都在其中。
**免费的是什么,月月在变,不是这个文件能保持真实的东西**,所以这里不写数额:
去看供应商自己的价格页。**这是用一个比你机器装得下更大的模型来试它的最便宜的办法。**

两句老实话。**能连上不等于擅长这个** —— 上面那张模型表就是干这个的,而它只有一行,
因为只跑过一个模型。以及,**一家答 OpenAI API 却不答它的工具调用部分的供应商,
能聊天,别的就不太行了。**
