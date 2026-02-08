# GitHub Automation MCP Plugin

GitHub automation for OpenCLI - Releases, PRs, Issues, Actions.

## Features

- ✅ **Create releases** - Automate release management
- ✅ **Manage PRs** - Create and manage pull requests
- ✅ **Handle issues** - Create and track issues
- ✅ **List releases** - Query repository releases
- ✅ **Trigger workflows** - Run GitHub Actions
- 🚧 **Monitor events** - Webhooks (coming soon)

## Installation

```bash
opencli plugin add github-automation
```

## Configuration

1. Create GitHub personal access token at https://github.com/settings/tokens

2. Add to `.env`:
```bash
GITHUB_TOKEN=your_github_token_here
```

## Usage

### Natural Language

```bash
# Create release
opencli "Create a GitHub release v1.0.0 for myrepo with release notes"

# Create PR
opencli "Create a PR from feature-branch to main"

# Create issue
opencli "Create an issue titled 'Bug: Login not working'"
```

### Automation Workflow

```bash
# GitHub Release → Twitter
opencli "When I create a GitHub release, post to Twitter"

# Result:
# 1. Monitor GitHub releases
# 2. Extract release info
# 3. Call twitter_post with release notes
```

## Tools

### github_create_release
- `owner`, `repo`, `tag_name` - Required
- `name`, `body` - Optional
- `draft`, `prerelease` - Booleans

### github_create_pr
- `owner`, `repo`, `title`, `head`, `base` - Required
- `body`, `draft` - Optional

### github_create_issue
- `owner`, `repo`, `title` - Required
- `body`, `labels`, `assignees` - Optional

## License

MIT
