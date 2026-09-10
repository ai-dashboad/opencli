---
title: 參與開發
sidebar_position: 3
---

# 參與開發

**歡迎提 PR,不用等誰邀請。** 這是個小專案;**有用的東西通常不是一個大功能**,
而是表裡的一行、翻譯裡的一句、或者一份詳細到能動手的 bug 報告。

## 最有用的貢獻

**模型表裡的一行。** [測一個模型](/reference/checking-a-model)是一個固定任務、
大約五分鐘。**那張表短,是因為它只放跑過的**,而**一個負面結果和正面結果一樣有價值** ——
沒人會發帖說那個不管用的模型,所以每個人都要重新發現一遍。

**一份翻譯,或者對某一份的一行修正。** 內置十種。其中任何一種都可以**一句一句地修正**,
不用動其餘的 —— 見[多語言](/configuration/languages)。**一種新語言就是一個 JSON 文件。**

**帶齊四樣東西的 bug 報告。** 模型和 provider **原樣寫**(Ollama 上的
`qwen3-coder:30b`,不是「一個本地模型」)、你讓它做什麼、發生了什麼、
以及 `~/.opencli/log` 裡失敗前後的五十行。**黏那些日志之前,先看看裡面有沒有金鑰。**

**告訴我們你實際想幹什麼。** 內置的那些部門和技能,是**從「猜人們需要什麼」寫出來的**。
**你伸手去找、卻沒找到的那個東西,是你能說的最有用的話。**

## 動手寫程式碼之前

**比一處修復更大的東西,先開一個 issue。** 不是設卡 —— 是為了在你搭進去一晚上之前
把做法談定。**沒有 issue 就直接來的 PR 一樣會被讀。**

## 環境

Rust 和 pnpm;工作區是 `opencli-rs/`,網頁介面是 `web/`,桌面外殼是 `desktop/`。

```shell
git clone https://github.com/ai-dashboad/opencli
cd opencli
pnpm install
cargo build -p opencli-cli
```

在儲存庫根目錄用 `just` 跑工作區的那些命令;`just help` 會列出來。

## 開 PR 之前

```shell
just fmt
just fix -p <crate>          # clippy,只跑你動過的 crate
cargo test -p <crate>
```

**不要直接跑 `cargo fmt`。** 這棵樹是用 `imports_granularity=Item` 格式化的,
而那是個 nightly 才有的選項。**在 stable 上它會被靜默忽略**,於是 `cargo fmt`
會重寫工作區裡幾乎每個文件的 import 塊,**把你的改動埋進上百個無關 diff 裡**。
`just fmt` 走 nightly,正是因為這個。沒有 nightly 工具鏈
(`rustup toolchain install nightly`)的話,只格式化你動過的文件,其餘交給 CI 確認。

如果你動了網頁介面,`python3 scripts/i18n-check.py` 會找出**從沒被包起來翻譯的英文** ——
包括那些容易漏掉的情況,比如被行內標簽劈開的文字,和在導入時就算好的標簽。

## 什麼樣的 PR 好合

- **一件事。** 無關的修復分開提。
- **一個在你改之前失敗、改之後通過的測試。** 不要求全覆蓋 ——
  一條本來能抓住這個 bug 的斷言就夠。
- **每個 commit 都能構建。** 這樣 review 和回滾才做得了。
- **行為變了就改文檔。** README、`opencli --help`、或者這裡那頁現在寫錯了的。
- 描述裡寫清 **做了什麼、為什麼、怎麼做**。**「為什麼」是 diff 裡讀不出來的那部分。**

## 沒有 CLA

**沒有什麼要簽的。** 貢獻同樣按
[Apache-2.0](https://github.com/ai-dashboad/opencli/blob/main/LICENSE)。

## 報告安全問題

**安全 bug 不要開公開 issue。** 用 GitHub 的
[私密通報表單](https://github.com/ai-dashboad/opencli/security/advisories/new),
它能送到維護者手裡而不公開任何東西。

**最值得看的地方**:sandbox 策略、審批路徑,以及任何決定「一次工具調用能碰什麼」的地方。
**一個讀你文件、在你機器上執行命令的 agent,面很大 —— 由你先找到它,好過別人先找到。**

## 好好說話

**尊重別人**;我們遵循 [Contributor Covenant](https://www.contributor-covenant.org/)。
**預設對方是善意的** —— 文字交流很難,**寧可往厚道那邊偏一點**。
如果有什麼讓人困惑,那本身就值得開一個 issue:**讓人看不懂的文檔,是文檔的 bug。**
