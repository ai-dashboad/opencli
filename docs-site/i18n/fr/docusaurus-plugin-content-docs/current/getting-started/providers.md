---
title: Fournisseurs
sidebar_position: 4
---

# D'où vient le modèle

**Ce n'est pas une liste d'intégrations. C'est un seul protocole :** tout ce qui
répond à `/v1/chat/completions` et `/v1/models` comme le fait OpenAI peut être visé,
et ses modèles apparaissent dans le sélecteur **sans être déclarés un par un**.

La liste ci-dessous n'est donc pas « ce pour quoi nous avons écrit du support ».
C'est **là où les gens le pointent** — et chaque endpoint qui y figure **s'est vu
demander sa liste de modèles, sans clé, le 2026-09-06**. Un `401` en est la preuve :
le chemin existe, il veut une clé, et il a la forme de l'API OpenAI.

**Sur votre propre machine**

[Ollama](https://ollama.com) · [LM Studio](https://lmstudio.ai) ·
[llama.cpp](https://github.com/ggml-org/llama.cpp) ·
[LocalAI](https://localai.io) · [Jan](https://jan.ai) ·
[Xinference](https://inference.readthedocs.io) ·
[KoboldCpp](https://github.com/LostRuins/koboldcpp) ·
[llamafile](https://github.com/Mozilla-Ocho/llamafile)

**Sur votre propre serveur**

[vLLM](https://docs.vllm.ai) · [SGLang](https://docs.sglang.ai) ·
[Text Generation Inference](https://huggingface.co/docs/text-generation-inference) ·
[NVIDIA NIM](https://developer.nvidia.com/nim) ·
[LiteLLM](https://docs.litellm.ai) comme passerelle devant n'importe lequel d'entre eux

**Hébergeant des modèles ouverts**

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

**En Chine**

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

**Modèles fermés, quand vous en voulez un**

[OpenAI](https://openai.com) · [Anthropic](https://anthropic.com) ·
[Mistral](https://mistral.ai) · [xAI](https://x.ai)

**On peut souvent atteindre un modèle par plus d'un chemin**

Xiaomi et ByteDance **exploitent leur propre endpoint *et* voient leurs modèles portés
par d'autres**, ce qui compte quand l'un est moins cher, plus rapide ou plus proche de
vous que l'autre.

| Modèle | De son créateur | Également porté par |
| --- | --- | --- |
| Xiaomi MiMo | [`api.xiaomimimo.com/v1`](https://mimo.mi.com/docs/zh-CN/api/chat/openai-api) | OpenRouter · Novita · DeepInfra · PPIO · Featherless · Hugging Face |
| Doubao 豆包 | [Volcengine Ark `ark.cn-beijing.volces.com/api/v3`](https://volcengine.com/product/ark) | Qiniu 七牛云 |
| ByteDance Seed | Volcengine Ark | OpenRouter · DeepInfra |

**La colonne de droite vient d'avoir demandé sa liste de modèles à chaque fournisseur
et d'avoir regardé, le 2026-09-10.** Celle de gauche vient de leur propre documentation,
confirmée par une requête sans clé.

**Documenté, mais non vérifié ici**

[Google Gemini](https://ai.google.dev/gemini-api/docs/openai),
[GitHub Models](https://docs.github.com/github-models) et
[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai) documentent tous
un endpoint compatible OpenAI, et **aucun des trois n'a pu être confirmé par une requête
sans clé**. Ils sont ici plutôt qu'au-dessus **pour que la différence se voie**.

**Quotas gratuits**

Plusieurs d'entre eux donnent quelque chose — Groq, Cerebras, ModelScope, NVIDIA, les
modèles gratuits d'OpenRouter, le palier Flash de 智谱, SiliconFlow, 百度千帆, Google et
GitHub, entre autres. **Ce qui est gratuit change d'un mois à l'autre et n'est pas quelque
chose que ce fichier peut garder vrai**, donc aucun montant n'est cité : allez voir la page
de tarifs du fournisseur. **C'est la manière la moins chère d'essayer ceci avec un modèle
plus gros que ce que votre machine peut contenir.**

Deux remarques honnêtes. **Être joignable n'est pas la même chose qu'être bon à cela** —
c'est à quoi sert le tableau des modèles ci-dessus, et **il a une ligne parce qu'un seul
modèle a été essayé**. Et **un fournisseur qui répond à l'API OpenAI mais pas à sa partie
appel d'outils discutera, et guère plus**.
