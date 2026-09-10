# OpenCLI

中文 · **[English](./README.md)**

Claude 有 Claude Code,OpenAI 有 Codex,Gemini 有自己的 CLI。

**你真正跑得动的那些模型 —— Qwen、DeepSeek、GLM、Llama、Mistral —— 一个都没有。**

OpenCLI 就是它们的那一个。一个终端 agent 加一个桌面应用,指向任何
OpenAI 兼容的接口:你面前这台机器上的模型、你自己的网关,或者你愿意用的时候
接一个在线服务。它不自带模型,不需要账号,不内置任何密钥。

不用翻墙,不用付费,你输入的东西不离开这台机器。

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

或者[下载桌面端](https://opencli.ai/download.html),macOS、Windows、Linux 都有。

---

## 它不只是写代码的

这个 agent 会读文件、执行命令、修改内容。这件事对一个装满发票的文件夹和对一个
代码仓库同样成立 —— 而大多数人手上真正的活儿是前一种。

所以桌面端是按一间公司的样子组织的。**部门**是一个目录加一份常驻说明,**Bot**
是部门里的一个会话,带着一份职责,**值守**是一份会自己到点、卡住了会来问你的
工作。九个部门带样例数据一起装好,所以每一项都可以先试再配:

| 部门 | 装好就能跑的活儿 |
| --- | --- |
| **财务** | 拿 `ledger.csv` 和 `statement.csv` 对账;给每个逾期客户各起一封催款邮件 |
| **客服** | 逐条回复进来的问题;把它们按「真正在问什么」归类 |
| **运营** | 列出所有还没发货的订单,以及各等了多少天 |
| **市场** | 把笔记变成一周的推文;按买过什么给联系人分组 |
| **人事行政** | 拿简历对岗位;从会议记录里揪出决定、负责人、和没人认领的事 |
| **法务** | 逐条比对对方草案和我方条款,两版都引出来 |
| **研究** | 归纳研究之间在哪里一致、在哪里冲突、以及为什么 |
| **病历** | 按时间列出记录了什么,以及医生该看一眼的地方,并引用原始记录 |
| **研发** | 读一个服务,报出哪里会给出错误的结果 |

另外六个流程作为技能内置,在任何目录都能用:**按规则核查一张表**、**周报**、
**收件箱分拣**、**两版文档比对**、**会议纪要转成决定和负责人**、**档案审阅**。

---

## 哪些模型真的能用

这是别人不回答的那个问题。能不能调用工具,是「能干活」和「只能聊」之间的分水岭,
而模型卡上从来不写。

表里每一行都是同一个固定任务:一张六行的发票表,埋了三个问题 —— 超额但没有采购
单号、金额空着、月份是 13 —— 外加一份写明三条规则的 `rules.md`。通过的标准是三个
全部找到,各自引出所违反的规则,并且说出行号。

| 模型 | 运行时 | 会调工具 | 三个全中 | 备注 |
| --- | --- | --- | --- | --- |
| `huihui-qwen3.8-27b` | Ollama,本机 | 是 | 是 | 用脚本验的,不是眼看的。第一次凭记忆报行数,报错了一位;技能已改成要求这个数字必须来自脚本 |

这张表短,是因为它只放跑过的。**给它加一行是你能做的最有用的贡献** ——
任务在 [`docs/model-check.md`](./docs/model-check.md),大概五分钟。

---

## 模型从哪来

**这不是一张"我们对接了谁"的清单,而是一个协议。** 任何按 OpenAI 的方式回答
`/v1/chat/completions` 和 `/v1/models` 的地址都能指过去,而且它的模型会自动出现在
选单里,不用一个个声明。

所以下面这张表列的是**人们把它指向哪里**。表里每一个地址都在 2026-09-06 被不带 key
地问过一次模型列表 —— 返回 `401` 就是证据:路径存在、要鉴权、而且是 OpenAI 的形状。

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
以及用 [LiteLLM](https://docs.litellm.ai) 在它们前面做网关

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

[硅基流动](https://siliconflow.cn) · [无问芯穹](https://cloud.infini-ai.com) ·
[PPIO 派欧云](https://ppinfra.com) · [七牛云](https://qiniu.com) ·
[魔搭 ModelScope](https://modelscope.cn) ·
[阿里云百炼](https://bailian.console.aliyun.com) ·
[火山方舟 · 豆包](https://volcengine.com/product/ark) ·
[百度千帆](https://cloud.baidu.com/product/wenxinworkshop) ·
[讯飞星火](https://xinghuo.xfyun.cn) ·
[DeepSeek](https://deepseek.com) · [智谱](https://bigmodel.cn) ·
[月之暗面 Kimi](https://moonshot.cn) · [MiniMax](https://minimax.io) ·
[阶跃星辰](https://stepfun.com) · [腾讯混元](https://cloud.tencent.com/product/hunyuan) ·
[百川智能](https://baichuan-ai.com)

**闭源模型,想用的时候**

[OpenAI](https://openai.com) · [Anthropic](https://anthropic.com) ·
[Mistral](https://mistral.ai) · [xAI](https://x.ai)

**一个模型,不一定从做它的那家公司拿**

小米发布 MiMo、字节发布 Seed,但**这两家都没有自己的公开 OpenAI 兼容接口**
(`xiaoai.mi.com` 返回的是网页,不是 API)。它们由别人托管 —— 这才是你实际连过去的地方:

| 模型 | 谁在提供 |
| --- | --- |
| 小米 MiMo | OpenRouter · Novita · DeepInfra · PPIO · Featherless · Hugging Face |
| 字节 Seed | OpenRouter · DeepInfra |
| 豆包 | 火山方舟(字节自家平台) · 七牛云 |

这几行是 2026-09-10 逐个问各家的模型列表、在里面找出来的,**不是从新闻稿抄的**。

**文档里写着支持,但我没验证成功的**

[Google Gemini](https://ai.google.dev/gemini-api/docs/openai)、
[GitHub Models](https://docs.github.com/github-models)、
[Cloudflare Workers AI](https://developers.cloudflare.com/workers-ai)
三家都在文档里写了 OpenAI 兼容接口,但都没能用一次不带 key 的请求确认。
放在这里而不是上面,是为了让这个差别看得见。

**免费额度**

这里面不少家是给免费额度的 —— Groq、Cerebras、魔搭、NVIDIA、OpenRouter 的免费模型、
智谱的 Flash、硅基流动、百度千帆、Google、GitHub 都在其中。**免费的部分逐月在变,
这个文件保不住它的准确性**,所以这里不写具体数字,请看各家自己的价格页。

这是用**比你机器装得下更大的模型**试这个东西最便宜的办法。

两句实话。**能连上不等于干得了这活儿** —— 那是上面那张模型表回答的问题,而它只有
一行,因为只跑过一个模型。另外,一个只实现了 OpenAI 对话接口、没实现工具调用的服务,
在这里只能聊天,干不了别的。

---

## 它做不到什么

写在这里,而不是让你后面自己发现。

- **通用开源模型手上有文件工具,还是会去用 `grep`。** 给了它结构化的读文件方式,
  一个没往这个方向训练过的模型仍然会退回 shell。这是模型的差距,换任何界面都补
  不上。这个项目能改变的是**可达性**,不是聪明程度。
- **桌面端没有 Apple / 微软的证书签名。** 系统会警告你,而且它警告得对:它确实
  没法判断是谁做的。macOS 上执行一次
  `xattr -dr com.apple.quarantine /Applications/OpenCLI.app`,或者右键 → *打开*。
  Windows 的 SmartScreen 要点 *More info* → *Run anyway*。
- **定时任务只在 OpenCLI 开着的时候跑。** 它是一个本地 agent,不是服务器。需要在
  机器睡着时触发的,请交给系统自己的调度器。
- **token 数是估算的,从来不是数出来的。** 分词器属于模型,而这个程序要跑它从没
  见过的模型。ASCII 四字节算一个 token,其余按字算一个 —— 对英文和中文都够近,
  其他情况偏向多算。
- **一次后台运行可以写它所在目录里的任何东西。** 沙箱的可写根**就是**那个目录。
  不在任何部门目录里的运行会被扣住,等你按名字授权那个位置。

---

## 安装

**桌面端** —— [opencli.ai/download](https://opencli.ai/download.html),或者直接从
最新的 release 拿:

| 平台 | 文件 |
| --- | --- |
| macOS,Apple 芯片 | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS,Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

装完之后它会自己更新。

**命令行** —— 一个二进制,macOS 和 Linux:

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

或者用 npm,任何能跑 Node 的地方:

```shell
npm install -g @ai-dashboad/opencli
```

**从源码构建** —— 需要一个较新的 Rust 工具链:

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

---

## 指一个模型给它

本机的 Ollama,`~/.opencli/config.toml` 里只要这些:

```toml
model = "qwen3-coder"

[model_providers.ollama]
name = "Ollama"
base_url = "http://localhost:11434/v1"
wire_api = "chat"

[[models]]
slug = "qwen3-coder"
model = "qwen3-coder:30b"
provider = "ollama"
context_window = 32768
```

然后 `opencli`。桌面端也可以直接帮你装一个本机模型 —— 进 **Models**,它会先看
这台机器上已经有什么。

任何 OpenAI 兼容的接口都一样,在线的也行。完整的配置说明在
[docs/config.md](./docs/config.md)。

---

## 界面语言

内置英文和简体中文。其他任何语言就是 `~/.opencli/locales` 里的一个文件 ——
见 [docs/languages.md](./docs/languages.md)。文件名如果和已内置的语言同名,它只会
**修正**其中的某几句,而不是替换整份翻译 —— 改一句别扭的话不该赔上另外四百句。

---

## 文档

- [**配置**](./docs/config.md) —— provider、模型、路由、沙箱
- [**加一种语言**](./docs/languages.md)
- [**测一个模型**](./docs/model-check.md) —— 上面那张表背后的任务
- [**参与开发**](./docs/contributing.md)
- [**安装与构建**](./docs/install.md)

---

## 这个项目从哪来

OpenCLI fork 自 [OpenAI 的 Codex CLI](https://github.com/openai/codex),
版权归 OpenAI 所有(2025),Apache-2.0 协议。**本项目与 OpenAI 无关联。**

之所以 fork,是因为 Codex 是为 OpenAI 的模型做的,而 OpenCLI 是为别人的模型做的
—— 这件事改变的不只是一个名字。部门、Bot、值守、后台运行,以及上面那些流程,都是
这边加的。还有相当一部分工作是在处理「模型小了会坏在哪里」:一个连着十一轮每轮
都压缩一次、每次都把上下文扔掉的死循环;以及一个把一整页中文读成实际成本四分之三
的 token 估算。

本项目使用 [Apache-2.0](LICENSE) 协议。完整归属见 [NOTICE](NOTICE)。
