# Publishing OpenCLI

This document outlines the complete automated release process for OpenCLI.

## Overview

OpenCLI uses a **fully automated multi-channel publishing workflow**. A single command triggers the entire release process across all distribution channels.

### Distribution Channels

- **GitHub Releases** - Binaries and release notes
- **Homebrew** - macOS and Linux package manager
- **Scoop** - Windows package manager
- **Winget** - Windows Package Manager
- **npm** - Node.js package manager (planned)
- **Docker/GHCR** - Container images
- **Snap** - Linux package manager (planned)
- **MCP Markets** - Smithery.ai, Glama.ai, PulseMCP, etc.

## Prerequisites

### Required Secrets

Configure these secrets in GitHub Settings → Secrets and variables → Actions:

```
HOMEBREW_TAP_TOKEN        # GitHub PAT for homebrew-tap repository
SCOOP_BUCKET_TOKEN        # GitHub PAT for scoop-bucket repository
NPM_TOKEN                 # npm automation token (if publishing to npm)
SNAPCRAFT_TOKEN           # Snap store credentials (if publishing to Snap)
```

### Required Repositories

Create these repositories before first release:

1. `<org>/homebrew-tap` - Homebrew formula repository
2. `<org>/scoop-bucket` - Scoop manifest repository

## Release Process

### 1. Prepare Release

Ensure all changes are committed and tests pass:

```bash
# Run tests
dart test
cargo test --workspace

# Check for uncommitted changes
git status
```

### 2. Execute Release

Run the automated release script:

```bash
./scripts/release.sh <version> "<description>"
```

**Examples:**

```bash
# Stable release
./scripts/release.sh 1.0.0 "Initial stable release"

# Minor update
./scripts/release.sh 1.1.0 "Add browser automation features"

# Patch release
./scripts/release.sh 1.0.1 "Bug fixes and performance improvements"

# Pre-release
./scripts/release.sh 1.1.0-beta.1 "Beta release with new features"
```

### 3. Automated Steps

The script automatically performs:

1. **Validates** version format (SemVer)
2. **Checks** for uncommitted changes
3. **Updates** version in all files:
   - `cli/Cargo.toml`
   - `daemon/pubspec.yaml`
   - `ide-plugins/vscode/package.json`
   - `web-ui/package.json`
   - `plugins/*/pubspec.yaml`
   - `README.md`
4. **Updates** `CHANGELOG.md`
5. **Syncs** documentation across packages
6. **Creates** git commit
7. **Tags** release with `v<version>`
8. **Pushes** to GitHub (triggers CI/CD)

### 4. GitHub Actions Workflow

Once pushed, GitHub Actions automatically:

#### Prepare Stage
- Extracts version from tag
- Syncs documentation

#### Build Stage (parallel)
- **CLI Binaries** - 5 platforms:
  - macOS (ARM64 + x86_64)
  - Linux (x86_64 + ARM64)
  - Windows (x86_64)
- **Daemon Binaries** - 3 platforms:
  - macOS
  - Linux
  - Windows
- Calculates SHA256 checksums for all binaries

#### Publish Stage (parallel)
- **GitHub Release**
  - Creates release with auto-generated notes
  - Uploads all binaries
  - Uploads checksums
  - Marks as pre-release if version contains hyphen
- **Homebrew**
  - Updates formula with new version and checksums
  - Pushes to homebrew-tap repository
- **Scoop**
  - Updates manifest with new version and checksum
  - Pushes to scoop-bucket repository
- **Winget**
  - Generates manifest files
  - Uploads as artifacts (manual PR required)
- **Docker**
  - Builds multi-arch images (amd64, arm64)
  - Pushes to GitHub Container Registry
  - Tags: `latest`, `<version>`, `<major>.<minor>`, `<major>`

### 5. Manual Steps

Some platforms require manual submission:

#### Winget (Windows Package Manager)

1. Download manifest artifacts from GitHub Actions
2. Fork `microsoft/winget-pkgs`
3. Create directory: `manifests/o/OpenCLI/OpenCLI/<version>/`
4. Copy manifest files
5. Submit Pull Request

Or use automated tool:
```powershell
winget-create update OpenCLI.OpenCLI -u <binary-url> -v <version> -t $GITHUB_TOKEN
```

#### MCP Markets

**Smithery.ai** (Automated)
- Automatically indexed via `smithery.json`
- No manual action needed

**Glama.ai** (Automated)
- Submit repository URL
- Automatically scrapes for MCP Server

**PulseMCP** (Manual)
- Visit https://pulsemcp.com/submit
- Submit project details

**Awesome MCP Servers** (Manual PR)
1. Fork `awesome-mcp-servers` repository
2. Add OpenCLI to README table
3. Submit Pull Request

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (`x.0.0`) - Incompatible API changes
- **MINOR** (`1.x.0`) - Backwards-compatible features
- **PATCH** (`1.0.x`) - Backwards-compatible bug fixes
- **Pre-release** (`1.0.0-alpha.1`) - Alpha, beta, rc

## CHANGELOG Format

The `CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/):

```markdown
## [1.0.0] - 2026-01-31

### Added
- New features

### Changed
- Changes in existing functionality

### Fixed
- Bug fixes

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Security
- Security fixes
```

## Release Checklist

### Pre-Release

- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md describes changes
- [ ] Version bump is appropriate
- [ ] No uncommitted changes
- [ ] On correct branch (usually `main`)

### During Release

- [ ] Run `./scripts/release.sh <version> "<description>"`
- [ ] Verify git tag created
- [ ] Verify push successful
- [ ] Monitor GitHub Actions

### Post-Release

- [ ] Verify GitHub Release created
- [ ] Verify binaries uploaded
- [ ] Check Homebrew formula updated
- [ ] Check Scoop manifest updated
- [ ] Check Docker images pushed
- [ ] Submit Winget PR (if applicable)
- [ ] Update MCP Markets (if needed)
- [ ] Announce release

## Monitoring Release

### GitHub Actions

Monitor workflow progress:
```
https://github.com/<org>/opencli/actions
```

### Docker Images

Verify images:
```bash
docker pull ghcr.io/<org>/opencli:latest
docker pull ghcr.io/<org>/opencli:<version>
```

### Package Managers

Test installation:
```bash
# Homebrew
brew install <org>/tap/opencli
brew upgrade opencli

# Scoop
scoop install opencli
scoop update opencli

# Winget
winget install OpenCLI.OpenCLI
winget upgrade OpenCLI.OpenCLI

# npm (if published)
npm install -g @opencli/cli
```

## Troubleshooting

### Failed Workflows

If a workflow fails:

1. **Check logs** in GitHub Actions
2. **Fix the issue** in code
3. **Delete the tag** locally and remotely:
   ```bash
   git tag -d v<version>
   git push origin :refs/tags/v<version>
   ```
4. **Re-run** the release script

### Version Mismatch

If version sync fails:

```bash
# Manually run version bump
dart scripts/bump_version.dart <version>

# Check differences
git diff
```

### Failed Push

If push fails:

```bash
# Verify remote
git remote -v

# Try manual push
git push origin main --follow-tags

# Or push tag separately
git push origin v<version>
```

## Rolling Back

To rollback a release:

1. **Delete GitHub Release**
   - Go to Releases → Edit → Delete

2. **Delete Git Tag**
   ```bash
   git tag -d v<version>
   git push origin :refs/tags/v<version>
   ```

3. **Revert Package Managers**
   - Homebrew: Push old formula
   - Scoop: Push old manifest
   - Winget: Submit new PR
   - Docker: Delete image tags (or leave as historical)

## Best Practices

1. **Test locally first** - Build and test before releasing
2. **Use pre-releases** - Test distribution with `-beta` versions
3. **Automate everything** - Avoid manual version updates
4. **Document changes** - Keep CHANGELOG.md current
5. **Verify checksums** - Ensure integrity across platforms
6. **Monitor failures** - Set up notifications for failed workflows
7. **Communicate** - Announce releases to users

## Continuous Deployment

For automated releases on every merge to `main`:

1. Update `.github/workflows/release.yml` trigger:
   ```yaml
   on:
     push:
       branches: [main]
   ```

2. Implement automatic version bumping
3. Generate CHANGELOG from commits

**Note:** Manual releases are recommended for better control.

## Support

For release issues:

- **GitHub Discussions**: https://github.com/<org>/opencli/discussions
- **Issues**: https://github.com/<org>/opencli/issues
- **Email**: support@opencli.ai

## References

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Homebrew Formula](https://docs.brew.sh/Formula-Cookbook)
- [Scoop Manifests](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
- [Winget Manifests](https://docs.microsoft.com/en-us/windows/package-manager/package/manifest)
