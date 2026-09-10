---
title: 安装
sidebar_position: 1
---

# 安装

## 桌面端

从 [opencli.ai/download](https://opencli.ai/download.html) 下载,或者直接从最新的
release 拿:

| 平台 | 下载 |
| --- | --- |
| macOS · Apple 芯片 | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

每个链接指向的都是最新版本,所以换了版本它还是有效的。

装完之后它会自己更新。

### 第一次打开,系统会警告你

这些安装包**没有** Apple 或微软的证书。那种证书要按年付费,这个项目还没花这笔钱。
**下载本身没有任何问题** —— 只是操作系统没法判断是谁做的。

**macOS** —— 把 OpenCLI 拖进「应用程序」之后,执行一次:

```shell
xattr -dr com.apple.quarantine /Applications/OpenCLI.app
```

或者右键点应用、选**打开**,再确认一次。只需要第一次这么做。

**Windows** —— SmartScreen 会弹一个蓝框。点 **More info**,再点 **Run anyway**。

## 命令行

一个二进制,macOS 和 Linux:

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

它会判断你的平台、下载对应的构建,把 `opencli` 放进 `/usr/local/bin` —— 如果没有
写权限,就退到 `~/.local/bin`,并提示你把它加进 `PATH`。

npm 包还没发布 —— `@ai-dashboad` 这个 scope 还没注册。在那之前,上面这个安装脚本和
桌面端是仅有的两条路。

## 从源码构建

需要一个较新的 Rust 工具链:

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

二进制在 `opencli-rs/target/release/opencli`。

## 它把东西写在哪

| | |
| --- | --- |
| `~/.opencli/config.toml` | provider、模型、审批和沙箱设置 |
| `~/.opencli/workspace/` | 没有别的指定时,对话从这里开始 |
| `~/.opencli/skills/` | 技能,包括内置的那些 |
| `~/.opencli/locales/` | 你自己加的语言 |
| `~/.opencli/log/` | 日志 |

**在你把 agent 指向某个目录之前,`~/.opencli` 之外不会被写入任何东西。**

## 下一步

[指一个模型给它](/getting-started/point-at-a-model) —— 它不带模型,
在有地方可问之前不会回答。
