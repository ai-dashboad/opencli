---
title: Установка
sidebar_position: 1
---

# Установка

## Настольное приложение

Скачайте с [opencli.ai/download](https://opencli.ai/download.html) или прямо
из последнего релиза:

| Платформа | Скачать |
| --- | --- |
| macOS · Apple Silicon | [`OpenCLI-macos-aarch64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-aarch64.dmg) |
| macOS · Intel | [`OpenCLI-macos-x86_64.dmg`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-macos-x86_64.dmg) |
| Windows | [`OpenCLI-windows-x86_64-setup.exe`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-windows-x86_64-setup.exe) |
| Linux | [`OpenCLI-linux-x86_64.AppImage`](https://github.com/ai-dashboad/opencli/releases/latest/download/OpenCLI-linux-x86_64.AppImage) |

**Каждая ссылка всегда указывает на самый новый релиз**, поэтому продолжает
работать при смене версий.

Дальше **приложение обновляется само**.

### В первый раз компьютер вас предупредит

Эти сборки **не подписаны** сертификатом Apple или Microsoft. Такие
сертификаты стоят денег каждый год, и проект этих денег не тратил.
**С загрузкой всё в порядке** — просто операционная система не может понять,
кто её собрал.

**macOS** — перетащив OpenCLI в «Программы», выполните один раз:

```shell
xattr -dr com.apple.quarantine /Applications/OpenCLI.app
```

либо щёлкните по приложению правой кнопкой, выберите **Открыть** и
подтвердите. **Только при первом запуске.**

**Windows** — SmartScreen покажет синее окно. Нажмите **Подробнее**, затем
**Выполнить в любом случае**.

## Командная строка

Один бинарник, macOS и Linux:

```shell
curl -fsSL https://opencli.ai/install.sh | sh
```

**Скрипт определит вашу платформу**, скачает подходящую сборку и положит
`opencli` в `/usr/local/bin` — или в `~/.local/bin`, если туда писать нельзя,
и подскажет добавить его в `PATH`.

**Пакет npm пока не опубликован** — область `@ai-dashboad` не зарегистрирована.
Пока это так, **установщик выше и настольные сборки — два доступных пути**.

## Из исходников

Понадобится свежий тулчейн Rust:

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

Бинарник появится в `opencli-rs/target/release/opencli`.

## Что и куда записано

| | |
| --- | --- |
| `~/.opencli/config.toml` | поставщики, модели, настройки подтверждений и песочницы |
| `~/.opencli/workspace/` | где начинается разговор, если не указано иное |
| `~/.opencli/skills/` | навыки, включая идущие в комплекте |
| `~/.opencli/locales/` | языки, которые вы добавили |
| `~/.opencli/log/` | журналы |

**За пределами `~/.opencli` ничего не пишется, пока вы не направите агента в
какой-нибудь каталог.**

## Дальше

[Укажите ему модель](/getting-started/point-at-a-model) — модели внутри нет, и
**он не ответит, пока ему некого спросить**.
