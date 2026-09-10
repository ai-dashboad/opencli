---
title: 配置文件
sidebar_position: 1
---

# 配置文件

`~/.opencli/config.toml`。这里每一项都有默认值;**这个文件只保存你改过的东西**。

桌面端写的是同一个文件,**并且保留你的注释和排版** —— 所以手工编辑和在**设置**里改,
是同一件事。

## Provider 和模型

一个 provider 就是「一个地址 + 一个存放密钥的环境变量名」:

```toml
[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

在它下面声明的模型会出现在选单里:

```toml
model = "my-model"

[[models]]
slug = "my-model"
model = "provider-side-model-id"
provider = "my-provider"
display_name = "My Model"
context_window = 128000
reasoning_efforts = ["low", "medium", "high"]
```

`slug` 是你敲的,`model` 是那家怎么叫它。**这两者不一样的情况够多,值得分开。**

**你不是非声明不可。** 模型是从 provider 的 `/v1/models` 拉来的。声明一个,是为了钉住
上下文窗口、显示名、或者它接受哪些思考强度。

## 审批和沙箱

```toml
approval_policy = "on-failure"   # untrusted | on-failure | never
sandbox_mode = "workspace-write" # read-only | workspace-write | danger-full-access
```

见[沙箱与审批](/configuration/sandbox-and-approvals)。

## 工具输出

```toml
tool_output_token_limit = 10000
```

一次工具输出可以往对话里加多少的预算。

**token 是估算的,不是数出来的。** 分词器属于模型,而这个程序要跑它从没见过的模型。
估算方式是 ASCII 四字节算一个 token、其余按字算一个 —— **对英文和中文都够近**,其他情况
偏向多算。设成 500 **不会**正好在 500 个 token 处截断;它会截在附近,**但用的是这个数字
所写的那个单位**。

## 看什么设置在生效

**设置**页显示每一个生效的值**以及它从哪来**,包括你从没设过的那些。`显示原始配置`
就是文件本身。

## 完整参考

这个文件接受的每一个键,连同默认值:[完整配置参考](/configuration/reference)。
