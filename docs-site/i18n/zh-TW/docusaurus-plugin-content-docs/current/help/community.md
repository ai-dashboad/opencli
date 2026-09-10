---
title: 求助
sidebar_position: 4
---

# 求助,以及去哪裡說話

## 問之前

**頭一周會出的問題,大半在[故障排查](/help/troubleshooting)裡**,而「我的 provider
支援嗎」的答案在[供應商](/getting-started/providers)。

如果 agent 會說話但從不碰你的文件,**那幾乎總是模型的問題而不是設定的問題** ——
在花一晚上折騰設定之前,[先測它](/reference/checking-a-model)。

## 去哪裡問

**[GitHub Issues](https://github.com/ai-dashboad/opencli/issues)** —— bug,以及任何
**表現和文檔寫的不一樣**的地方。

**[GitHub Discussions](https://github.com/ai-dashboad/opencli/discussions)** —— 問題、
想法、以及「這是不是本來就該這樣」。

**還沒有聊天群。** 等人多到值得開一個的時候會有;**一個空房間幫不了任何人。**

## 什麼樣的報告好處理

四行,而大多數報告沒有:

1. **模型和 provider**,**原樣寫** —— Ollama 上的 `qwen3-coder:30b`,不是「一個本地模型」。
2. **你讓它做什麼**,原話。
3. **發生了什麼**,以及你以為會發生什麼。
4. **`~/.opencli/log` 裡失敗前後的五十行。**

**黏那些日志之前,先看看裡面有沒有金鑰。**

## 最有幫助的是什麼

**給模型表加一行。** [測一個模型](/reference/checking-a-model)是一個固定任務、大約五分鐘。
那張表短是因為它只放跑過的,而**一個負面結果和正面結果一樣有價值** —— 沒人會發帖說那個
不管用的模型,**所以每個人都要重新發現一遍**。

**一份翻譯,或者對某一份的一處修正。** 內置十種。其中任何一種都可以**一行一行地修正**,
不用動其餘的 —— 見[多語言](/configuration/languages)。

**告訴我們你實際想幹什麼。** 內置的那些部門和流程,是**從「猜人們需要什麼」寫出來的**。
**你伸手去找、卻沒找到的那個東西,是你能說的最有用的話。**

## 貢獻程式碼

[參與開發](/reference/contributing)裡有環境搭建和 PR 流程。
