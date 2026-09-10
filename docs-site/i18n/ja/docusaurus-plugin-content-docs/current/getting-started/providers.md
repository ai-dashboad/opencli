---
title: 供給元
sidebar_position: 4
---

# モデルはどこから来るか

**これは統合の一覧ではありません。一つのプロトコルです。** OpenAI と同じように
`/v1/chat/completions` と `/v1/models` に答えるものなら何でも指定でき、
そのモデルは**一つずつ宣言しなくても**選択リストに現れます。

ですから下の一覧は「我々が対応を作った先」ではなく、**人々が実際に指定している先**です ——
そして**この中のどのエンドポイントも、2026-09-06 に鍵なしでモデル一覧を訊いています**。
`401` がその証拠です:パスが存在し、鍵を求め、そして OpenAI API の形をしている。

**自分のマシンで**

[Ollama](https://ollama.com) · [LM Studio](https://lmstudio.ai) ·
[llama.cpp](https://github.com/ggml-org/llama.cpp) ·
[LocalAI](https://localai.io) · [Jan](https://jan.ai) ·
[Xinference](https://inference.readthedocs.io) ·
[KoboldCpp](https://github.com/LostRuins/koboldcpp) ·
[llamafile](https://github.com/Mozilla-Ocho/llamafile)

**自分のサーバーで**

[vLLM](https://docs.vllm.ai) · [SGLang](https://docs.sglang.ai) ·
[Text Generation Inference](https://huggingface.co/docs/text-generation-inference) ·
[NVIDIA NIM](https://developer.nvidia.com/nim) ·
[LiteLLM](https://docs.litellm.ai) (そのどれかの前に置くゲートウェイとして)

**オープンモデルをホストしている**

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

**中国国内**

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

**クローズドなモデルが要るとき**

[OpenAI](https://openai.com) · [Anthropic](https://anthropic.com) ·
[Mistral](https://mistral.ai) · [xAI](https://x.ai)

**同じモデルに複数の経路があることは珍しくありません**

小米と字節跳動は**自前のエンドポイントを持ちつつ、他社にもモデルを載せてもらっています** ——
片方がもう片方より安い、速い、あるいは近いとき、これが効いてきます。

| モデル | 作った会社から | 他にも載せている |
| --- | --- | --- |
| Xiaomi MiMo | [`api.xiaomimimo.com/v1`](https://mimo.mi.com/docs/zh-CN/api/chat/openai-api) | OpenRouter · Novita · DeepInfra · PPIO · Featherless · Hugging Face |
| Doubao 豆包 | [Volcengine Ark `ark.cn-beijing.volces.com/api/v3`](https://volcengine.com/product/ark) | Qiniu 七牛云 |
| ByteDance Seed | Volcengine Ark | OpenRouter · DeepInfra |

**右の列は 2026-09-10 に各社へモデル一覧を訊いて見たものです。** 左の列は各社自身の文書から取り、
鍵なしのリクエストで確認しました。

**文書はあるが、ここでは未確認**

[Google Gemini](https://ai.google.dev/gemini-api/docs/openai)、
[GitHub Models](https://docs.github.com/github-models)、
[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai)
はいずれも OpenAI 互換エンドポイントを文書化していますが、**どれも鍵なしのリクエストでは確認できませんでした**。
上ではなくここに置いてあるのは、**その違いを見えるようにするため**です。

**無料枠**

いくつかは無料で出しています —— Groq、Cerebras、ModelScope、NVIDIA、OpenRouter の無料モデル、
智谱の Flash 帯、SiliconFlow、百度千帆、Google、GitHub などです。
**何が無料かは月ごとに変わり、このファイルが真実に保てるものではない**ので、金額は書きません:
各社の価格ページを見てください。**自分のマシンに載らない大きさのモデルでこれを試す、一番安い方法です。**

正直な話が二つ。**届くことと、これが得意なことは同じではありません** —— 上のモデル表がそのためにあり、
そして**一つのモデルしか走らせていないので一行しかありません**。それから、
**OpenAI API には答えるがツール呼び出しの部分には答えない供給元は、話をするだけ**です。
