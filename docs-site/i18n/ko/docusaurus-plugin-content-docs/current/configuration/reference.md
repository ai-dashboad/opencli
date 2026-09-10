---
title: 전체 설정 참고
sidebar_position: 4
---

# 전체 설정 참고

`~/.opencli/config.toml` 이 받아들이는 모든 키. **대부분의 사람이 건드리는 몇 개**는
[설정 파일](/configuration/config-file)에 있고, 그쪽이 훨씬 짧습니다.

### 가장 빠른 길: OpenCLI가 알아서 모델을 찾게 하기

이미 Ollama, LM Studio, vLLM, llama.cpp 를 로컬에서 돌리고 있다면:

```shell
opencli provider scan
```

**흔히 쓰는 localhost 포트를 두드려 보고**, 찾은 서버마다 어떤 모델을 제공하는지 물어서
해당 `[model_providers.*]` 와 `[[models]]` 를 `config.toml` 에 씁니다 ——
**기존 주석과 설정은 보존됩니다.** `--dry-run` 을 붙이면 무엇을 쓸지 먼저 볼 수 있습니다.

호스팅 공급자는 카탈로그에서 하나 설치하고 키를 넣습니다:

```shell
opencli provider list          # 카탈로그와 이미 설정된 것들
opencli provider add openrouter
export OPENROUTER_API_KEY=...
```

**카탈로그에는 접속 정보만 있습니다** —— 바이너리에 키는 들어 있지 않고,
**당신이 넣기 전에는 아무것도 켜지지 않습니다.** 카탈로그에 없는 것을 설정하려면
아래 설명대로 직접 절을 쓰세요.

#### 모델의 능력 채워 넣기

**로컬 모델의 컨텍스트 창과 도구 호출 지원 여부는 어디에도 공개되어 있지 않습니다.**
그리고 **어림짐작은 비워 두는 것보다 나쁩니다** —— 컨텍스트 창을 너무 크게 잡으면
공급자가 자동 압축 대신 그 차례를 **거절합니다.** **모델에게 직접 물으세요**:

```shell
opencli model probe <slug>            # --dry-run 을 붙이면 미리 봅니다
```

**가능한 경우 런타임 자신의 메타데이터를 읽고**(**Ollama는 실제 컨텍스트 길이와 능력 목록을
알려 줍니다**), 거기에 더해 **실제 요청을 한 번 보내** 내어 준 도구를 부르는지,
생각을 별도의 `reasoning` 필드로 돌려주는지 확인합니다. 알아낸 것은 그 모델의
`[[models]]` 항목에 기록됩니다.

**아예 대화가 안 되는 모델** —— 예컨대 임베딩 모델 —— 은 `provider scan` 이 건너뛰므로
`/model` 선택 목록까지 오지 못합니다.

### 모델과 공급자 고르기

이 빌드에는 몇몇 게이트웨이의 프리셋이 들어 있지만, **OpenAI 호환 API로 닿는 모델이라면
무엇이든** `~/.opencli/config.toml` 에서 설정할 수 있고 **다시 빌드할 필요가 없습니다.**

#### 공급자 추가하기

`[model_providers.<id>]` 의 항목은 **같은 id의 내장 공급자를 덮어씁니다.**
그러니 이것은 **번들된 게이트웨이를 프록시나 미러로 돌려 세우는 방법**이기도 합니다:

```toml
[model_providers.my-gateway]
name = "My Gateway"
base_url = "https://gateway.example.com/v1"
env_key = "MY_GATEWAY_API_KEY"
wire_api = "chat"
# 선택: 이 게이트웨이가 첫 토큰을 늦게 내놓는다면 올리세요.
stream_idle_timeout_ms = 90000
```

**API 키는 언제나 환경 변수에서 읽고, 설정 파일에는 저장되지 않습니다.**

#### 모델 추가하기

`[[models]]` 로 모델을 선언합니다. 내장 프리셋 옆에 `/model` 선택 목록에 나타나고,
**`model` 이 내장 프리셋과 같은 항목은 그것을 대체합니다**:

```toml
[[models]]
model = "qwen3-max"
provider = "my-gateway"
display_name = "Qwen3 Max"     # 선택. 기본값은 slug
description = "직접 돌립니다."  # 선택
show_in_picker = true          # 선택. 기본값은 true
```

`provider` 는 필수이고, 위에서 정의한 공급자나 내장 공급자를 가리켜야 합니다.
**정의되지 않은 공급자를 가리키는 모델은 시작할 때 바로 거부됩니다** ——
나중에 엉뚱한 오류와 함께 실패하는 대신에요.

선택 목록에 넣지 않고 모델을 고르려면 `model` 과 `model_provider` 를 직접 설정하세요:

```toml
model = "qwen3-max"
model_provider = "my-gateway"
```

`model` 이 내장 프리셋도 `[[models]]` 항목도 아닌 것을 가리키고 `model_provider` 도
설정되어 있지 않으면, 요청은 `openai` 공급자로 떨어지고 경고가 기록됩니다.

#### 컨텍스트 창

**이 빌드가 메타데이터를 갖고 있지 않은 모델은 보수적인 131,072 토큰 창으로 시작하고**,
게이트웨이의 **첫 「창 초과」 거절에서 진짜 값을 배웁니다.**
`model_context_window` 를 설정하면 명시적으로 못 박을 수 있습니다.

### MCP 서버에 연결하기

OpenCLI는 `~/.opencli/config.toml` 에 선언된 MCP 서버에 연결할 수 있습니다.

```toml
[mcp_servers.github]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-github"]
env_vars = ["GITHUB_PERSONAL_ACCESS_TOKEN"]

[mcp_servers.internal]
url = "https://mcp.example.com/mcp"
```

`env_vars` 는 그 서버가 필요로 하는 변수의 이름입니다.
**값은 공유되는 이 파일이 아니라 당신의 다른 키들과 함께 보관됩니다.**
여기 선언한 서버는 **눈앞의 대화가 아니라 다음에 여는 대화**와 함께 시작합니다.

데스크톱 앱은 **Abilities → Connectors** 에서 같은 표를 쓰며,
**핸드셰이크도 시험하고** 각 서버가 제공하는 도구도 보여 줍니다.

### 앱(Connectors)

입력창에서 `$` 로 ChatGPT 커넥터를 넣습니다. 팝오버가 쓸 수 있는 앱을 보여 줍니다.
`/apps` 명령은 사용 가능한 앱과 설치된 앱을 보여 줍니다.
**연결된 앱이 먼저 오고 「연결됨」으로 표시되며**, 나머지는 「설치 가능」으로 표시됩니다.

### 알림

OpenCLI는 에이전트가 한 차례를 마쳤을 때 알림 훅을 돌릴 수 있습니다.

```toml
notify = ["/path/to/your/script.sh"]
```

그 프로그램은 인자 하나로 호출됩니다: **무슨 일이 있었는지 적은 JSON 객체.**
**떼어 놓고 실행되므로 느린 스크립트가 다음 차례를 붙들지 않고**, 실패한 스크립트는
앞으로 튀어나오는 대신 로그에 남습니다.

### JSON 스키마

`config.toml` 을 위해 생성된 JSON 스키마는
[`opencli-rs/core/config.schema.json`](https://github.com/ai-dashboad/opencli/blob/main/opencli-rs/core/config.schema.json)
에 있고, **릴리스마다 `config-schema.json` 으로 함께 올라갑니다.**
이 파일을 손으로 고칠 때 에디터를 그쪽으로 향하게 하면 자동 완성과 검증이 됩니다.

**이것은 Rust 타입에서 생성되고, 타입과 어긋나면 CI가 실패합니다** ——
그러니 **이 파일에 대한 설명 중 유일하게 낡지 않는 것**입니다.

### 알림 억제

OpenCLI는 일부 화면 안내의 「다시 보지 않기」 표시를 `[notice]` 표에 저장합니다.

Ctrl+C / Ctrl+D 로 나가는 것은 약 1초 안에 두 번 누르라는 안내를 씁니다
(`ctrl + c again to quit`).
