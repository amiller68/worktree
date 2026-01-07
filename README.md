# wt

[![Tests](https://github.com/amiller68/worktree/actions/workflows/test.yml/badge.svg)](https://github.com/amiller68/worktree/actions/workflows/test.yml)

Git worktree manager for running parallel Claude Code sessions.

## Features

- **Simple commands** - Create, list, open, and remove worktrees with short commands
- **Auto-isolation** - Worktrees stored in `.worktrees/` (automatically git-ignored)
- **Shell integration** - Tab completion for commands and worktree names
- **Nested paths** - Supports branch names like `feature/auth/login`
- **Self-updating** - Run `wt update` to get the latest version

## Install

```bash
curl -sSf https://raw.githubusercontent.com/amiller68/worktree/main/install.sh | bash
```

Restart your shell after installing, or run:
```bash
source ~/.zshrc  # or ~/.bashrc
```

## Commands

| Command | Description |
|---------|-------------|
| `wt create <name> [branch]` | Create a worktree with a new branch |
| `wt create <name> -o` | Create and cd into the worktree |
| `wt open <name>` | cd into an existing worktree |
| `wt list` | List worktrees in `.worktrees/` |
| `wt list --all` | List all git worktrees |
| `wt remove <pattern>` | Remove worktree(s) matching pattern (supports regex) |
| `wt cleanup` | Remove all worktrees |
| `wt update` | Update wt to latest version |
| `wt update --force` | Force update (reset to remote) |
| `wt version` | Show version |

## Usage

### Create a worktree and start working

```bash
cd ~/projects/my-app
wt create feature-auth -o    # Creates worktree, cd's into it
claude                       # Start Claude Code
```

The `-o` flag can be placed anywhere:
```bash
wt -o create feature-auth    # Same as above
wt create -o feature-auth    # Also works
```

### Run multiple Claude sessions in parallel

Terminal 1:
```bash
cd ~/projects/my-app
wt create feature-auth -o
claude
```

Terminal 2:
```bash
cd ~/projects/my-app
wt create fix-bug-123 -o
claude
```

Both instances work independently with their own branches.

### Use an existing branch

```bash
wt create my-worktree existing-branch
```

### Nested branch names

```bash
wt create feature/auth/oauth -o
# Creates .worktrees/feature/auth/oauth/
```

### Remove with regex

```bash
wt remove test1              # Remove exact match
wt remove 'test.*'           # Remove all starting with "test"
wt remove 'feature/.*'       # Remove all under feature/
```

## How it works

Worktrees are stored in `.worktrees/` inside your repo:

```
my-repo/
├── .worktrees/           # Auto-added to .git/info/exclude
│   ├── feature-a/
│   ├── feature-b/
│   └── feature/
│       └── auth/
│           └── oauth/
├── src/
└── ...
```

Each worktree is a full checkout of your repo on its own branch. Changes in one worktree don't affect others until you merge.

## Shell Integration

### Tab Completion

Both bash and zsh get tab completion:

```bash
wt <TAB>           # Shows: create list open remove cleanup update version
wt open <TAB>      # Shows available worktrees
wt remove <TAB>    # Shows available worktrees
```

### How the -o flag works

The `wt` shell function wraps the underlying `_wt` script. When you use `open` or the `-o` flag, the script outputs a `cd` command that the shell function `eval`s:

```bash
# What happens internally:
_wt open my-feature  # outputs: cd "/path/to/.worktrees/my-feature"
eval "cd ..."        # shell function evals it
```

This is why `wt open` can change your current directory.

## Testing

Run the test suite:

```bash
./test.sh
```

Tests run on both Ubuntu and macOS via GitHub Actions.

## Updating

```bash
wt update          # Pull latest changes
wt update --force  # Force reset to remote (discards local changes)
```

## Uninstall

```bash
rm -rf ~/.local/share/worktree
rm ~/.local/bin/_wt
# Remove source lines from ~/.bashrc and ~/.zshrc
```

## Requirements

- Git
- Bash or Zsh

## License

MIT
