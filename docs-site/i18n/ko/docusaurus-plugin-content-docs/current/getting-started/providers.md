---
title: 공급자
sidebar_position: 4
---

# 모델은 어디서 오는가

**이것은 연동 목록이 아닙니다. 하나의 프로토콜입니다.** OpenAI가 하는 방식대로
`/v1/chat/completions` 와 `/v1/models` 에 답하는 것이면 무엇이든 가리킬 수 있고,
그 모델들은 **하나씩 선언하지 않아도** 목록에 나타납니다.

그러니 아래 목록은 「우리가 지원을 만든 곳」이 아니라 **사람들이 실제로 가리키는 곳**입니다 ——
그리고 **여기 있는 모든 엔드포인트는 2026-09-06에 키 없이 모델 목록을 요청받았습니다.**
`401` 이 증거입니다: 경로가 있고, 키를 요구하며, OpenAI API의 모양을 하고 있습니다.

**당신의 기계에서**

[Ollama](https://ollama.com) · [LM Studio](https://lmstudio.ai) ·
[llama.cpp](https://github.com/ggml-org/llama.cpp) ·
[LocalAI](https://localai.io) · [Jan](https://jan.ai) ·
[Xinference](https://inference.readthedocs.io) ·
[KoboldCpp](https://github.com/LostRuins/koboldcpp) ·
[llamafile](https://github.com/Mozilla-Ocho/llamafile)

**당신의 서버에서**

[vLLM](https://docs.vllm.ai) · [SGLang](https://docs.sglang.ai) ·
[Text Generation Inference](https://huggingface.co/docs/text-generation-inference) ·
[NVIDIA NIM](https://developer.nvidia.com/nim) ·
[LiteLLM](https://docs.litellm.ai) (그중 아무 것 앞에 두는 게이트웨이로)

**공개 모델을 호스팅하는 곳**

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

**중국**

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

**닫힌 모델이 필요할 때**

[OpenAI](https://openai.com) · [Anthropic](https://anthropic.com) ·
[Mistral](https://mistral.ai) · [xAI](https://x.ai)

**한 모델에 이르는 길이 하나가 아닐 때가 많습니다**

샤오미와 바이트댄스는 **자기 엔드포인트를 돌리면서 동시에 다른 곳도 그 모델을 실어 나릅니다** ——
한쪽이 더 싸거나 빠르거나 가까울 때 이 사실이 쓸모 있어집니다.

| 모델 | 만든 곳에서 | 이런 곳도 실어 나름 |
| --- | --- | --- |
| Xiaomi MiMo | [`api.xiaomimimo.com/v1`](https://mimo.mi.com/docs/zh-CN/api/chat/openai-api) | OpenRouter · Novita · DeepInfra · PPIO · Featherless · Hugging Face |
| Doubao 豆包 | [Volcengine Ark `ark.cn-beijing.volces.com/api/v3`](https://volcengine.com/product/ark) | Qiniu 七牛云 |
| ByteDance Seed | Volcengine Ark | OpenRouter · DeepInfra |

**오른쪽 열은 2026-09-10에 각 공급자에게 모델 목록을 물어 확인한 것입니다.** 왼쪽 열은 각자의
문서에서 가져와 키 없는 요청으로 확인했습니다.

**문서는 있지만 여기서 확인하지 못한 것**

[Google Gemini](https://ai.google.dev/gemini-api/docs/openai),
[GitHub Models](https://docs.github.com/github-models),
[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai)
는 모두 OpenAI 호환 엔드포인트를 문서화하고 있지만 **셋 다 키 없는 요청으로는 확인되지 않았습니다.**
위가 아니라 여기에 둔 것은 **그 차이를 보이게 하려는 것**입니다.

**무료 사용량**

몇 곳은 뭔가를 그냥 줍니다 —— Groq, Cerebras, ModelScope, NVIDIA, OpenRouter의 무료 모델,
智谱의 Flash 등급, SiliconFlow, 百度千帆, Google, GitHub 같은 곳들입니다.
**무엇이 무료인지는 달마다 바뀌고, 이 파일이 참으로 유지할 수 있는 것이 아니므로** 액수는 적지 않습니다:
각자의 가격 페이지를 보세요. **당신 기계에 올라가지 않을 크기의 모델로 이걸 시험하는 가장 싼 방법입니다.**

솔직한 말 둘. **닿는다는 것과 이 일을 잘한다는 것은 다릅니다** —— 위의 모델 표가 그것을 위한 것이고,
**모델 하나만 돌려 봤기 때문에 줄이 하나뿐입니다.** 그리고
**OpenAI API에는 답하지만 도구 호출 부분에는 답하지 않는 공급자는 대화만 할 뿐입니다.**
