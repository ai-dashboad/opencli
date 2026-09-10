---
title: 설치
sidebar_position: 1
---

# 설치

## 데스크톱 앱

[opencli.ai/download](https://opencli.ai/download.html) 에서 내려받거나,
최신 릴리스에서 바로 가져가세요:

| 플랫폼 | 내려받기 |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

**모든 링크는 늘 가장 새 릴리스를 가리키므로** 버전이 바뀌어도 그대로 동작합니다.

그다음부터는 **앱이 스스로 업데이트합니다**.

### 처음 한 번은 컴퓨터가 경고합니다

이 빌드들은 Apple이나 Microsoft 인증서로 **서명되어 있지 않습니다**.
인증서는 해마다 돈이 들고, 이 프로젝트는 그 돈을 쓰지 않았습니다.
**내려받은 파일에는 아무 문제가 없습니다** —— 운영체제가 누가 만들었는지 알 수 없을 뿐입니다.

**macOS** —— OpenCLI를 응용 프로그램으로 끌어다 놓은 뒤 한 번만 실행하거나:

```shell
xattr -dr com.apple.quarantine /Applications/OpenCLI.app
```

앱을 오른쪽 클릭해 **열기** 를 고르고 확인하세요. **처음 한 번뿐입니다.**

**Windows** —— SmartScreen이 파란 창을 띄웁니다. **추가 정보** 를 누르고
**실행** 을 고르세요.

## 명령줄

바이너리 하나, macOS와 Linux:

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

**플랫폼을 알아내** 맞는 빌드를 받아 `opencli` 를 `/usr/local/bin` 에 둡니다 ——
거기에 쓸 수 없으면 `~/.local/bin` 에 두고 `PATH` 에 넣으라고 알려 줍니다.

**npm 패키지는 아직 공개되지 않았습니다** —— `@ai-dashboad` 스코프가 등록되지 않았기 때문입니다.
등록되기 전까지는 **위 설치 스크립트와 데스크톱 빌드, 두 갈래**뿐입니다.

## 소스에서

최근 버전의 Rust 툴체인:

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

바이너리는 `opencli-rs/target/release/opencli` 에 생깁니다.

## 무엇을 어디에 썼는가

| | |
| --- | --- |
| `~/.opencli/config.toml` | 공급자, 모델, 승인과 샌드박스 설정 |
| `~/.opencli/workspace/` | 달리 정한 것이 없을 때 대화가 시작하는 곳 |
| `~/.opencli/skills/` | 스킬. 기본으로 들어 있는 것들 포함 |
| `~/.opencli/locales/` | 당신이 추가한 언어 |
| `~/.opencli/log/` | 로그 |

**당신이 에이전트를 어떤 디렉터리로 향하게 하기 전까지 `~/.opencli` 밖에는 아무것도 쓰지 않습니다.**

## 다음

[모델을 가리켜 주기](/getting-started/point-at-a-model) —— 모델이 들어 있지 않고,
**물어볼 곳이 없으면 대답하지 않습니다**.
