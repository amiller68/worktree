# Development Guide

Guide for AI agents and developers working on this Git worktree manager.

## Project Overview

`wt` is a CLI tool for managing git worktrees, designed for parallel Claude Code sessions.

## Versioning

- **Location:** `manifest.toml`
- **Format:** Semantic versioning (MAJOR.MINOR.PATCH)
- **Rules:**
  - MAJOR: Breaking changes (removed commands, changed behavior)
  - MINOR: New features, commands, flags (backward compatible)
  - PATCH: Bug fixes, docs, internal refactoring

## Testing

- **Directory:** `tests/`
- **Run all:** `./test.sh`
- **Structure:**
  - `tests/test_*.sh` - Individual test modules
  - `assert_*` helper functions in test.sh
  - Tests run in isolated temp directories
- **Adding tests:** Create new test module or add to existing one

## Documentation

- **Main docs:** `README.md`
- **Update when:**
  - New commands/flags added
  - Behavior changed
  - New configuration options

## Key Files

- `_wt.sh` - Main implementation
- `manifest.toml` - Version
- `test.sh` - Test runner
- `tests/` - Test modules
- `shell/wt.bash` - Bash integration
- `shell/wt.zsh` - Zsh integration
