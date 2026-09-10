---
title: 完整設定參考
sidebar_position: 4
---

# 完整設定參考

`~/.opencli/config.toml` 接受的每一個鍵。**大多數人只會碰其中少數幾個**,
那些在[設定文件](/configuration/config-file)裡,那頁短得多。

### 最快的路:讓 OpenCLI 自己找到你的模型

如果你本地已經在跑 Ollama、LM Studio、vLLM 或 llama.cpp:

```shell
opencli provider scan
```

**這會探常見的 localhost 端口**,問每一個找到的服務它在跑哪些模型,
然後把對應的 `[model_providers.*]` 和 `[[models]]` 段寫進你的 `config.toml` ——
**已有的注釋和設定會保留**。加 `--dry-run` 可以先看它打算寫什麼。

托管的 provider,從目錄裡裝一個再配上金鑰:

```shell
opencli provider list          # 目錄,加上已經配好的
opencli provider add openrouter
export OPENROUTER_API_KEY=...
```

**目錄裡只有連接訊息** —— 二進制裡不帶任何金鑰,而且在你加之前什麼都不生效。
要配目錄裡沒有的東西,按下面說的自己寫這些段。

#### 補上一個模型的能力

**本地模型的上下文視窗和工具調用支援,哪兒都沒公布**,而**猜比不填更糟** ——
上下文視窗填得太大,意味著 provider 直接拒掉這一輪,而不是自動壓縮。
**去問模型本人**:

```shell
opencli model probe <slug>            # 加 --dry-run 可以預覽
```

這會讀執行環境自己的元資料(**Ollama 會報出真實的上下文長度和能力清單**),
並且**額外發一次真實請求**,看這個模型會不會去調一個遞給它的工具、
以及會不會把思考放在單獨的 `reasoning` 字段裡返回。結果寫進該模型的 `[[models]]` 條目。

**完全不能聊天的模型** —— 比如 embedding 模型 —— 會被 `provider scan` 跳過,
所以它們永遠到不了 `/model` 選擇器裡。

### 選模型和 provider

這個構建內置了幾個網關的預設,但**任何能通過 OpenAI 兼容 API 連上的模型**,
都可以在 `~/.opencli/config.toml` 裡配好,**不用重新編譯**。

#### 加一個 provider

`[model_providers.<id>]` 裡的條目**會覆蓋同名的內置 provider**,
所以這也是把一個自帶網關重新指向某個代理或鏡像的辦法:

```toml
[model_providers.my-gateway]
name = "My Gateway"
base_url = "https://gateway.example.com/v1"
env_key = "MY_GATEWAY_API_KEY"
wire_api = "chat"
# 可選:這個網關吐第一個 token 很慢的話,調大它。
stream_idle_timeout_ms = 90000
```

**API 金鑰總是從環境變量讀,永遠不存進設定文件。**

#### 加一個模型

用 `[[models]]` 聲明模型。它們會出現在 `/model` 選擇器裡、挨著內置預設,
而**一個 `model` 與內置預設同名的條目會替換掉它**:

```toml
[[models]]
model = "qwen3-max"
provider = "my-gateway"
display_name = "Qwen3 Max"     # 可選,預設用 slug
description = "自建的。"        # 可選
show_in_picker = true          # 可選,預設 true
```

`provider` 必填,而且必須指向上面定義過的、或者一個內置的 provider;
**指向未定義 provider 的模型會在啟動時就被拒絕**,而不是過後帶著一個無關的錯誤失敗。

想選一個模型但不把它加進選擇器,直接設 `model` 和 `model_provider`:

```toml
model = "qwen3-max"
model_provider = "my-gateway"
```

如果 `model` 指的東西既不是內置預設也不是某個 `[[models]]` 條目,而 `model_provider`
又沒設,請求會退回到 `openai` provider,並記一條警告。

#### 上下文視窗

**這個構建沒有元資料的模型,從一個保守的 131,072 token 視窗開始**,
並從網關第一次「上下文視窗超了」的拒絕裡學到真實值。
設 `model_context_window` 可以把它釘死。

### 連接 MCP 伺服器

OpenCLI 可以連上在 `~/.opencli/config.toml` 裡聲明的 MCP 伺服器。

```toml
[mcp_servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env_vars = ["GITHUB_PERSONAL_ACCESS_TOKEN"]

[mcp_servers.internal]
url = "https://mcp.example.com/mcp"
```

`env_vars` 寫的是這個服務需要哪些變量;**值和你其他金鑰放在一起,而不是放進這個會被分享
出去的文件裡**。這裡聲明的服務,**在你下一次打開的聊天裡啟動,不是眼前這個。**

桌面端從 **Abilities → Connectors** 寫的是同一張表,**它還會測握手**,
並列出每個服務提供的工具。

### 應用(Connectors)

在輸入框裡用 `$` 插入一個 ChatGPT connector;彈出層會列出可用的應用。
`/apps` 命令列出可用和已裝的應用。**已連接的排在前面並標為已連接**,其餘標為可安裝。

### 通知

OpenCLI 可以在 agent 結束一輪時跑一個通知鈎子。

```toml
notify = ["/path/to/your/script.sh"]
```

這個程式被調用時帶一個參數:**一個描述發生了什麼的 JSON 對象**。
它是分離執行的,**所以一個慢指令碼不會拖住下一輪**,而一個失敗的指令碼只記日志、不彈到面前。

### JSON Schema

`config.toml` 生成的 JSON Schema 在
[`opencli-rs/core/config.schema.json`](https://github.com/ai-dashboad/opencli/blob/main/opencli-rs/core/config.schema.json),
**每個 release 都會帶上一份 `config-schema.json`**。手動改這個文件時,
把編輯器指過去就有補全和校驗。

**它是從 Rust 類型生成的,而且一旦和它們漂開 CI 就會紅** ——
所以**它是這個文件唯一不會過期的說明。**

### 提示開關

OpenCLI 把某些介面提示的「不再顯示」標記存在 `[notice]` 表裡。

Ctrl+C / Ctrl+D 退出用的是大約一秒內雙擊的提示(`ctrl + c again to quit`)。
