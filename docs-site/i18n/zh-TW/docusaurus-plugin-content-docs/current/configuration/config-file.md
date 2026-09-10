---
title: 設定文件
sidebar_position: 1
---

# 設定文件

`~/.opencli/config.toml`。這裡每一項都有預設值;**這個文件只保存你改過的東西**。

桌面端寫的是同一個文件,**並且保留你的注釋和排版** —— 所以手工編輯和在**設定**裡改,
是同一件事。

## Provider 和模型

一個 provider 就是「一個地址 + 一個存放金鑰的環境變量名」:

```toml
[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

在它下面聲明的模型會出現在選單裡:

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

`slug` 是你敲的,`model` 是那家怎麼叫它。**這兩者不一樣的情況夠多,值得分開。**

**你不是非聲明不可。** 模型是從 provider 的 `/v1/models` 拉來的。聲明一個,是為了釘住
上下文視窗、顯示名、或者它接受哪些思考強度。

## 審批和沙箱

```toml
approval_policy = "on-failure"   # untrusted | on-failure | never
sandbox_mode = "workspace-write" # read-only | workspace-write | danger-full-access
```

見[沙箱與審批](/configuration/sandbox-and-approvals)。

## 工具輸出

```toml
tool_output_token_limit = 10000
```

一次工具輸出可以往對話裡加多少的預算。

**token 是估算的,不是數出來的。** 分詞器屬於模型,而這個程式要跑它從沒見過的模型。
估算方式是 ASCII 四字節算一個 token、其餘按字算一個 —— **對英文和中文都夠近**,其他情況
偏向多算。設成 500 **不會**正好在 500 個 token 處截斷;它會截在附近,**但用的是這個數字
所寫的那個單位**。

## 看什麼設定在生效

**設定**頁顯示每一個生效的值**以及它從哪來**,包括你從沒設過的那些。`顯示原始設定`
就是文件本身。

## 完整參考

這個文件接受的每一個鍵,連同預設值:[完整設定參考](/configuration/reference)。
