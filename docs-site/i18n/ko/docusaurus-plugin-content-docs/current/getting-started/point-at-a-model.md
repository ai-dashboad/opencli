---
title: 모델을 가리켜 주기
sidebar_position: 2
---

# 모델을 가리켜 주기

**OpenCLI에는 모델도 키도 들어 있지 않습니다.** 새로 설치하면 첫 화면이 그렇게 말하고
아래 두 갈래를 내놓습니다.

**이것은 연동 목록이 아니라 하나의 프로토콜입니다.** OpenAI가 하는 방식대로
`/v1/chat/completions` 와 `/v1/models` 에 답하는 것이면 무엇이든 가리킬 수 있고,
**그 모델들은 목록에 알아서 나타납니다.** 하나씩 선언하지 않아도 됩니다.

## 이 기계 안에서

데스크톱 앱이 대신 설치해 줍니다: **Models** 를 열면, 무언가를 받아 오겠다고 하기 전에
**이미 기계에 있는 것을 먼저 봅니다**.

직접 하려면, [Ollama](https://ollama.com) 가 이미 돌고 있다는 전제로:

```toml
model = "qwen3-coder"

[model_providers.ollama]
name = "Ollama"
base_url = "http://localhost:11434/v1"
wire_api = "chat"

[[models]]
slug = "qwen3-coder"
model = "qwen3-coder:30b"
provider = "ollama"
context_window = 32768
```

이걸 `~/.opencli/config.toml` 에 넣고 `opencli` 를 실행하세요.

**아무것도 기계 밖으로 나가지 않고, 맡아 둘 키도 없습니다.**

## 공급자를 쓰기

**어느 곳이든 방식은 같습니다.** 형태는 베이스 URL 하나와, 키가 들어 있는 환경 변수의 이름:

```toml
model = "my-model"

[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

```shell
export MY_PROVIDER_API_KEY=...
opencli
```

데스크톱 앱에서는 같은 일을 **Settings** 에서 하며, **키는 저장되고 다시는 보이지 않습니다**.

### 큰 모델을 시험하는 가장 싼 방법이 무료 사용량입니다

몇몇 공급자는 무료로 내줍니다. **당신 기계에는 올라가지 않을 만큼 큰 모델**을
그렇게 돌릴 수 있습니다. 무엇이 무료인지는 달마다 바뀌므로 이 페이지는 액수를 적지 않습니다 ——
**각자의 가격 페이지를 보세요.**

[README](https://github.com/ai-dashboad/opencli#where-the-model-comes-from)
에 공급자 전체 목록이 있습니다. **한 곳씩 모델 목록을 물어 확인한 것들**입니다.

## 모델이 그것을 만든 회사에서 오지 않을 수도 있습니다

샤오미는 MiMo를, 바이트댄스는 Seed를 내놓지만 **둘 다 자기 공개 OpenAI 호환 엔드포인트를
운영하지 않습니다.** 둘 다 다른 곳이 실어 나릅니다 —— 그러니 MiMo에는 OpenRouter, Novita,
DeepInfra, PPIO, Hugging Face 를 거쳐 닿지, 샤오미를 거쳐 닿지 않습니다.

## 닿는다는 것과 이 일을 잘한다는 것은 다릅니다

**OpenAI API에는 답하지만 도구 호출 부분에는 답하지 않는 공급자는 대화만 할 뿐입니다.**
이 에이전트는 도구를 불러서 일합니다. 한 모델에 마음을 정하기 전에
[시험해 보세요](/reference/checking-a-model) —— **5분, 정해진 과제 하나**입니다.

## 다음

[첫 대화](/getting-started/first-conversation).
