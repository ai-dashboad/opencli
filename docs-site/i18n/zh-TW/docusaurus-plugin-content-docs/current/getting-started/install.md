---
title: 安裝
sidebar_position: 1
---

# 安裝

## 桌面端

從 [opencli.ai/download](https://opencli.ai/download.html) 下載,或者直接從最新的
release 拿:

| 平臺 | 下載 |
| --- | --- |
| macOS · Apple 芯片 | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

每個連結指向的都是最新版本,所以換了版本它還是有效的。

裝完之後它會自己更新。

### 第一次打開,系統會警告你

這些安裝檔**沒有** Apple 或微軟的證書。那種證書要按年付費,這個專案還沒花這筆錢。
**下載本身沒有任何問題** —— 只是操作系統沒法判斷是誰做的。

**macOS** —— 把 OpenCLI 拖進「應用程式」之後,執行一次:

```shell
xattr -dr com.apple.quarantine /Applications/OpenCLI.app
```

或者右鍵點應用、選**打開**,再確認一次。只需要第一次這麼做。

**Windows** —— SmartScreen 會彈一個藍框。點 **More info**,再點 **Run anyway**。

## 命令列

一個二進制,macOS 和 Linux:

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

它會判斷你的平臺、下載對應的構建,把 `opencli` 放進 `/usr/local/bin` —— 如果沒有
寫權限,就退到 `~/.local/bin`,並提示你把它加進 `PATH`。

npm 包還沒發佈 —— `@ai-dashboad` 這個 scope 還沒注冊。在那之前,上面這個安裝指令碼和
桌面端是僅有的兩條路。

## 從源碼構建

需要一個較新的 Rust 工具鏈:

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

二進制在 `opencli-rs/target/release/opencli`。

## 它把東西寫在哪

| | |
| --- | --- |
| `~/.opencli/config.toml` | provider、模型、審批和沙箱設定 |
| `~/.opencli/workspace/` | 沒有別的指定時,對話從這裡開始 |
| `~/.opencli/skills/` | 技能,包括內置的那些 |
| `~/.opencli/locales/` | 你自己加的語言 |
| `~/.opencli/log/` | 日志 |

**在你把 agent 指向某個目錄之前,`~/.opencli` 之外不會被寫入任何東西。**

## 下一步

[指一個模型給它](/getting-started/point-at-a-model) —— 它不帶模型,
在有地方可問之前不會回答。
