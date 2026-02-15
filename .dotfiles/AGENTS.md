# AGENTS.md - Dotfiles Repository Guidelines

## Repository Overview

This is a macOS dotfiles repository using a bare git repository pattern. It configures Ghostty, zsh, modern CLI tools, and AI-powered shell enhancements.

## Build / Test / Lint Commands

This repository contains shell scripts and configuration files. There are no formal build or test commands.

### Validation Commands

```bash
# Check shell script syntax
bash -n scripts/install.sh
bash -n scripts/motd.sh
bash -n scripts/setup-git.sh
bash -n scripts/refresh-quotes.sh

# Validate JSON
jq empty quotes/tech-quotes.json

# Run shellcheck (if available)
shellcheck scripts/*.sh
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
~/.dotfiles/
├── scripts/           # Executable shell scripts
│   ├── install.sh    # Bootstrap installer
│   ├── motd.sh       # Daily message of the day
│   ├── setup-git.sh  # Git configuration helper
│   └── refresh-quotes.sh  # AI quote refresh
├── quotes/           # Data files
│   └── tech-quotes.json
├── zsh/              # Zsh plugins
│   └── plugins/
├── Brewfile          # Homebrew dependencies
└── .gitignore        # Excludes secrets and cache
```

## Security Practices

- NEVER commit secrets, API keys, or personal tokens
- Use `.zshrc.local` for machine-specific settings (gitignored)
- Use 1Password CLI (`op`) for secret management
- Scripts should never hardcode credentials
- Backup directory is `.dotfiles.backup/`

## Git Workflow

This repo uses a **bare repository pattern**:
- Git directory: `~/.dotfiles`
- Work tree: `$HOME`
- Use `dotfiles` alias instead of `git`
- Never show untracked files: `status.showUntrackedFiles no`

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
