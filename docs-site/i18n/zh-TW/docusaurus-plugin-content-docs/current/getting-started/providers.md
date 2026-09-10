---
title: 供應商
sidebar_position: 4
---

# 模型從哪來

**這不是一張集成清單。它是一個協議**:凡是能按 OpenAI 那樣回答
`/v1/chat/completions` 和 `/v1/models` 的,都可以指過去,它的模型會出現在選擇器裡,
**不用一個一個聲明**。

所以下面這張表不是「我們為誰做了支援」,而是**人們把它指向哪裡** —— 而且裡面的每一個
端點,都在 2026-09-06 被**不帶金鑰地問過一次模型清單**。`401` 就是證據:路徑存在、
它要金鑰、並且它長得像 OpenAI API。

**在你自己的機器上**

[Ollama](https://ollama.com) · [LM Studio](https://lmstudio.ai) ·
[llama.cpp](https://github.com/ggml-org/llama.cpp) ·
[LocalAI](https://localai.io) · [Jan](https://jan.ai) ·
[Xinference](https://inference.readthedocs.io) ·
[KoboldCpp](https://github.com/LostRuins/koboldcpp) ·
[llamafile](https://github.com/Mozilla-Ocho/llamafile)

**在你自己的伺服器上**

[vLLM](https://docs.vllm.ai) · [SGLang](https://docs.sglang.ai) ·
[Text Generation Inference](https://huggingface.co/docs/text-generation-inference) ·
[NVIDIA NIM](https://developer.nvidia.com/nim) ·
[LiteLLM](https://docs.litellm.ai)(作為上面任意一個前面的網關)

**托管開源模型的**

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

**國內**

[硅基流動 SiliconFlow](https://siliconflow.cn) ·
[無問芯穹 Infinigence](https://cloud.infini-ai.com) ·
[PPIO 派歐雲](https://ppinfra.com) · [七牛雲 Qiniu](https://qiniu.com) ·
[魔搭 ModelScope](https://modelscope.cn) ·
[阿里雲百煉 DashScope](https://bailian.console.aliyun.com) ·
[火山方舟 Volcengine · 豆包](https://volcengine.com/product/ark) ·
[百度千帆 Qianfan](https://cloud.baidu.com/product/wenxinworkshop) ·
[訊飛星火 iFlytek](https://xinghuo.xfyun.cn) ·
[DeepSeek](https://deepseek.com) · [智譜 Zhipu](https://bigmodel.cn) ·
[月之暗面 Moonshot](https://moonshot.cn) · [MiniMax](https://minimax.io) ·
[階躍星辰 StepFun](https://stepfun.com) · [騰訊混元 Hunyuan](https://cloud.tencent.com/product/hunyuan) ·
[百川智慧 Baichuan](https://baichuan-ai.com) ·
[小米 MiMo](https://mimo.mi.com)

**閉源模型,想用的時候**

[OpenAI](https://openai.com) · [Anthropic](https://anthropic.com) ·
[Mistral](https://mistral.ai) · [xAI](https://x.ai)

**同一個模型常常不止一條路**

小米和字節**既自己跑一個端點,也有別家在承載它們的模型** ——
當其中一條更便宜、更快、或者離你更近的時候,這件事就有用了。

| 模型 | 出自它自己 | 也由這些承載 |
| --- | --- | --- |
| 小米 MiMo | [`api.xiaomimimo.com/v1`](https://mimo.mi.com/docs/zh-CN/api/chat/openai-api) | OpenRouter · Novita · DeepInfra · PPIO · Featherless · Hugging Face |
| 豆包 | [火山方舟 `ark.cn-beijing.volces.com/api/v3`](https://volcengine.com/product/ark) | 七牛雲 |
| 字節 Seed | 火山方舟 | OpenRouter · DeepInfra |

**右邊那欄是 2026-09-10 逐家問了模型清單看出來的。** 左邊那欄來自它們自己的文檔,
並用一次不帶金鑰的請求確認過。

**有文檔,但這裡沒驗證過**

[Google Gemini](https://ai.google.dev/gemini-api/docs/openai)、
[GitHub Models](https://docs.github.com/github-models)、
[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai)
都寫了 OpenAI 兼容端點,**而三家都沒能用不帶金鑰的請求確認**。它們列在這裡而不是上面,
**就是為了讓這個差別看得見**。

**免費額度**

其中有幾家是給東西的 —— Groq、Cerebras、魔搭、NVIDIA、OpenRouter 的免費模型、
智譜的 Flash 檔、硅基流動、百度千帆、Google 和 GitHub 都在其中。
**免費的是什麼,月月在變,不是這個文件能保持真實的東西**,所以這裡不寫數額:
去看供應商自己的價格頁。**這是用一個比你機器裝得下更大的模型來試它的最便宜的辦法。**

兩句老實話。**能連上不等於擅長這個** —— 上面那張模型表就是幹這個的,而它只有一行,
因為只跑過一個模型。以及,**一家答 OpenAI API 卻不答它的工具調用部分的供應商,
能聊天,別的就不太行了。**
