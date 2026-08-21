<p align="center"><code>npm i -g @openai/opencli</code><br />or <code>brew install --cask opencli</code></p>
<p align="center"><strong>OpenCLI CLI</strong> is a coding agent from OpenAI that runs locally on your computer.
<p align="center">
  <img src="https://github.com/openai/opencli/blob/main/.github/opencli-cli-splash.png" alt="OpenCLI CLI splash" width="80%" />
</p>
</br>
If you want OpenCLI in your code editor (VS Code, Cursor, Windsurf), <a href="https://developers.openai.com/opencli/ide">install in your IDE.</a>
</br>If you are looking for the <em>cloud-based agent</em> from OpenAI, <strong>OpenCLI Web</strong>, go to <a href="https://chatgpt.com/opencli">chatgpt.com/opencli</a>.</p>

---

## Quickstart

### Installing and running OpenCLI CLI

Install globally with your preferred package manager:

```shell
# Install using npm
npm install -g @openai/opencli
```

```shell
# Install using Homebrew
brew install --cask opencli
```

Then simply run `opencli` to get started.

<details>
<summary>You can also go to the <a href="https://github.com/openai/opencli/releases/latest">latest GitHub Release</a> and download the appropriate binary for your platform.</summary>

Each GitHub Release contains many executables, but in practice, you likely want one of these:

- macOS
  - Apple Silicon/arm64: `opencli-aarch64-apple-darwin.tar.gz`
  - x86_64 (older Mac hardware): `opencli-x86_64-apple-darwin.tar.gz`
- Linux
  - x86_64: `opencli-x86_64-unknown-linux-musl.tar.gz`
  - arm64: `opencli-aarch64-unknown-linux-musl.tar.gz`

Each archive contains a single entry with the platform baked into the name (e.g., `opencli-x86_64-unknown-linux-musl`), so you likely want to rename it to `opencli` after extracting it.

</details>

### Using OpenCLI with your ChatGPT plan

Run `opencli` and select **Sign in with ChatGPT**. We recommend signing into your ChatGPT account to use OpenCLI as part of your Plus, Pro, Team, Edu, or Enterprise plan. [Learn more about what's included in your ChatGPT plan](https://help.openai.com/en/articles/11369540-opencli-in-chatgpt).

You can also use OpenCLI with an API key, but this requires [additional setup](https://developers.openai.com/opencli/auth#sign-in-with-an-api-key).

## Docs

- [**OpenCLI Documentation**](https://developers.openai.com/opencli)
- [**Contributing**](./docs/contributing.md)
- [**Installing & building**](./docs/install.md)
- [**Open source fund**](./docs/open-source-fund.md)

This repository is licensed under the [Apache-2.0 License](LICENSE).
