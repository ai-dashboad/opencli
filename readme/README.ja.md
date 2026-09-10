<div align="center">

<img src="../website/public/favicon.svg" width="80" alt="OpenCLI" />

# OpenCLI

**自分で動かすモデルのための、オープンソースのエージェント**

[![CI](https://img.shields.io/github/actions/workflow/status/ai-dashboad/opencli/rust-ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/ai-dashboad/opencli/actions/workflows/rust-ci.yml)
[![Release](https://img.shields.io/github/v/release/ai-dashboad/opencli?style=flat-square)](https://github.com/ai-dashboad/opencli/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ai-dashboad/opencli/total?style=flat-square)](https://github.com/ai-dashboad/opencli/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat-square)](../LICENSE)

[English](../README.md) ·
[简体中文](./README.zh-CN.md) ·
[繁體中文](./README.zh-TW.md) ·
**日本語** ·
[한국어](./README.ko.md) ·
[Español](./README.es.md) ·
[Português](./README.pt-BR.md) ·
[Français](./README.fr.md) ·
[Deutsch](./README.de.md) ·
[Русский](./README.ru.md)

[ダウンロード](https://opencli.ai/download.html) ·
[ドキュメント](https://docs.opencli.ai) ·
[はじめに](https://docs.opencli.ai/getting-started/install) ·
[プロバイダ](https://docs.opencli.ai/getting-started/providers) ·
[できないこと](https://docs.opencli.ai/reference/limits)

</div>

OpenCLI は自分のコンピュータで動くエージェントで、OpenAI 互換のモデルなら何でも使えます — 目の前のマシンにあるもの、自分のサーバーにあるもの、あるいは必要なときにホスティングされたプロバイダのもの。ファイルを読み、コマンドを実行し、作業中のものを編集します。ターミナルとデスクトップアプリは同じ会話を共有します。

**何も組み込まれていません。** モデルもアカウントも鍵もなく、推論をどこから買うかについての立場もありません。エンドポイントを指定すればそのモデルが自動的に現れ、入力したものはそこにだけ送られます。

## ダウンロード

| プラットフォーム | |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

インストール後は自動で更新されます。これらのビルドには Apple / Microsoft の証明書がないため、初回起動だけ一手間かかります — [その手順](https://docs.opencli.ai/getting-started/install).

**コマンドライン、macOS と Linux:**

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

そのあとモデルを指定してください。

## できること

- 🗂 **コードだけでなくファイルの仕事を。** 請求書の入ったフォルダを読むのも、リポジトリを読むのも同じことです — そして実際の仕事の多くは前者です。

- 🏢 **会社のように組み立てられています。** **部門**は常設の指示が付いたディレクトリ、**ボット**はその中の会話で、役割を持っています。九つの部門がサンプルデータ付きで用意されているので、設定する前に試せます。

- ⏰ **当番は自分で時間になり** — 自分だけで決めるべきでないことに行き当たると**手を止めてあなたに尋ねます**。その線引きは前もって言葉で書いておきます：*一件でも 10,000 を超えたら*。

- 🤝 **ボット同士が仕事を渡し合い、** 何をしたか、どんなファイルを作ったかも一緒に渡します。八ホップまで、各ボット三回までなので、連鎖が暴走することはありません。

- 🧰 **六つのワークフローがスキルとして同梱され、** どのディレクトリでも使えます：表を規則に照らして点検する、一週間で何が変わったかを報告する、受信箱を仕分ける、二つの草案を比べる、書き起こしを決定と担当者に変える、記録を読んで確認すべき点を挙げる。

- 🔌 **コネクタは MCP サーバーです** — GitHub、Postgres、Slack、Notion、ブラウザ。鍵は設定ファイルとは別に保管されます。設定ファイルは共有されるものだからです。

- 🚦 **境界の見えるサンドボックス。** 実行は自分のディレクトリの中にしか書き込めません。見慣れない場所を指した実行は、その場所を名指しで許可するまで保留されます。

- 🌍 **十の言語、** それ以外はどれも JSON ファイル一つで、何も再ビルドせずに追加できます。

- 💻 **ターミナル、デスクトップ、ローカルの Web UI が** 同じゲートウェイを共有するので、一方で始めた会話をもう一方で続けられます。

## つながる先

三十の連携ではなく、**一つのプロトコル**です。`/v1/chat/completions` と `/v1/models` に OpenAI と同じ形で答えるものなら何でも指定でき、そのモデルは自動的に現れます。以下の各エンドポイントは、掲載前に実際にモデル一覧を尋ねて確認しています。

**あなたのマシンで** — Ollama · LM Studio · llama.cpp · LocalAI · Jan ·
Xinference · KoboldCpp · llamafile

**あなたのサーバーで** — vLLM · SGLang · Text Generation Inference · NVIDIA NIM ·
LiteLLM

**オープンモデルをホストしている** — Fireworks · Together · Groq · DeepInfra · Baseten ·
Novita · Hyperbolic · Nebius · Cerebras · SambaNova · Featherless · Chutes ·
NVIDIA · Hugging Face · OpenRouter · Vercel AI Gateway · Perplexity

**中国** — 硅基流动 · 无问芯穹 · PPIO · 七牛云 · 魔搭 · 阿里云百炼 ·
火山方舟 / 豆包 · 百度千帆 · 讯飞星火 · 小米 MiMo · DeepSeek · 智谱 ·
月之暗面 · MiniMax · 阶跃星辰 · 腾讯混元 · 百川

**クローズドなモデル、必要なときに** — OpenAI · Anthropic · Mistral · xAI

**いくつかは無料枠を出しています。** 自分のマシンに載らないほど大きなモデルを試すには、それが一番安上がりです。エンドポイントと、どのモデルをどこが提供しているか： [プロバイダ](https://docs.opencli.ai/getting-started/providers).

> **つながることと、この仕事ができることは別です。** ツールを呼べるかどうかが、仕事のできるモデルと話すだけのモデルを分けます。そしてモデルカードには書かれていません。
> [自分のを試す](https://docs.opencli.ai/reference/checking-a-model) —
> 決まった課題ひとつ、五分。表が一行しかないのは、一つしか動かしていないからです — **行を足すことが、いま最も役に立つ貢献です。**

## できないこと

- **汎用のオープンモデルは、ファイル用のツールがあっても `grep` に手を伸ばします。** モデル側の差であり、どんなインターフェースでも埋められません。
- **トークン数は推定であり、数えたものではありません。** トークナイザはモデルのものであり、これは見たこともないモデルを動かします。
- **定期実行は OpenCLI が開いている間だけ動きます。** これはローカルのエージェントであってサーバーではありません。
- **バックグラウンド実行は、自分のディレクトリの中なら何でも書き換えられます。**
- **デスクトップ版に署名はありません。** OS が警告するのは正しいことです。
- **右から左に書く言語のレイアウトはまだありません。**

[できないこと](https://docs.opencli.ai/reference/limits) に、それぞれの理由が書いてあります。

## これがどこから来たか

[OpenAI の Codex CLI](https://github.com/openai/codex) のフォークです。Copyright 2025 OpenAI、Apache-2.0。**OpenAI とは無関係です。**

Codex は OpenAI のモデルのために作られ、これはそれ以外のみんなのために作られています — 変わるのは名前だけではありません。部門、ボット、当番、バックグラウンド実行、そしてワークフローはこちらのものです。モデルが小さいときに何が壊れるかにも相当の手を入れました：十一ターン続けて毎ターン要約し、そのたびに文脈を捨てていた圧縮ループと、中国語一ページを実際の三分の四に読んでいたトークン推定です。

[Apache-2.0](../LICENSE) · [NOTICE](../NOTICE) ·
[開発に参加する](https://docs.opencli.ai/reference/contributing)
