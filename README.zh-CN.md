<p align="center">
  <img src="website/public/favicon.svg" width="72" alt="OpenCLI" />
</p>

<h3 align="center">给那些没有自己 agent 的模型</h3>

<p align="center">
  <a href="https://docs.opencli.ai"><b>文档</b></a> ·
  <a href="https://opencli.ai/download.html"><b>下载</b></a> ·
  <a href="./README.md"><b>English</b></a>
</p>

---

Claude 有 Claude Code,OpenAI 有 Codex,Gemini 有自己的 CLI。**你真正跑得动的
那些模型 —— Qwen、DeepSeek、GLM、Llama、MiMo —— 一个都没有。**

OpenCLI 就是它们的那一个。一个终端 agent 加一个桌面应用,指向任何 OpenAI 兼容的
接口:你面前这台机器上的模型、你自己的网关,或者你愿意用的时候接一个在线服务。
不自带模型,不需要账号,不内置密钥。

**不用翻墙,不用付费,你输入的东西不离开这台机器。**

## 安装

```shell
curl -fsSL https://opencli.ai/install.sh | sh    # macOS 和 Linux
npm install -g @ai-dashboad/opencli              # 任何能跑 Node 的地方
```

桌面端(macOS / Windows / Linux):[opencli.ai/download](https://opencli.ai/download.html)。
安装包没有代码签名,**系统第一次会警告你** ——
[怎么办](https://docs.opencli.ai/getting-started/install)。

然后[指一个模型给它](https://docs.opencli.ai/getting-started/point-at-a-model)。

## 它不只是写代码的

这个 agent 会读文件、执行命令、修改内容。这件事对一个装满发票的文件夹,和对一个
代码仓库同样成立 —— 而大多数人手上真正的活儿是前一种。

所以桌面端是按一间公司的样子组织的。**部门**是一个目录加一份常设说明,**Bot**
是部门里的一个会话、带着一份职责,**值守**是一份会自己到点、卡住了会来问你的工作。

九个部门带样例数据一起装好 —— 财务、客服、运营、市场、人事、法务、研究、病历、
研发 —— 每一项都可以先试再配。另有六个流程作为技能内置,在任何目录都能用:
**按规则核查一张表**、**周报**、**收件箱分拣**、**两版文档比对**、
**会议纪要转成决定和负责人**、**档案审阅**。

→ [部门与 Bot](https://docs.opencli.ai/doing-work/departments-and-bots)

## 模型从哪来

**这是一个协议,不是一张对接清单。** 任何按 OpenAI 的方式回答
`/v1/chat/completions` 和 `/v1/models` 的地址都能指过去,它的模型会自动出现。

四十来家逐个问过模型列表验证过 —— 本机运行时、自建服务、托管开源模型的、国内的、
以及闭源模型。**其中不少家给免费额度**,那是用比你机器装得下更大的模型试这个东西
最便宜的办法。

→ [供应商](https://docs.opencli.ai/getting-started/providers)

## 哪些模型真的能用

**能连上不等于干得了这活儿。** 会不会调用工具,是「能干活」和「只能聊」之间的分水岭,
而模型卡上从来不写。

一个固定任务,五分钟。表里只有一行,因为只跑过一个模型。
**给它加一行是你能做的最有用的贡献。**

→ [测一个模型](https://docs.opencli.ai/reference/checking-a-model)

## 它做不到什么

- **通用开源模型手上有文件工具,还是会去用 `grep`。** 这是模型的差距,换任何界面都补不上。
- **token 数是估算的,从来不是数出来的。** 分词器属于模型,而这个程序要跑它从没见过的模型。
- **定时的活儿只在 OpenCLI 开着时执行。** 它是本地 agent,不是服务器。
- **一次后台运行可以写它所在目录里的任何东西。** 沙箱的可写根**就是**那个目录。
- **桌面端没有代码签名。** 系统警告你是对的。

→ [做不到什么](https://docs.opencli.ai/reference/limits),每一条都写了为什么。

## 这个项目从哪来

fork 自 [OpenAI 的 Codex CLI](https://github.com/openai/codex),版权归 OpenAI
所有(2025),Apache-2.0。**与 OpenAI 无关联。**

Codex 是为 OpenAI 的模型做的,而这个是为别人的模型做的 —— 这件事改变的不只是一个
名字。部门、Bot、值守、后台运行,以及那些流程,都是这边加的。还有相当一部分工作
是在处理「模型小了会坏在哪里」:一个连着十一轮每轮都压缩一次的死循环;以及一个
把一整页中文读成实际成本四分之三的 token 估算。

本项目使用 [Apache-2.0](LICENSE) 协议,完整归属见 [NOTICE](NOTICE)。
参与开发:[CONTRIBUTING](https://docs.opencli.ai/reference/contributing)。
