---
title: 설정 파일
sidebar_position: 1
---

# 설정 파일

`~/.opencli/config.toml`. **여기 있는 것은 전부 기본값을 가지고 있습니다.**
파일이 담는 것은 **당신이 바꾼 것뿐**입니다.

**데스크톱 앱은 같은 파일에, 당신의 주석과 서식을 지킨 채 씁니다.** 그러니
**손으로 고치는 것과 Settings 에서 고치는 것은 같은 행위**입니다.

## 공급자와 모델

**공급자란 베이스 URL 하나와, 키가 들어 있는 환경 변수의 이름**입니다:

```toml
[model_providers.my-provider]
name = "My Provider"
base_url = "https://api.example.com/v1"
env_key = "MY_PROVIDER_API_KEY"
wire_api = "chat"
```

그 아래에 선언한 모델이 선택 목록에 나타납니다:

```toml
model = "my-model"

[[models]]
slug = "my-model"
model = "provider-side-model-id"
provider = "my-provider"
display_name = "My Model"
context_window = 128000
reasoning_efforts = ["low", "medium", "high"]
```

`slug` 는 **당신이 치는 이름**이고 `model` 은 **공급자가 부르는 이름**입니다.
**떼어 놓을 값어치가 있을 만큼 둘은 자주 다릅니다.**

**선언하지 않아도 됩니다.** 모델은 공급자의 `/v1/models` 에서 가져옵니다.
선언은 **컨텍스트 창, 표시 이름, 받아들이는 추론 강도를 못 박고 싶을 때** 하는 일입니다.

## 승인과 샌드박스

```toml
approval_policy = "on-failure"   # untrusted | on-failure | never
sandbox_mode = "workspace-write" # read-only | workspace-write | danger-full-access
```

[샌드박스와 승인](/configuration/sandbox-and-approvals)에서 설명합니다.

## 도구 출력

```toml
tool_output_token_limit = 10000
```

**도구의 출력이 대화에 더해도 되는 양의 예산**입니다.

**토큰은 세는 것이 아니라 어림합니다.** 토크나이저는 모델의 것이고,
**여기서는 한 번도 본 적 없는 모델을 돌립니다.** 어림은 **ASCII 네 바이트에 한 토큰,
그 밖에는 한 글자에 한 토큰** —— **영어에도 중국어에도 가깝고**, 나머지에서는 넉넉히
세는 쪽으로 기웁니다. 이걸 500 으로 둬도 **정확히 500 토큰에서 자르지 않습니다.**
**그 언저리에서, 이 숫자와 같은 단위로 자릅니다.**

## 지금 무엇이 적용되고 있는지 보기

**Settings** 는 **당신이 한 번도 설정하지 않은 것까지 포함해** 적용되는 모든 값과
**그것이 어디서 왔는지**를 보여 줍니다. `Show raw config` 는 파일 그 자체입니다.

## 전체 참고 문서

이 파일이 받아들이는 모든 키와 기본값:
[전체 설정 참고](/configuration/reference).
