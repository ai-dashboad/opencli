---
title: 設定ファイル
sidebar_position: 1
---

# 設定ファイル

`~/.opencli/config.toml`。**ここにあるものはすべて既定値を持っています**。
ファイルが抱えるのは、**あなたが変えたものだけ**です。

**デスクトップアプリは同じファイルに、あなたのコメントと書式を保ったまま書きます。**
ですから**手で編集することと Settings で編集することは同じ行為**です。

## 供給元とモデル

**供給元とは、ベース URL と、鍵の入った環境変数の名前**です:

```toml
[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

その下で宣言したモデルが選択リストに現れます:

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

`slug` は**あなたが打つ名前**、`model` は**供給元がそれを呼ぶ名前**です。
**分けておく価値があるくらい、両者はよく食い違います。**

**宣言しなくても構いません。** モデルは供給元の `/v1/models` から取ってきます。
宣言するのは、**コンテキストウィンドウ、表示名、受け付ける努力度を固定したいとき**です。

## 承認とサンドボックス

```toml
approval_policy = "on-failure"   # untrusted | on-failure | never
sandbox_mode = "workspace-write" # read-only | workspace-write | danger-full-access
```

[サンドボックスと承認](/configuration/sandbox-and-approvals)で説明しています。

## ツールの出力

```toml
tool_output_token_limit = 10000
```

**ツールの出力が対話に足してよい量の予算**です。

**トークンは数えるのではなく見積もります。** トークナイザーはモデルのものであり、
**これは見たこともないモデルを走らせます**。見積もりは **ASCII 四バイトで一トークン、
それ以外は一文字一トークン** —— **英語にも中国語にも近く**、その他では多めに数える側に寄せます。
これを 500 にしても**ちょうど 500 トークンで切るわけではありません**。
**その近くで、この数字と同じ単位で切ります。**

## 今何が効いているかを見る

**Settings** は、**あなたが一度も設定していないものも含めて**、適用されている値と
**それがどこから来たか**をすべて表示します。`Show raw config` はファイルそのものです。

## 完全な参考資料

このファイルが受け付けるすべてのキーと、その既定値:
[完全な設定リファレンス](/configuration/reference)。
