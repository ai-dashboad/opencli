---
title: 指一个模型给它
sidebar_position: 2
---

# 指一个模型给它

OpenCLI **不带模型也不带密钥**。全新安装的第一屏会这么说,并给出下面两条路。

**这不是一张对接清单,而是一个协议。** 任何按 OpenAI 的方式回答
`/v1/chat/completions` 和 `/v1/models` 的地址都能指过去,而且**它的模型会自动出现在
选单里** —— 你不用一个个声明。

## 这台机器上

桌面端可以帮你装一个:打开**模型**,它会**先看这台机器上已经有什么**,再决定要不要下载。

手工配置,前提是 [Ollama](https://ollama.com) 已经在跑:

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

放进 `~/.opencli/config.toml`,然后运行 `opencli`。

**什么都不会离开这台机器,也没有密钥要保管。**

## 一家在线服务

每一家都一样。模式是「一个地址 + 一个存放密钥的环境变量名」:

```toml
model = "my-model"

[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

```shell
export MY_PROVIDER_API_KEY=...
opencli
```

桌面端里同样的事在**设置**里做,密钥存好之后不会再显示出来。

### 免费额度是试大模型最便宜的办法

好几家都给一点免费的,那是你跑**比自己机器装得下更大的模型**的方式。免费的部分逐月
在变,所以这一页不写具体数字 —— 看他们自己的价格页。

## 一个模型不一定从做它的那家拿

小米和字节**既有自己的接口,也把模型交给别人托管** —— 哪边更便宜、更快、离你更近,
不一定。完整对照在[供应商](/getting-started/providers)。

## 能连上不等于干得了这活儿

**一个实现了 OpenAI 对话接口、但没实现工具调用的服务,在这里只能聊天** —— 这个 agent
是靠调用工具干活的。

在投入一个模型之前,[先测它](/reference/checking-a-model) —— 五分钟,一个固定任务。

## 下一步

[第一次对话](/getting-started/first-conversation)。
