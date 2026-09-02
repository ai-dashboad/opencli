# Cutting a release

One tag produces everything: the CLI for eight targets, the desktop app for
four, and the `latest.json` the installed apps read to update themselves. They
all carry the same version number, which is why `scripts/set-version.sh` exists
— an app that disagrees with its own release about which release it is will
never offer an update, and will not say why.

## The steps

```shell
scripts/set-version.sh 0.2.0
cargo update -w --manifest-path opencli-rs/Cargo.toml   # refresh the lock files
git commit -am "release 0.2.0"
git tag -a v0.2.0 -m "Release 0.2.0"
git push origin main v0.2.0
```

The tag message is not the release notes — the **commit message** the tag points
at is, so write the commit for people reading the release page.

## What runs

| Workflow | Triggered by | Produces |
| --- | --- | --- |
| `rust-release.yml` | tag `v*.*.*` | CLI binaries, npm packages, the GitHub Release |
| `desktop-release.yml` | called by the above | `.dmg`, `.AppImage`, `.deb`, `.msi`, `-setup.exe`, and the signed updater artifacts |
| `website.yml` | push to `main` touching `website/` | opencli.ai |

`desktop-release.yml` is called rather than triggered by the same tag on
purpose: two workflows publishing to one tag race each other, and the loser's
files go missing from the release with no error anywhere.

## Secrets and variables

| Name | Kind | Needed for | If missing |
| --- | --- | --- | --- |
| `TAURI_SIGNING_PRIVATE_KEY` | secret | Signing the desktop updater artifacts | **Auto-update stops working.** The build still succeeds, so this fails quietly — check that `latest.json` in the release lists every platform |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | secret | The above, if the key has a password | Ours has none; set it to an empty string |
| `CLOUDFLARE_API_TOKEN` | secret | Publishing opencli.ai | The site builds in CI and is not deployed |
| `CLOUDFLARE_ACCOUNT_ID` | variable | The above | Same |
| `APPLE_CERTIFICATE_P12` and friends | secret | Signing and notarising the macOS CLI binaries | Skipped; the downloads are unsigned, which the download page explains |
| `AZURE_TRUSTED_SIGNING_*` | secret | Signing the Windows CLI binaries | Skipped, as above |

### The updater signing key

Generated once, with `cargo tauri signer generate`. The **public** key is
committed, in `desktop/src-tauri/tauri.conf.json`. The **private** key is not in
this repository and must not be: it is the only thing standing between a user's
machine and someone else's idea of an update.

If it is lost, every installed copy stops accepting updates and everyone has to
download the app again by hand. Keep a copy somewhere that survives the loss of
one laptop.

To rotate it: generate a new pair, replace `pubkey` in `tauri.conf.json`,
replace the secret, and release. Apps already installed will refuse the update
signed by the new key — they trust only the key they were built with — so a
rotation costs everyone one manual reinstall. It is not a routine operation.

## Checking a release actually works

The parts that fail silently, in the order they bite:

1. **`latest.json` lists every platform.** Open it from the release. A platform
   whose build failed is simply absent, and its users never hear about the
   update. `scripts/make-updater-manifest.py` refuses to write an empty one, but
   it cannot know that four platforms were expected rather than three.
2. **The stable download names exist.** `OpenCLI-macos-aarch64.dmg` and its
   siblings are what the site and the README link to. They are copies made
   during the build; if the naming in `desktop-release.yml` drifts, the links
   404 while the release itself looks complete.
3. **An installed older version offers the update.** The only true test. Keep
   the previous release's app around, launch it, and wait — it checks eight
   seconds after start, and then every six hours.

## Testing the updater without cutting a release

The endpoint is baked into the app at build time, so pointing a test build at a
local file server needs a config override rather than an edit:

```shell
# The version to be offered.
scripts/set-version.sh 0.2.0
(cd desktop && cargo tauri build --bundles app)
mkdir -p /tmp/feed && cp desktop/src-tauri/target/release/bundle/macos/OpenCLI.app.tar.gz* /tmp/feed/

# The version doing the asking, pointed at that feed. The `dangerous` flag is
# required: the plugin refuses a plain-http endpoint, and refuses it by
# panicking at startup rather than by disabling updates — so a build without it
# will not launch at all.
scripts/set-version.sh 0.1.0
(cd desktop && cargo tauri build --bundles app --config '{"plugins":{"updater":{
  "endpoints":["http://127.0.0.1:4821/latest.json"],
  "dangerousInsecureTransportProtocol":true}}}')
```

Write a `latest.json` into `/tmp/feed` by hand (the same shape
`make-updater-manifest.py` writes), serve it with `python3 -m http.server 4821`,
install the 0.1.0 build into `/Applications`, and launch it.

Both builds must be signed with the same key the app was built to trust, so set
`TAURI_SIGNING_PRIVATE_KEY` for each.
