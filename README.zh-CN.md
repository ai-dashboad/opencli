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
