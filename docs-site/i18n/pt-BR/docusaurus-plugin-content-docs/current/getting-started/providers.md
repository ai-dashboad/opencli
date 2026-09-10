---
title: Provedores
sidebar_position: 4
---

# De onde vem o modelo

**Isto não é uma lista de integrações. É um protocolo só:** qualquer coisa que
responda a `/v1/chat/completions` e `/v1/models` do jeito que a OpenAI responde
pode ser apontada, e os modelos dela aparecem no seletor **sem serem declarados um
a um**.

Então a lista abaixo não é «para quem construímos suporte». É **para onde as pessoas
apontam** — e a cada endpoint dela **foi pedida a lista de modelos, sem chave, em
2026-09-06**. Um `401` é a prova: o caminho existe, ele quer uma chave e tem o
formato da API da OpenAI.

**Na sua própria máquina**

[Ollama](https://ollama.com) · [LM Studio](https://lmstudio.ai) ·
[llama.cpp](https://github.com/ggml-org/llama.cpp) ·
[LocalAI](https://localai.io) · [Jan](https://jan.ai) ·
[Xinference](https://inference.readthedocs.io) ·
[KoboldCpp](https://github.com/LostRuins/koboldcpp) ·
[llamafile](https://github.com/Mozilla-Ocho/llamafile)

**No seu próprio servidor**

[vLLM](https://docs.vllm.ai) · [SGLang](https://docs.sglang.ai) ·
[Text Generation Inference](https://huggingface.co/docs/text-generation-inference) ·
[NVIDIA NIM](https://developer.nvidia.com/nim) ·
[LiteLLM](https://docs.litellm.ai) como gateway na frente de qualquer um deles

**Hospedando modelos abertos**

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

**Na China**

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

**Modelos fechados, quando você quiser um**

[OpenAI](https://openai.com) · [Anthropic](https://anthropic.com) ·
[Mistral](https://mistral.ai) · [xAI](https://x.ai)

**Muitas vezes dá para chegar a um modelo por mais de um caminho**

A Xiaomi e a ByteDance **mantêm o próprio endpoint *e* têm seus modelos carregados
por terceiros**, o que importa quando um é mais barato, mais rápido ou mais perto de
você do que o outro.

| Modelo | De quem o fez | Também carregado por |
| --- | --- | --- |
| Xiaomi MiMo | [`api.xiaomimimo.com/v1`](https://mimo.mi.com/docs/zh-CN/api/chat/openai-api) | OpenRouter · Novita · DeepInfra · PPIO · Featherless · Hugging Face |
| Doubao 豆包 | [Volcengine Ark `ark.cn-beijing.volces.com/api/v3`](https://volcengine.com/product/ark) | Qiniu 七牛云 |
| ByteDance Seed | Volcengine Ark | OpenRouter · DeepInfra |

**A coluna da direita vem de pedir a lista de modelos a cada provedor e olhar, em
2026-09-10.** A da esquerda vem da documentação deles, confirmada com uma requisição
sem chave.

**Documentado, mas não verificado aqui**

[Google Gemini](https://ai.google.dev/gemini-api/docs/openai),
[GitHub Models](https://docs.github.com/github-models) e
[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai) documentam um
endpoint compatível com a OpenAI, e **nenhum dos três pôde ser confirmado com uma
requisição sem chave**. Estão aqui e não acima **para que a diferença fique visível**.

**Cotas gratuitas**

Vários deles dão alguma coisa — Groq, Cerebras, ModelScope, NVIDIA, os modelos
gratuitos da OpenRouter, o nível Flash da 智谱, SiliconFlow, 百度千帆, Google e GitHub
entre eles. **O que é gratuito muda de mês para mês e não é algo que este arquivo
consiga manter verdadeiro**, então nenhum valor é citado: veja a página de preços do
provedor. **É o jeito mais barato de experimentar isto com um modelo maior do que a
sua máquina aguenta.**

Duas observações honestas. **Ser alcançável não é a mesma coisa que ser bom nisto** —
é para isso que serve a tabela de modelos acima, e **ela tem uma linha porque um modelo
foi executado**. E **um provedor que responde à API da OpenAI mas não à parte de
chamada de ferramentas vai conversar e pouco mais**.
