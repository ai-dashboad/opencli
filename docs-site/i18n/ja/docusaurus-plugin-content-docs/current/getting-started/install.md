---
title: インストール
sidebar_position: 1
---

# インストール

## デスクトップアプリ

[opencli.ai/download](https://opencli.ai/download.html) から、
または最新リリースから直接:

| プラットフォーム | ダウンロード |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

**どのリンクも常に最新のリリースを指す**ので、バージョンが変わってもそのまま使えます。

そのあとは**アプリが自分で更新します**。

### 初回はコンピューターが警告を出します

これらのビルドは Apple や Microsoft の証明書で**署名されていません**。
証明書は年ごとにお金がかかり、このプロジェクトはそれを払っていません。
**ダウンロードしたものに問題はありません** —— OS が誰のビルドか判別できないだけです。

**macOS** —— OpenCLI をアプリケーションにドラッグしたあと、一度だけ実行するか:

```shell
xattr -dr com.apple.quarantine /Applications/OpenCLI.app
```

アプリを右クリックして **開く** を選び、確認します。**初回だけ**です。

**Windows** —— SmartScreen が青い画面を出します。**詳細情報** をクリックし、
**実行** を選びます。

## コマンドライン

バイナリ一つ、macOS と Linux:

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

**プラットフォームを判別**し、対応するビルドを取得して、`opencli` を `/usr/local/bin` に置きます ——
そこに書けない場合は `~/.local/bin` に置き、`PATH` に足すよう伝えます。

**npm パッケージはまだ公開されていません** —— `@ai-dashboad` スコープが未登録だからです。
登録されるまでは、**上のインストーラーとデスクトップ版の二つ**が経路です。

## ソースから

新しめの Rust ツールチェーン:

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

バイナリは `opencli-rs/target/release/opencli` にできます。

## どこに何を書いたか

| | |
| --- | --- |
| `~/.opencli/config.toml` | 供給元、モデル、承認とサンドボックスの設定 |
| `~/.opencli/workspace/` | ほかに指定がないとき対話が始まる場所 |
| `~/.opencli/skills/` | スキル。同梱のものも含む |
| `~/.opencli/locales/` | あなたが足した言語 |
| `~/.opencli/log/` | ログ |

**あなたがエージェントをどこかのディレクトリに向けるまで、`~/.opencli` の外には何も書きません。**

## 次

[モデルを指定する](/getting-started/point-at-a-model) —— モデルは同梱しておらず、
**訊きに行く先がないうちは答えません**。
