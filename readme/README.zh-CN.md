<div align="center">

<img src="../website/public/favicon.svg" width="80" alt="OpenCLI" />

# OpenCLI

**给你自己跑的模型,一个开源 agent**

[![CI](https://img.shields.io/github/actions/workflow/status/ai-dashboad/opencli/rust-ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/ai-dashboad/opencli/actions/workflows/rust-ci.yml)
[![Release](https://img.shields.io/github/v/release/ai-dashboad/opencli?style=flat-square)](https://github.com/ai-dashboad/opencli/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ai-dashboad/opencli/total?style=flat-square)](https://github.com/ai-dashboad/opencli/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat-square)](../LICENSE)

[English](../README.md) ·
**简体中文** ·
[繁體中文](./README.zh-TW.md) ·
[日本語](./README.ja.md) ·
[한국어](./README.ko.md) ·
[Español](./README.es.md) ·
[Português](./README.pt-BR.md) ·
[Français](./README.fr.md) ·
[Deutsch](./README.de.md) ·
[Русский](./README.ru.md)

[下载](https://opencli.ai/download.html) ·
[文档](https://docs.opencli.ai) ·
[开始](https://docs.opencli.ai/getting-started/install) ·
[供应商](https://docs.opencli.ai/getting-started/providers) ·
[做不到什么](https://docs.opencli.ai/reference/limits)

</div>

OpenCLI 是一个跑在你自己电脑上的 agent,能用任何 OpenAI 兼容的模型 —— 你面前这台机器上的、你自己服务器上的,或者你愿意用的时候接一个在线服务。它读你的文件、执行你的命令、修改你的东西;终端和桌面端共享同一批会话。

**什么都不内置。** 不带模型、不要账号、不含密钥,对「你从谁那里买推理」不持任何立场。指向一个接口,它的模型就自动出现;你输入的东西只去那里,不去别处。

## 下载

| 平台 | |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

装完之后它会自己更新。这些安装包没有 Apple / 微软的证书,所以第一次启动要多一步 — [怎么办](https://docs.opencli.ai/getting-started/install).

**命令行,macOS 和 Linux:**

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

然后指一个模型给它。

## 它能做什么

- 🗂 **干的是文件的活儿,不只是代码。** 它读一个装满发票的文件夹,和读一个代码仓库是同一件事 —— 而大多数人手上真正的活儿是前一种。

- 🏢 **按一间公司的样子组织。** **部门**是一个目录加一份常设说明,**Bot** 是部门里的一个会话、带着一份职责。九个部门带样例数据一起装好,每一项都可以先试再配。

- ⏰ **值守会自己到点** —— 并且在碰到不该自己决定的事情时**停下来问你**。这个界线是事先用话写好的:*任何单笔超过 10000*。

- 🤝 **Bot 之间互相传活儿,** 连同做了什么、产出了哪些文件一起传过去。最多八跳,每个 Bot 最多出现三次,所以连锁不会失控。

- 🧰 **六个流程作为技能内置,** 在任何目录都能用:按规则核查一张表、周报、收件箱分拣、两版文档比对、会议纪要转成决定和负责人、档案审阅。

- 🔌 **连接器就是 MCP 服务** —— GitHub、Postgres、Slack、Notion、浏览器。密钥不放在配置文件里,因为那个文件会被分享出去。

- 🚦 **沙箱的边界是看得见的。** 一次运行只能写它自己的目录,别处写不了;指向陌生位置的运行会被扣住,等你按名字授权那个地方。

- 🌍 **十种语言,** 其他任何语言就是一个 JSON 文件,不用重新编译任何东西。

- 💻 **终端、桌面端、本地网页** 共用同一个网关,所以在一处开始的会话可以在另一处继续。

## 能连什么

不是三十个对接,是**一个协议**。任何按 OpenAI 的方式回答 `/v1/chat/completions` 和 `/v1/models` 的地址都能指过去,它的模型会自动出现。下面每一个地址都被问过模型列表,才写进这里。

**在你的机器上** — Ollama · LM Studio · llama.cpp · LocalAI · Jan ·
Xinference · KoboldCpp · llamafile

**在你的服务器上** — vLLM · SGLang · Text Generation Inference · NVIDIA NIM ·
LiteLLM

**托管开源模型的** — Fireworks · Together · Groq · DeepInfra · Baseten ·
Novita · Hyperbolic · Nebius · Cerebras · SambaNova · Featherless · Chutes ·
NVIDIA · Hugging Face · OpenRouter · Vercel AI Gateway · Perplexity

**国内** — 硅基流动 · 无问芯穹 · PPIO · 七牛云 · 魔搭 · 阿里云百炼 ·
火山方舟 / 豆包 · 百度千帆 · 讯飞星火 · 小米 MiMo · DeepSeek · 智谱 ·
月之暗面 · MiniMax · 阶跃星辰 · 腾讯混元 · 百川

**闭源模型,想用的时候** — OpenAI · Anthropic · Mistral · xAI

**其中不少家给免费额度**,那是用比你机器装得下更大的模型试这个东西最便宜的办法。具体地址、以及哪个模型由谁提供: [供应商](https://docs.opencli.ai/getting-started/providers).

> **能连上不等于干得了这活儿。** 会不会调用工具,是「能干活」和「只能聊」之间的分水岭,而模型卡上从来不写。
> [测一下你的](https://docs.opencli.ai/reference/checking-a-model) —
> 一个固定任务,五分钟。表里只有一行,因为只跑过一个模型 —— **给它加一行是你能做的最有用的贡献。**

## 它做不到什么

- **通用开源模型手上有文件工具,还是会去用 `grep`。** 这是模型的差距,换任何界面都补不上。
- **token 数是估算的,从来不是数出来的。** 分词器属于模型,而这个程序要跑它从没见过的模型。
- **定时的活儿只在 OpenCLI 开着时执行。** 它是本地 agent,不是服务器。
- **一次后台运行可以写它所在目录里的任何东西。**
- **桌面端没有代码签名。** 系统警告你是对的。
- **从右往左书写的语言,版面还没做。**

[做不到什么](https://docs.opencli.ai/reference/limits) 里每一条都写了为什么。

## 这个项目从哪来

fork 自 [OpenAI 的 Codex CLI](https://github.com/openai/codex),版权归 OpenAI 所有(2025),Apache-2.0。**与 OpenAI 无关联。**

Codex 是为 OpenAI 的模型做的,而这个是为别人的模型做的 —— 这件事改变的不只是一个名字。部门、Bot、值守、后台运行,以及那些流程,都是这边加的。还有相当一部分工作是在处理「模型小了会坏在哪里」:一个连着十一轮每轮都压缩一次、每次都把上下文扔掉的死循环;以及一个把一整页中文读成实际成本四分之三的 token 估算。

[Apache-2.0](../LICENSE) · [NOTICE](../NOTICE) ·
[参与开发](https://docs.opencli.ai/reference/contributing)
