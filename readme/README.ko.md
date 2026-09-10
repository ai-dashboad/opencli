<div align="center">

<img src="../website/public/favicon.svg" width="80" alt="OpenCLI" />

# OpenCLI

**직접 돌리는 모델을 위한 오픈소스 에이전트**

[![CI](https://img.shields.io/github/actions/workflow/status/ai-dashboad/opencli/rust-ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/ai-dashboad/opencli/actions/workflows/rust-ci.yml)
[![Release](https://img.shields.io/github/v/release/ai-dashboad/opencli?style=flat-square)](https://github.com/ai-dashboad/opencli/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ai-dashboad/opencli/total?style=flat-square)](https://github.com/ai-dashboad/opencli/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=flat-square)](../LICENSE)

[English](../README.md) ·
[简体中文](./README.zh-CN.md) ·
[繁體中文](./README.zh-TW.md) ·
[日本語](./README.ja.md) ·
**한국어** ·
[Español](./README.es.md) ·
[Português](./README.pt-BR.md) ·
[Français](./README.fr.md) ·
[Deutsch](./README.de.md) ·
[Русский](./README.ru.md)

[다운로드](https://opencli.ai/download.html) ·
[문서](https://docs.opencli.ai) ·
[시작하기](https://docs.opencli.ai/getting-started/install) ·
[제공자](https://docs.opencli.ai/getting-started/providers) ·
[못 하는 일](https://docs.opencli.ai/reference/limits)

</div>

OpenCLI 는 당신의 컴퓨터에서 도는 에이전트로, OpenAI 호환 모델이면 무엇이든 씁니다 — 눈앞의 기기에 있는 것, 당신 서버에 있는 것, 또는 필요할 때 쓰는 호스팅 제공자의 것. 파일을 읽고, 명령을 실행하고, 작업물을 고칩니다. 터미널과 데스크톱 앱은 같은 대화를 공유합니다.

**아무것도 내장되어 있지 않습니다.** 모델도, 계정도, 키도 없고, 추론을 어디서 사는지에 대한 입장도 없습니다. 엔드포인트를 가리키면 그 모델이 알아서 나타나고, 입력한 것은 거기로만 갑니다.

## 다운로드

| 플랫폼 | |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

설치 후에는 알아서 업데이트됩니다. 이 빌드에는 Apple / Microsoft 인증서가 없어서 첫 실행에 한 단계가 더 필요합니다 — [어떻게 하는지](https://docs.opencli.ai/getting-started/install).

**명령줄, macOS 와 Linux:**

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

그다음 모델을 하나 지정하세요.

## 할 수 있는 일

- 🗂 **코드만이 아니라 파일을 다룹니다.** 청구서가 든 폴더를 읽는 일과 저장소를 읽는 일은 같습니다 — 그리고 사람들이 실제로 가진 일은 대개 앞쪽입니다.

- 🏢 **회사처럼 짜여 있습니다.** **부서**는 상시 지침이 붙은 디렉터리, **봇**은 그 안의 대화이며 맡은 일이 있습니다. 아홉 개 부서가 예제 데이터와 함께 들어 있어, 설정하기 전에 먼저 써볼 수 있습니다.

- ⏰ **당번은 스스로 때가 되고** — 혼자 정하면 안 되는 일에 이르면 **멈추고 당신에게 묻습니다**. 그 선은 미리 말로 적어 둡니다: *한 건이라도 10,000 을 넘으면*.

- 🤝 **봇끼리 일을 넘깁니다,** 무엇을 했는지와 만들어낸 파일까지 함께. 여덟 번까지, 봇 하나당 세 번까지라 연쇄가 폭주하지 않습니다.

- 🧰 **여섯 가지 작업 흐름이 스킬로 들어 있고,** 어느 디렉터리에서나 씁니다: 표를 규칙에 비춰 점검하기, 한 주 동안 무엇이 바뀌었는지 보고하기, 받은 편지함 분류하기, 두 초안 비교하기, 회의록을 결정과 담당자로 바꾸기, 기록에서 살펴볼 만한 것 짚기.

- 🔌 **커넥터는 MCP 서버입니다** — GitHub, Postgres, Slack, Notion, 브라우저. 키는 설정 파일과 따로 보관합니다. 그 파일은 공유되는 물건이니까요.

- 🚦 **경계가 보이는 샌드박스.** 실행은 자기 디렉터리 안에만 쓸 수 있습니다. 낯선 곳을 가리킨 실행은 그 자리를 이름으로 허용할 때까지 보류됩니다.

- 🌍 **열 개 언어,** 그 밖의 어떤 언어든 JSON 파일 하나면 되고, 아무것도 다시 빌드하지 않아도 됩니다.

- 💻 **터미널, 데스크톱, 로컬 웹 UI 가** 같은 게이트웨이를 씁니다. 한쪽에서 시작한 대화를 다른 쪽에서 이어갈 수 있습니다.

## 무엇과 연결되는가

서른 개의 연동이 아니라 **하나의 프로토콜**입니다. `/v1/chat/completions` 와 `/v1/models` 에 OpenAI 와 같은 방식으로 답하는 것이면 무엇이든 가리킬 수 있고, 그 모델은 알아서 나타납니다. 아래의 모든 엔드포인트는 여기 적기 전에 실제로 모델 목록을 물어 확인했습니다.

**당신의 기기에서** — Ollama · LM Studio · llama.cpp · LocalAI · Jan ·
Xinference · KoboldCpp · llamafile

**당신의 서버에서** — vLLM · SGLang · Text Generation Inference · NVIDIA NIM ·
LiteLLM

**오픈 모델을 호스팅하는 곳** — Fireworks · Together · Groq · DeepInfra · Baseten ·
Novita · Hyperbolic · Nebius · Cerebras · SambaNova · Featherless · Chutes ·
NVIDIA · Hugging Face · OpenRouter · Vercel AI Gateway · Perplexity

**중국** — 硅基流动 · 无问芯穹 · PPIO · 七牛云 · 魔搭 · 阿里云百炼 ·
火山方舟 / 豆包 · 百度千帆 · 讯飞星火 · 小米 MiMo · DeepSeek · 智谱 ·
月之暗面 · MiniMax · 阶跃星辰 · 腾讯混元 · 百川

**닫힌 모델, 필요할 때** — OpenAI · Anthropic · Mistral · xAI

**여러 곳이 무료 사용량을 줍니다.** 당신 기기에 안 들어가는 큰 모델을 시험하기에 가장 싼 방법입니다. 엔드포인트와, 어떤 모델을 어디서 제공하는지: [제공자](https://docs.opencli.ai/getting-started/providers).

> **연결된다는 것과 이 일을 잘한다는 것은 다릅니다.** 도구를 호출할 수 있는지가 일할 수 있는 모델과 말만 하는 모델을 가릅니다. 그리고 모델 카드에는 적혀 있지 않습니다.
> [당신 것을 시험해 보세요](https://docs.opencli.ai/reference/checking-a-model) —
> 정해진 과제 하나, 오 분. 표에 한 줄뿐인 건 한 모델만 돌려봤기 때문입니다 — **한 줄을 더하는 것이 지금 가장 쓸모 있는 기여입니다.**

## 못 하는 일

- **범용 오픈 모델은 파일 도구가 있어도 `grep` 으로 손이 갑니다.** 모델 쪽의 격차이고, 어떤 인터페이스로도 메울 수 없습니다.
- **토큰 수는 추정이지 센 것이 아닙니다.** 토크나이저는 모델의 것이고, 이것은 본 적 없는 모델을 돌립니다.
- **예약된 일은 OpenCLI 가 열려 있는 동안에만 돕니다.** 이것은 로컬 에이전트이지 서버가 아닙니다.
- **백그라운드 실행은 자기 디렉터리 안이면 무엇이든 쓸 수 있습니다.**
- **데스크톱 빌드에는 서명이 없습니다.** 운영체제가 경고하는 것이 맞습니다.
- **오른쪽에서 왼쪽으로 쓰는 언어의 배치는 아직 없습니다.**

[못 하는 일](https://docs.opencli.ai/reference/limits) 에 각각의 이유가 적혀 있습니다.

## 이것이 어디서 왔는가

[OpenAI 의 Codex CLI](https://github.com/openai/codex) 를 포크한 것입니다. Copyright 2025 OpenAI, Apache-2.0. **OpenAI 와는 무관합니다.**

Codex 는 OpenAI 의 모델을 위해 만들어졌고, 이것은 나머지 모두를 위해 만들어졌습니다 — 바뀌는 것은 이름만이 아닙니다. 부서, 봇, 당번, 백그라운드 실행, 그리고 작업 흐름은 이쪽 것입니다. 모델이 작을 때 무엇이 깨지는지에도 꽤 많은 손을 댔습니다: 열한 턴 내리 매 턴 요약하며 그때마다 맥락을 버리던 압축 루프와, 중국어 한 쪽을 실제 비용의 사분의 삼으로 읽던 토큰 추정입니다.

[Apache-2.0](../LICENSE) · [NOTICE](../NOTICE) ·
[개발 참여](https://docs.opencli.ai/reference/contributing)
