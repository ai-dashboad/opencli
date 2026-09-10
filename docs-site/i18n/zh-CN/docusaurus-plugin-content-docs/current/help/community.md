---
title: 求助
sidebar_position: 4
---

# 求助,以及去哪里说话

## 问之前

**头一周会出的问题,大半在[故障排查](/help/troubleshooting)里**,而「我的 provider
支持吗」的答案在[供应商](/getting-started/providers)。

如果 agent 会说话但从不碰你的文件,**那几乎总是模型的问题而不是配置的问题** ——
在花一晚上折腾配置之前,[先测它](/reference/checking-a-model)。

## 去哪里问

**[GitHub Issues](https://github.com/ai-dashboad/opencli/issues)** —— bug,以及任何
**表现和文档写的不一样**的地方。

**[GitHub Discussions](https://github.com/ai-dashboad/opencli/discussions)** —— 问题、
想法、以及「这是不是本来就该这样」。

**还没有聊天群。** 等人多到值得开一个的时候会有;**一个空房间帮不了任何人。**

## 什么样的报告好处理

四行,而大多数报告没有:

1. **模型和 provider**,**原样写** —— Ollama 上的 `qwen3-coder:30b`,不是「一个本地模型」。
2. **你让它做什么**,原话。
3. **发生了什么**,以及你以为会发生什么。
4. **`~/.opencli/log` 里失败前后的五十行。**

**粘那些日志之前,先看看里面有没有密钥。**

## 最有帮助的是什么

**给模型表加一行。** [测一个模型](/reference/checking-a-model)是一个固定任务、大约五分钟。
那张表短是因为它只放跑过的,而**一个负面结果和正面结果一样有价值** —— 没人会发帖说那个
不管用的模型,**所以每个人都要重新发现一遍**。

**一份翻译,或者对某一份的一处修正。** 内置十种。其中任何一种都可以**一行一行地修正**,
不用动其余的 —— 见[多语言](/configuration/languages)。

**告诉我们你实际想干什么。** 内置的那些部门和流程,是**从「猜人们需要什么」写出来的**。
**你伸手去找、却没找到的那个东西,是你能说的最有用的话。**

## 贡献代码

[参与开发](/reference/contributing)里有环境搭建和 PR 流程。
