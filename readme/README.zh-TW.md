<div align="center">

<img src="../website/public/favicon.svg" width="80" alt="OpenCLI" />

# OpenCLI

**給你自己跑的模型,一個開源 agent**

[![CI](https://img.shields.io/github/actions/workflow/status/ai-dashboad/opencli/rust-ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/ai-dashboad/opencli/actions/workflows/rust-ci.yml)
[![Release](https://img.shields.io/github/v/release/ai-dashboad/opencli?style=flat-square)](https://github.com/ai-dashboad/opencli/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ai-dashboad/opencli/total?style=flat-square)](https://github.com/ai-dashboad/opencli/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat-square)](../LICENSE)

[English](../README.md) ·
[简体中文](./README.zh-CN.md) ·
**繁體中文** ·
[日本語](./README.ja.md) ·
[한국어](./README.ko.md) ·
[Español](./README.es.md) ·
[Português](./README.pt-BR.md) ·
[Français](./README.fr.md) ·
[Deutsch](./README.de.md) ·
[Русский](./README.ru.md)

[下載](https://opencli.ai/download.html) ·
[文檔](https://docs.opencli.ai) ·
[開始](https://docs.opencli.ai/getting-started/install) ·
[供應商](https://docs.opencli.ai/getting-started/providers) ·
[做不到什么](https://docs.opencli.ai/reference/limits)

</div>

OpenCLI 是一個跑在你自己電腦上的 agent,能用任何 OpenAI 兼容的模型 —— 你面前這臺機器上的、你自己伺服器上的,或者你願意用的時候接一個在線服務。它讀你的文件、執行你的命令、修改你的東西;終端機和桌面端共享同一批對話。

**什么都不內置。** 不帶模型、不要帳號、不含金鑰,對「你從誰那裡買推理」不持任何立場。指向一個介面,它的模型就自動出現;你輸入的東西只去那裡,不去別處。

## 下載

| 平臺 | |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

裝完之後它會自己更新。這些安裝檔沒有 Apple / 微軟的證书,所以第一次啟動要多一步 — [怎么辦](https://docs.opencli.ai/getting-started/install).

**命令列,macOS 和 Linux:**

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

然後指一個模型給它。

## 它能做什么

- 🗂 **幹的是文件的活兒,不只是程式碼。** 它讀一個裝滿發票的資料夾,和讀一個程式碼儲存庫是同一件事 —— 而大多數人手上真正的活兒是前一種。

- 🏢 **按一間公司的樣子組織。** **部門**是一個目錄加一份常設說明,**Bot** 是部門裡的一個對話、帶著一份職責。九個部門帶樣例資料一起裝好,每一項都可以先試再配。

- ⏰ **值守會自己到點** —— 並且在碰到不該自己決定的事情時**停下來問你**。這個界線是事先用話寫好的:*任何單筆超過 10000*。

- 🤝 **Bot 之間互相传活兒,** 連同做了什么、產出了哪些文件一起传過去。最多八跳,每個 Bot 最多出現三次,所以連鎖不會失控。

- 🧰 **六個流程作為技能內置,** 在任何目錄都能用:按規則核查一張表、周報、收件箱分揀、兩版文檔比對、會議纪要轉成決定和負責人、檔案審閱。

- 🔌 **連接器就是 MCP 服務** —— GitHub、Postgres、Slack、Notion、瀏覽器。金鑰不放在設定文件裡,因為那個文件會被分享出去。

- 🚦 **沙箱的邊界是看得見的。** 一次執行只能寫它自己的目錄,別處寫不了;指向陌生位置的執行會被扣住,等你按名字授權那個地方。

- 🌍 **十種語言,** 其他任何語言就是一個 JSON 文件,不用重新編譯任何東西。

- 💻 **終端機、桌面端、本地網頁** 共用同一個閘道,所以在一處開始的對話可以在另一處繼續。

## 能連什么

不是三十個對接,是**一個協議**。任何按 OpenAI 的方式回答 `/v1/chat/completions` 和 `/v1/models` 的地址都能指過去,它的模型會自動出現。下面每一個地址都被問過模型清單,才寫進這裡。

**在你的機器上** — Ollama · LM Studio · llama.cpp · LocalAI · Jan ·
Xinference · KoboldCpp · llamafile

**在你的伺服器上** — vLLM · SGLang · Text Generation Inference · NVIDIA NIM ·
LiteLLM

**托管開源模型的** — Fireworks · Together · Groq · DeepInfra · Baseten ·
Novita · Hyperbolic · Nebius · Cerebras · SambaNova · Featherless · Chutes ·
NVIDIA · Hugging Face · OpenRouter · Vercel AI Gateway · Perplexity

**国內** — 硅基流动 · 无问芯穹 · PPIO · 七牛云 · 魔搭 · 阿里云百炼 ·
火山方舟 / 豆包 · 百度千帆 · 讯飞星火 · 小米 MiMo · DeepSeek · 智谱 ·
月之暗面 · MiniMax · 阶跃星辰 · 腾讯混元 · 百川

**閉源模型,想用的時候** — OpenAI · Anthropic · Mistral · xAI

**其中不少家給免費額度**,那是用比你機器裝得下更大的模型試這個東西最便宜的辦法。具体地址、以及哪個模型由誰提供: [供應商](https://docs.opencli.ai/getting-started/providers).

> **能連上不等於干得了這活兒。** 會不會調用工具,是「能幹活」和「只能聊」之間的分水岭,而模型卡上從來不寫。
> [測一下你的](https://docs.opencli.ai/reference/checking-a-model) —
> 一個固定任務,五分鐘。表裡只有一行,因為只跑過一個模型 —— **給它加一行是你能做的最有用的貢獻。**

## 它做不到什么

- **通用開源模型手上有文件工具,還是會去用 `grep`。** 這是模型的差距,換任何介面都補不上。
- **token 數是估算的,從來不是數出來的。** 分詞器屬於模型,而這個程式要跑它從沒見過的模型。
- **定時的活兒只在 OpenCLI 開著時執行。** 它是本地 agent,不是伺服器。
- **一次後臺執行可以寫它所在目錄裡的任何東西。**
- **桌面端沒有程式碼簽名。** 系統警告你是對的。
- **從右往左书寫的語言,版面還沒做。**

[做不到什么](https://docs.opencli.ai/reference/limits) 裡每一條都寫了為什么。

## 這個專案從哪來

fork 自 [OpenAI 的 Codex CLI](https://github.com/openai/codex),版權歸 OpenAI 所有(2025),Apache-2.0。**與 OpenAI 無關聯。**

Codex 是為 OpenAI 的模型做的,而這個是為別人的模型做的 —— 這件事改變的不只是一個名字。部門、Bot、值守、後臺執行,以及那些流程,都是這邊加的。還有相当一部分工作是在處理「模型小了會壞在哪裡」:一個連著十一輪每輪都壓縮一次、每次都把上下文扔掉的死循環;以及一個把一整頁中文讀成實際成本四分之三的 token 估算。

[Apache-2.0](../LICENSE) · [NOTICE](../NOTICE) ·
[參與開發](https://docs.opencli.ai/reference/contributing)
