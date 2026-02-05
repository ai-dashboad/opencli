# OpenCLI Project Rules

## Language Requirements

**All text in this project MUST be in English**, including:
- Git commit messages
- Code comments
- Documentation files
- Variable names and function names
- Error messages and log output
- README and other markdown files

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
