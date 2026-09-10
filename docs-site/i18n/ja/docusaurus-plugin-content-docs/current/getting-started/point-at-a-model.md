---
title: モデルを指定する
sidebar_position: 2
---

# モデルを指定する

**OpenCLI にはモデルも鍵も入っていません。** 新規インストールの最初の画面はそう伝え、
下の二つの経路を出します。

**これは統合の一覧ではなく、一つのプロトコルです。** OpenAI と同じように
`/v1/chat/completions` と `/v1/models` に答えるものなら何でも指定でき、
**そのモデルは選択リストに自分から現れます**。一つずつ宣言する必要はありません。

## このマシンの中で

デスクトップアプリが入れてくれます:**Models** を開くと、
何かを取ってこようと言う前に**すでにマシンにあるものを見ます**。

手でやるなら、[Ollama](https://ollama.com) が動いている前提で:

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

これを `~/.opencli/config.toml` に置いて `opencli` を実行します。

**何もマシンの外に出ませんし、預かる鍵もありません。**

## 供給元を使う

**どの供給元も同じやり方です。** 型は、ベース URL と、鍵の入った環境変数の名前:

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

デスクトップアプリでは同じことを **Settings** で行い、
**鍵は保存され、二度と表示されません**。

### 大きなモデルを試す一番安い方法が無料枠です

いくつかの供給元は無料で出しており、**自分のマシンには載らないほど大きなモデル**を
そうやって動かせます。何が無料かは月ごとに変わるので、このページは金額を書きません ——
**各社の価格ページを見てください**。

[README](https://github.com/ai-dashboad/opencli#where-the-model-comes-from)
に供給元の全一覧があります。**一社ずつモデル一覧を訊いて確かめたもの**です。

## モデルは、作った会社から来るとは限りません

小米は MiMo を、字節跳動は Seed を出していますが、**どちらも自前の公開 OpenAI 互換
エンドポイントを持っていません**。両方とも他社が載せています —— つまり MiMo には
OpenRouter、Novita、DeepInfra、PPIO、Hugging Face 経由で届くのであって、
小米経由ではありません。

## 届くことと、これが得意なことは別です

**OpenAI API には答えるがツール呼び出しの部分には答えない供給元は、話をするだけ**です:
このエージェントはツールを呼ぶことで働きます。あるモデルに腰を据える前に
[試してください](/reference/checking-a-model) —— **五分、固定された課題ひとつ**です。

## 次

[最初の対話](/getting-started/first-conversation)。
