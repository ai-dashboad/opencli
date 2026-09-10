---
title: 指一個模型給它
sidebar_position: 2
---

# 指一個模型給它

OpenCLI **不帶模型也不帶金鑰**。全新安裝的第一屏會這麼說,並給出下面兩條路。

**這不是一張對接清單,而是一個協議。** 任何按 OpenAI 的方式回答
`/v1/chat/completions` 和 `/v1/models` 的地址都能指過去,而且**它的模型會自動出現在
選單裡** —— 你不用一個個聲明。

## 這臺機器上

桌面端可以幫你裝一個:打開**模型**,它會**先看這臺機器上已經有什麼**,再決定要不要下載。

手工設定,前提是 [Ollama](https://ollama.com) 已經在跑:

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

放進 `~/.opencli/config.toml`,然後執行 `opencli`。

**什麼都不會離開這臺機器,也沒有金鑰要保管。**

## 一家在線服務

每一家都一樣。模式是「一個地址 + 一個存放金鑰的環境變量名」:

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

桌面端裡同樣的事在**設定**裡做,金鑰存好之後不會再顯示出來。

### 免費額度是試大模型最便宜的辦法

好幾家都給一點免費的,那是你跑**比自己機器裝得下更大的模型**的方式。免費的部分逐月
在變,所以這一頁不寫具體數字 —— 看他們自己的價格頁。

## 一個模型不一定從做它的那家拿

小米和字節**既有自己的介面,也把模型交給別人托管** —— 哪邊更便宜、更快、離你更近,
不一定。完整對照在[供應商](/getting-started/providers)。

## 能連上不等於幹得了這活兒

**一個實現了 OpenAI 對話介面、但沒實現工具調用的服務,在這裡只能聊天** —— 這個 agent
是靠調用工具幹活的。

在投入一個模型之前,[先測它](/reference/checking-a-model) —— 五分鐘,一個固定任務。

## 下一步

[第一次對話](/getting-started/first-conversation)。
