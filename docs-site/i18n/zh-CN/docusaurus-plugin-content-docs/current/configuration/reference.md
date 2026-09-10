---
title: 完整配置参考
sidebar_position: 4
---

# 完整配置参考

`~/.opencli/config.toml` 接受的每一个键。**大多数人只会碰其中少数几个**,
那些在[配置文件](/configuration/config-file)里,那页短得多。

### 最快的路:让 OpenCLI 自己找到你的模型

如果你本地已经在跑 Ollama、LM Studio、vLLM 或 llama.cpp:

```shell
opencli provider scan
```

**这会探常见的 localhost 端口**,问每一个找到的服务它在跑哪些模型,
然后把对应的 `[model_providers.*]` 和 `[[models]]` 段写进你的 `config.toml` ——
**已有的注释和设置会保留**。加 `--dry-run` 可以先看它打算写什么。

托管的 provider,从目录里装一个再配上密钥:

```shell
opencli provider list          # 目录,加上已经配好的
opencli provider add openrouter
export OPENROUTER_API_KEY=...
```

**目录里只有连接信息** —— 二进制里不带任何密钥,而且在你加之前什么都不生效。
要配目录里没有的东西,按下面说的自己写这些段。

#### 补上一个模型的能力

**本地模型的上下文窗口和工具调用支持,哪儿都没公布**,而**猜比不填更糟** ——
上下文窗口填得太大,意味着 provider 直接拒掉这一轮,而不是自动压缩。
**去问模型本人**:

```shell
opencli model probe <slug>            # 加 --dry-run 可以预览
```

这会读运行时自己的元数据(**Ollama 会报出真实的上下文长度和能力列表**),
并且**额外发一次真实请求**,看这个模型会不会去调一个递给它的工具、
以及会不会把思考放在单独的 `reasoning` 字段里返回。结果写进该模型的 `[[models]]` 条目。

**完全不能聊天的模型** —— 比如 embedding 模型 —— 会被 `provider scan` 跳过,
所以它们永远到不了 `/model` 选择器里。

### 选模型和 provider

这个构建内置了几个网关的预设,但**任何能通过 OpenAI 兼容 API 连上的模型**,
都可以在 `~/.opencli/config.toml` 里配好,**不用重新编译**。

#### 加一个 provider

`[model_providers.<id>]` 里的条目**会覆盖同名的内置 provider**,
所以这也是把一个自带网关重新指向某个代理或镜像的办法:

```toml
[model_providers.my-gateway]
name = "My Gateway"
base_url = "https://gateway.example.com/v1"
env_key = "MY_GATEWAY_API_KEY"
wire_api = "chat"
# 可选:这个网关吐第一个 token 很慢的话,调大它。
stream_idle_timeout_ms = 90000
```

**API 密钥总是从环境变量读,永远不存进配置文件。**

#### 加一个模型

用 `[[models]]` 声明模型。它们会出现在 `/model` 选择器里、挨着内置预设,
而**一个 `model` 与内置预设同名的条目会替换掉它**:

```toml
[[models]]
model = "qwen3-max"
provider = "my-gateway"
display_name = "Qwen3 Max"     # 可选,默认用 slug
description = "自建的。"        # 可选
show_in_picker = true          # 可选,默认 true
```

`provider` 必填,而且必须指向上面定义过的、或者一个内置的 provider;
**指向未定义 provider 的模型会在启动时就被拒绝**,而不是过后带着一个无关的错误失败。

想选一个模型但不把它加进选择器,直接设 `model` 和 `model_provider`:

```toml
model = "qwen3-max"
model_provider = "my-gateway"
```

如果 `model` 指的东西既不是内置预设也不是某个 `[[models]]` 条目,而 `model_provider`
又没设,请求会退回到 `openai` provider,并记一条警告。

#### 上下文窗口

**这个构建没有元数据的模型,从一个保守的 131,072 token 窗口开始**,
并从网关第一次「上下文窗口超了」的拒绝里学到真实值。
设 `model_context_window` 可以把它钉死。

### 连接 MCP 服务器

OpenCLI 可以连上在 `~/.opencli/config.toml` 里声明的 MCP 服务器。

```toml
[mcp_servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env_vars = ["GITHUB_PERSONAL_ACCESS_TOKEN"]

[mcp_servers.internal]
url = "https://mcp.example.com/mcp"
```

`env_vars` 写的是这个服务需要哪些变量;**值和你其他密钥放在一起,而不是放进这个会被分享
出去的文件里**。这里声明的服务,**在你下一次打开的聊天里启动,不是眼前这个。**

桌面端从 **Abilities → Connectors** 写的是同一张表,**它还会测握手**,
并列出每个服务提供的工具。

### 应用(Connectors)

在输入框里用 `$` 插入一个 ChatGPT connector;弹出层会列出可用的应用。
`/apps` 命令列出可用和已装的应用。**已连接的排在前面并标为已连接**,其余标为可安装。

### 通知

OpenCLI 可以在 agent 结束一轮时跑一个通知钩子。

```toml
notify = ["/path/to/your/script.sh"]
```

这个程序被调用时带一个参数:**一个描述发生了什么的 JSON 对象**。
它是分离运行的,**所以一个慢脚本不会拖住下一轮**,而一个失败的脚本只记日志、不弹到面前。

### JSON Schema

`config.toml` 生成的 JSON Schema 在
[`opencli-rs/core/config.schema.json`](https://github.com/ai-dashboad/opencli/blob/main/opencli-rs/core/config.schema.json),
**每个 release 都会带上一份 `config-schema.json`**。手动改这个文件时,
把编辑器指过去就有补全和校验。

**它是从 Rust 类型生成的,而且一旦和它们漂开 CI 就会红** ——
所以**它是这个文件唯一不会过期的说明。**

### 提示开关

OpenCLI 把某些界面提示的「不再显示」标记存在 `[notice]` 表里。

Ctrl+C / Ctrl+D 退出用的是大约一秒内双击的提示(`ctrl + c again to quit`)。
