# AGENTS.md - Dotfiles Repository Guidelines

## Repository Overview

This is a macOS dotfiles repository. The source of truth is `~/Development/dotfiles`. It configures Ghostty, zsh, modern CLI tools, and AI-powered shell enhancements.

## Build / Test / Lint Commands

This repository contains shell scripts and configuration files. There are no formal build or test commands.

### Validation Commands

```bash
# Check shell script syntax
bash -n .dotfiles/scripts/install.sh
bash -n .dotfiles/scripts/motd.sh
bash -n .dotfiles/scripts/setup-git.sh
bash -n .dotfiles/scripts/refresh-quotes.sh

# Validate JSON
jq empty .dotfiles/quotes/tech-quotes.json

# Run shellcheck (if available)
shellcheck .dotfiles/scripts/*.sh
```

### Dotfiles Management

```bash
# Use the dotfiles alias for git operations
dotfiles status
dotfiles add <file>
dotfiles commit -m "message"
dotfiles push

# Pull updates
dotfiles pull
```

### Anti-Pattern: Bare Repo Worktree vs Staging Repo (Legacy)

If you point the bare repo worktree at `~/dotfiles-staging` while that directory
has its own `.git`, Git will report mass deletions because the index expects the
bare repo layout, not the staging repo layout. This is noisy and misleading.

Legacy path note: `~/dotfiles-staging` is no longer the source of truth.

This repo now uses `~/Development/dotfiles` as the source of truth.

**Do this instead:**
- Use the repo's own Git with `git -C ~/Development/dotfiles ...`
- Or use the bare repo with `--work-tree=$HOME` (default)

## Code Style Guidelines

### Shell Scripts (Bash)

**Shebang & Strict Mode**
- Always use `#!/bin/bash`
- Always include `set -euo pipefail` at the top (or `set -e` for simpler scripts)
- This ensures: exit on error, undefined variables fail, pipeline failures are caught

**Function Style**
```bash
# Use descriptive function names with underscores
function_name() {
    # Use local variables
    local var_name="value"
    
    # Use explicit returns
    return 0
}
```

**Variable Conventions**
- UPPER_CASE for constants and environment variables
- lower_case for local variables
- Quote all variables: `"$variable"`
- Use `${var}` when necessary for clarity

**Logging Pattern**
```bash
# Use consistent color-coded logging
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
```

**Error Handling**
- Always check command exit codes
- Use `|| true` for commands that may fail non-critically
- Redirect errors appropriately: `2>/dev/null` or `>&2`
- Use `command -v` to check if tools exist before using them

**Comments**
- Use section headers with clear separators:
```bash
# ============================================================================
# SECTION NAME
# ============================================================================
```
- Explain WHY, not WHAT
- Keep comments concise

### JSON Files

- Use 2-space indentation
- Ensure valid JSON with jq before committing
- Maintain consistent structure in arrays of objects

### Zsh Plugin Code

- Use zsh parameter expansion patterns: `${var//pattern/replacement}`
- Set local options: `setopt LOCAL_OPTIONS NO_NOTIFY NO_MONITOR`
- Use zle (zsh line editor) widgets properly
- Prefix private functions with underscore: `_function_name`

## File Organization

```
~/Development/dotfiles/
├── .config/                 # App configs (ghostty, starship, mise)
├── .dotfiles/
│   ├── scripts/             # Bootstrap + helpers
│   ├── quotes/              # Tech quotes cache
│   ├── zsh/plugins/         # Zsh plugins (mcrn-ai)
│   └── Brewfile             # Homebrew dependencies
├── .tmux.conf
├── .zshrc
└── README.md
```

## Security Practices

- NEVER commit secrets, API keys, or personal tokens
- Use `.zshrc.local` for machine-specific settings (gitignored)
- Use 1Password CLI (`op`) for secret management
- Scripts should never hardcode credentials
- Backup directory is `.dotfiles.backup/`

## Git Workflow

This repo uses a **local repo as source of truth**:
- Repo path: `~/Development/dotfiles`
- Scripts and quotes live under `~/Development/dotfiles/.dotfiles`
- Use `dotfiles` alias instead of `git`

### Anti-Pattern: Bare Repo Worktree vs Staging Repo (Legacy)

If you point the bare repo worktree at `~/dotfiles-staging` while that directory
has its own `.git`, Git will report mass deletions because the index expects the
bare repo layout, not the staging repo layout. This is noisy and misleading.

Legacy path note: `~/dotfiles-staging` is no longer the source of truth.

This repo now uses `~/Development/dotfiles` as the source of truth.

**Do this instead:**
- Use the repo's own Git with `git -C ~/Development/dotfiles ...`
- Or use the bare repo with `--work-tree=$HOME` (default)

## Dependencies

Core tools used in scripts:
- `jq` - JSON processing
- `gh` - GitHub CLI
- `op` - 1Password CLI
- `opencode` - AI code assistant
- `brew` - Package management

Always check for tool availability before using:
```bash
if ! command -v tool_name &>/dev/null; then
    log_error "tool_name not found"
    exit 1
fi
```

## Testing Changes

1. Test scripts with `bash -n` for syntax
2. Run scripts in isolation before committing
3. Test on a fresh macOS VM if possible
4. Verify backup functionality works
5. Check that `.gitignore` properly excludes sensitive files
