# OpenCLI Project Rules

## Language Requirements

**All text in this project MUST be in English**, including:
- Git commit messages
- Code comments
- Documentation files (docs/, test-results/, etc.)
- Variable names and function names
- Error messages and log output
- README and other markdown files
- Test reports and E2E test output
- AI-generated content (reports, summaries, code comments)
- UI strings in the Flutter app and Web UI

**No exceptions.** Even if the user writes in Chinese or another language, all code, documentation, and generated files MUST be written in English.

## Web UI Layout Rules

- **All pages must use full-width layout** matching `/create` page style: `padding: 20px 32px 24px; max-width: 100%`. Do NOT use constrained `max-width` (e.g. 1000px, 1200px) or `margin: 0 auto` centering on page containers. Content should fill the available width uniformly across all pages.

## Code Style

- Follow Dart style guide for daemon code
- Follow Flutter style guide for mobile app
- Use meaningful variable and function names
- Add comments for complex logic

## Git Workflow

- Use conventional commits format: `type: description`
  - `feat:` new feature
  - `fix:` bug fix
  - `chore:` maintenance
  - `docs:` documentation
  - `refactor:` code refactoring
  - `test:` adding tests
- Keep commits atomic and focused
- Write clear, descriptive commit messages in English

## Project Structure

- `daemon/` - Dart backend daemon
- `opencli_app/` - Flutter cross-platform app (iOS, Android, macOS, Windows, Linux)
- `cli/` - Command line interface
- `web-ui/` - Web interface
- `scripts/` - Build and utility scripts
- `capabilities/` - Capability package definitions
- `docs/` - Documentation files
- `plugins/` - MCP plugin implementations

## Releasing New Versions

To release a new version, **always use the release script**:

```bash
./scripts/release.sh <version> "<description>"
```

Examples:
```bash
./scripts/release.sh 0.3.0 "New domain system with 12 task domains"
./scripts/release.sh 0.2.3 "Bug fixes for pattern matching"
./scripts/release.sh 1.0.0 "First stable release"
```

The script handles: version bump (via `scripts/bump_version.dart`), CHANGELOG update, git commit, annotated tag, and push. It also triggers GitHub Actions for builds.

**Never manually edit version numbers** — always use the release script.

## Documentation Guidelines

**All documentation markdown files MUST be created in the `docs/` folder**, including:
- Feature documentation
- User guides
- Architecture documents
- API documentation
- Implementation notes

**Exceptions** (can be in project root):
- `README.md` - Main project readme
- `CHANGELOG.md` - Version history
- `LICENSE` - License file
- `CONTRIBUTING.md` - Contribution guidelines

**Examples:**
- ✅ `docs/PLUGIN_SYSTEM.md` - Correct
- ✅ `docs/QUICK_START.md` - Correct
- ❌ `PLUGIN_SYSTEM.md` - Wrong (should be in docs/)
- ❌ `QUICK_START.md` - Wrong (should be in docs/)
