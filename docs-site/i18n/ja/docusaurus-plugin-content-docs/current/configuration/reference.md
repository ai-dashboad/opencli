---
title: 完全な設定リファレンス
sidebar_position: 4
---

# 完全な設定リファレンス

`~/.opencli/config.toml` が受け付けるすべてのキー。**大半の人が触るのはごく一部**で、
それは[設定ファイル](/configuration/config-file)にあり、そちらはずっと短いです。

### 一番早い道:OpenCLI にモデルを見つけさせる

すでに Ollama、LM Studio、vLLM、llama.cpp をローカルで動かしているなら:

```shell
opencli provider scan
```

**これは通例の localhost ポートを探り**、見つけたサーバーそれぞれに何を提供しているか訊いて、
対応する `[model_providers.*]` と `[[models]]` を `config.toml` に書き込みます ——
**既存のコメントと設定は保たれます**。`--dry-run` を足すと、何を書くつもりか先に見られます。

ホスト型の供給元は、カタログから一つ入れて鍵を設定します:

```shell
opencli provider list          # カタログと、すでに設定済みのもの
opencli provider add openrouter
export OPENROUTER_API_KEY=...
```

**カタログには接続情報しかありません** —— バイナリに鍵は同梱されず、
**あなたが足すまで何も有効になりません**。カタログにないものを設定するには、
下のとおり自分でこれらの節を書きます。

#### モデルの能力を埋める

**ローカルモデルのコンテキストウィンドウとツール呼び出しの可否は、どこにも公表されていません。**
そして**当てずっぽうは、未設定より悪い**です —— コンテキストウィンドウが大きすぎると、
供給元は自動圧縮する代わりにそのターンを**拒否**します。**モデル本人に訊いてください**:

```shell
opencli model probe <slug>            # --dry-run を足すと下見できます
```

**利用できる場合は実行環境自身のメタデータを読み**(**Ollama は本物のコンテキスト長と能力一覧を
報告します**)、さらに**実際のリクエストを一度送って**、差し出したツールを呼ぶかどうか、
思考を別の `reasoning` フィールドで返すかどうかを見ます。分かったことはそのモデルの
`[[models]]` に書き込まれます。

**そもそも会話ができないモデル** —— 例えば埋め込みモデル —— は `provider scan` に飛ばされるので、
`/model` の選択リストには決して届きません。

### モデルと供給元を選ぶ

このビルドはいくつかのゲートウェイのプリセットを同梱していますが、
**OpenAI 互換 API で届くモデルなら何でも** `~/.opencli/config.toml` で設定でき、
**再ビルドは要りません**。

#### 供給元を足す

`[model_providers.<id>]` の項目は**同じ id の内蔵供給元を上書きします**。
ですからこれは、**同梱のゲートウェイをプロキシやミラーに向け直す方法**でもあります:

```toml
[model_providers.my-gateway]
name = "My Gateway"
base_url = "https://gateway.example.com/v1"
env_key = "MY_GATEWAY_API_KEY"
wire_api = "chat"
# 任意: このゲートウェイが最初のトークンを吐くのが遅いなら上げてください。
stream_idle_timeout_ms = 90000
```

**API 鍵は常に環境変数から読まれ、設定ファイルに保存されることはありません。**

#### モデルを足す

`[[models]]` でモデルを宣言します。内蔵プリセットの隣で `/model` の選択リストに現れ、
**`model` が内蔵プリセットと一致する項目はそれを置き換えます**:

```toml
[[models]]
model = "qwen3-max"
provider = "my-gateway"
display_name = "Qwen3 Max"     # 任意。既定は slug
description = "自前で動かしています。" # 任意
show_in_picker = true          # 任意。既定は true
```

`provider` は必須で、上で定義した供給元か内蔵のものを指す必要があります。
**未定義の供給元を指すモデルは起動時に弾かれます** ——
あとで無関係なエラーとともに失敗する代わりに。

選択リストに入れずにモデルを選ぶには、`model` と `model_provider` を直に設定します:

```toml
model = "qwen3-max"
model_provider = "my-gateway"
```

`model` が内蔵プリセットでも `[[models]]` の項目でもないものを指していて、
`model_provider` も未設定なら、リクエストは `openai` 供給元に落ち、警告が記録されます。

#### コンテキストウィンドウ

**このビルドにメタデータのないモデルは、控えめな 131,072 トークンの窓から始まり**、
ゲートウェイからの**最初の「窓を超えた」拒否から本物の値を学びます**。
`model_context_window` を設定すれば明示的に固定できます。

### MCP サーバーにつなぐ

OpenCLI は `~/.opencli/config.toml` で宣言された MCP サーバーにつなげます。

```toml
[mcp_servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env_vars = ["GITHUB_PERSONAL_ACCESS_TOKEN"]

[mcp_servers.internal]
url = "https://mcp.example.com/mcp"
```

`env_vars` はそのサーバーが必要とする変数の名前です。
**値は、共有されるこのファイルではなく、あなたの他の鍵と一緒に保管されます。**
ここで宣言したサーバーは、**目の前の対話ではなく、次に開く対話**とともに起動します。

デスクトップアプリは **Abilities → Connectors** から同じ表を書き、
**握手のテスト**と、各サーバーが提供するツールの一覧も行います。

### アプリ(Connectors)

入力欄で `$` を使うと ChatGPT のコネクターを挿入できます。ポップオーバーが使えるアプリを並べます。
`/apps` コマンドは使用可能なアプリと導入済みのアプリを並べます。
**接続済みのものが先に来て「接続済み」と表示され**、それ以外は「導入可能」と印がつきます。

### 通知

OpenCLI は、エージェントが一巡を終えたときに通知フックを走らせられます。

```toml
notify = ["/path/to/your/script.sh"]
```

そのプログラムは引数一つで呼ばれます:**何が起きたかを述べる JSON オブジェクト**。
**切り離して実行される**ので、**遅いスクリプトが次の一巡を止めることはなく**、
失敗したスクリプトは表に出るのではなく記録されます。

### JSON スキーマ

`config.toml` から生成された JSON スキーマは
[`opencli-rs/core/config.schema.json`](https://github.com/ai-dashboad/opencli/blob/main/opencli-rs/core/config.schema.json)
にあり、**リリースごとに `config-schema.json` として同梱されます**。
手でこのファイルを編集するとき、エディターをそこに向ければ補完と検証が効きます。

**これは Rust の型から生成され、型と食い違えば CI が落ちます** ——
つまり**このファイルについての、唯一古びない説明**です。

### 通知の抑止

OpenCLI は一部の画面のプロンプトについて「二度と表示しない」フラグを `[notice]` 表に保存します。

Ctrl+C / Ctrl+D での終了は、およそ一秒以内の二度押しをうながす表示を使います
(`ctrl + c again to quit`)。
