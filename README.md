# OpenCLI

A coding agent that runs locally in your terminal and works with **any
OpenAI-compatible API** — a hosted provider, a self-hosted gateway, or a model
running on your own machine.

This build ships no models and no API keys. You declare the providers and models
you want in `~/.opencli/config.toml`, so the binary carries no opinion about
where your inference comes from and no secrets.

---

## Quickstart

### Build

Requires a recent Rust toolchain.

```shell
git clone https://github.com/ai-dashboad/opencli.git
cd opencli/opencli-rs
cargo build --release -p opencli-cli --bin opencli
```

The binary lands at `opencli-rs/target/release/opencli`; put it somewhere on your
`PATH`.

### Configure a model

Create `~/.opencli/config.toml` pointing at any OpenAI-compatible endpoint:

```toml
model = "my-model"

[model_providers.my-gateway]
name = "My Gateway"
base_url = "https://gateway.example.com/v1"
env_key = "MY_GATEWAY_API_KEY"
wire_api = "chat"

[[models]]
model = "my-model"
provider = "my-gateway"
display_name = "My Model"
context_window = 128000
reasoning_efforts = ["low", "medium", "high"]
```

Then:

```shell
export MY_GATEWAY_API_KEY=...
opencli
```

Models declared this way appear in the `/model` picker. Local runtimes work the
same way — built-in `ollama` and `lmstudio` providers point at localhost.

For OpenAI itself, set `OPENAI_API_KEY` and use the built-in `openai` provider.

See [docs/config.md](./docs/config.md) for the full reference.

## Docs

- [**Configuration**](./docs/config.md) — providers, models, routing, sandboxing
- [**Contributing**](./docs/contributing.md)
- [**Installing & building**](./docs/install.md)

## License and attribution

Licensed under the [Apache-2.0 License](LICENSE).

This project is derived from [OpenAI OpenCLI](https://github.com/openai/opencli),
Copyright 2025 OpenAI, also licensed under Apache-2.0. See [NOTICE](NOTICE) for
full attribution.
