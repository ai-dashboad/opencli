---
title: 参与开发
sidebar_position: 3
---

# 参与开发

**欢迎提 PR,不用等谁邀请。** 这是个小项目;**有用的东西通常不是一个大功能**,
而是表里的一行、翻译里的一句、或者一份详细到能动手的 bug 报告。

## 最有用的贡献

**模型表里的一行。** [测一个模型](/reference/checking-a-model)是一个固定任务、
大约五分钟。**那张表短,是因为它只放跑过的**,而**一个负面结果和正面结果一样有价值** ——
没人会发帖说那个不管用的模型,所以每个人都要重新发现一遍。

**一份翻译,或者对某一份的一行修正。** 内置十种。其中任何一种都可以**一句一句地修正**,
不用动其余的 —— 见[多语言](/configuration/languages)。**一种新语言就是一个 JSON 文件。**

**带齐四样东西的 bug 报告。** 模型和 provider **原样写**(Ollama 上的
`qwen3-coder:30b`,不是「一个本地模型」)、你让它做什么、发生了什么、
以及 `~/.opencli/log` 里失败前后的五十行。**粘那些日志之前,先看看里面有没有密钥。**

**告诉我们你实际想干什么。** 内置的那些部门和技能,是**从「猜人们需要什么」写出来的**。
**你伸手去找、却没找到的那个东西,是你能说的最有用的话。**

## 动手写代码之前

**比一处修复更大的东西,先开一个 issue。** 不是设卡 —— 是为了在你搭进去一晚上之前
把做法谈定。**没有 issue 就直接来的 PR 一样会被读。**

## 环境

Rust 和 pnpm;工作区是 `opencli-rs/`,网页界面是 `web/`,桌面外壳是 `desktop/`。

```shell
git clone https://github.com/ai-dashboad/opencli
cd opencli
pnpm install
cargo build -p opencli-cli
```

在仓库根目录用 `just` 跑工作区的那些命令;`just help` 会列出来。

## 开 PR 之前

```shell
just fmt
just fix -p <crate>          # clippy,只跑你动过的 crate
cargo test -p <crate>
```

**不要直接跑 `cargo fmt`。** 这棵树是用 `imports_granularity=Item` 格式化的,
而那是个 nightly 才有的选项。**在 stable 上它会被静默忽略**,于是 `cargo fmt`
会重写工作区里几乎每个文件的 import 块,**把你的改动埋进上百个无关 diff 里**。
`just fmt` 走 nightly,正是因为这个。没有 nightly 工具链
(`rustup toolchain install nightly`)的话,只格式化你动过的文件,其余交给 CI 确认。

如果你动了网页界面,`python3 scripts/i18n-check.py` 会找出**从没被包起来翻译的英文** ——
包括那些容易漏掉的情况,比如被行内标签劈开的文字,和在导入时就算好的标签。

## 什么样的 PR 好合

- **一件事。** 无关的修复分开提。
- **一个在你改之前失败、改之后通过的测试。** 不要求全覆盖 ——
  一条本来能抓住这个 bug 的断言就够。
- **每个 commit 都能构建。** 这样 review 和回滚才做得了。
- **行为变了就改文档。** README、`opencli --help`、或者这里那页现在写错了的。
- 描述里写清 **做了什么、为什么、怎么做**。**「为什么」是 diff 里读不出来的那部分。**

## 没有 CLA

**没有什么要签的。** 贡献同样按
[Apache-2.0](https://github.com/ai-dashboad/opencli/blob/main/LICENSE)。

## 报告安全问题

**安全 bug 不要开公开 issue。** 用 GitHub 的
[私密通报表单](https://github.com/ai-dashboad/opencli/security/advisories/new),
它能送到维护者手里而不公开任何东西。

**最值得看的地方**:sandbox 策略、审批路径,以及任何决定「一次工具调用能碰什么」的地方。
**一个读你文件、在你机器上执行命令的 agent,面很大 —— 由你先找到它,好过别人先找到。**

## 好好说话

**尊重别人**;我们遵循 [Contributor Covenant](https://www.contributor-covenant.org/)。
**默认对方是善意的** —— 文字交流很难,**宁可往厚道那边偏一点**。
如果有什么让人困惑,那本身就值得开一个 issue:**让人看不懂的文档,是文档的 bug。**
