# Dotfiles - 2026 Ready Terminal Setup

A modern, portable terminal configuration featuring Ghostty, Catppuccin theme, zsh with AI integration, and a curated stack of 2026-ready CLI tools.

![Ghostty Terminal](https://user-images.githubusercontent.com/your-username/ghostty-screenshot.png)

## ✨ Features

- **Ghostty** - Modern GPU-accelerated terminal with Catppuccin Mocha theme
- **zsh** - Enhanced with autosuggestions, syntax highlighting, and AI-powered command generation
- **Modern CLI Stack** - eza, bat, ripgrep, fd, btop, dust (all Rust-based, blazing fast)
- **Smart Navigation** - zoxide learns your habits for instant directory jumping
- **AI Integration** - zsh-ask-opencode for natural language → shell commands (Ctrl+O)
- **Daily MOTD** - System info via Fastfetch + curated tech quotes
- **Weekly AI Quotes** - Refresh your quote cache with GPT-5 mini generated quotes
- **1Password Integration** - CLI support for secure secret management
- **Bare Git Repo** - Clean, portable setup with no symlink complexity

## 🚀 Quick Start

### Prerequisites

- macOS 12+ (Monterey or later)
- Internet connection for initial setup
- GitHub account (for git configuration)

### One-Command Install

```bash
# Clone the bare repository
git clone --bare https://github.com/sammykins/dotfiles.git ~/.dotfiles

# Define the alias in current shell scope
alias dotfiles='git --git-dir="$HOME/.dotfiles" --work-tree="$HOME"'

# Checkout the content
dotfiles checkout

# Configure git to not show untracked files
dotfiles config --local status.showUntrackedFiles no

# Run the bootstrap script
~/.dotfiles/scripts/install.sh
```

### Post-Install Setup

After the bootstrap completes:

```bash
# 1. Restart your terminal
exec zsh

# 2. Configure Git
gh auth login
~/.dotfiles/scripts/setup-git.sh

# 3. Set up 1Password (optional)
op account add

# 4. Refresh your quotes (weekly)
~/.dotfiles/scripts/refresh-quotes.sh
```

## 🎮 Usage

### AI Command Generation (Ctrl+O)

Press `Ctrl+O` and type what you want in natural language:

```bash
# Type this:
find all files modified in the last 3 days

# Press Ctrl+O → AI generates:
find . -type f -mtime -3
```

### Smart Directory Navigation (zoxide)

```bash
# Jump to frequently used directories
z proj          # Jumps to ~/Projects (learns from your habits)
z dow           # Jumps to ~/Downloads
zi              # Interactive selection with fzf

# Traditional cd also works (zoxide is aliased as cd)
cd ~/Documents  # Works as expected, but also learns the path
```

### Modern CLI Aliases

| Traditional | Modern | Description |
|------------|---------|-------------|
| `ls` | `eza` | Icons, git status, colors |
| `cat` | `bat` | Syntax highlighting, pager |
| `grep` | `rg` | 10x faster, respects .gitignore |
| `find` | `fd` | Intuitive syntax, fast |
| `top` | `btop` | Beautiful TUI, mouse support |
| `du` | `dust` | Tree view, intuitive sizes |

### Daily MOTD

Every 24 hours, you'll see:
- System information (via Fastfetch)
- A random tech quote
- Tip to refresh quotes weekly

### Tmux Shortcuts

Prefix key: `Ctrl+A` (screen-style)

| Shortcut | Action |
|----------|--------|
| `Ctrl+A c` | New window |
| `Ctrl+A n/p` | Next/previous window |
| `Ctrl+A \|` | Split vertical |
| `Ctrl+A -` | Split horizontal |
| `Ctrl+A h/j/k/l` | Navigate panes |
| `Ctrl+A r` | Reload config |

## 📁 Structure

```
~/.dotfiles/                    # Bare git repository
├── Library/Application Support/ghostty/config   # Ghostty configuration
├── .zshrc                       # Main shell configuration
├── .zprofile                    # Login shell configuration
├── .tmux.conf                   # Tmux configuration
├── .config/starship.toml        # Prompt configuration
├── scripts/
│   ├── install.sh              # Bootstrap script
│   ├── setup-git.sh            # Git configuration helper
│   ├── motd.sh                 # Daily message of the day
│   └── refresh-quotes.sh       # Weekly AI quote refresh
├── quotes/
│   └── tech-quotes.json        # Curated tech quotes (50+)
├── Brewfile                     # Homebrew dependencies
└── README.md                    # This file
```

## 🔧 Managing Your Dotfiles

### Using the `dotfiles` alias

```bash
# Check status
dotfiles status

# Add a modified file
dotfiles add .zshrc
dotfiles commit -m "Update zsh config"
dotfiles push

# Pull updates
dotfiles pull
```

### Adding New Files

```bash
# 1. Move file to home directory
cp ~/some-config ~/.myconfig

# 2. Add to dotfiles tracking
dotfiles add ~/.myconfig
dotfiles commit -m "Add myconfig"
dotfiles push
```

### Local Overrides

Edit `~/.zshrc.local` for machine-specific settings. This file is gitignored.

```bash
# ~/.zshrc.local
export MY_WORK_API_KEY="..."
alias work="cd ~/Work/project"
```

## 🔐 Secrets & 1Password

### Option 1: Environment Variables (Recommended for Projects)

Use 1Password Environments to mount `.env` files:

```bash
# In 1Password Desktop app
# 1. Create Environment for your project
# 2. Add secrets
# 3. Configure local .env file destination
```

### Option 2: Secret References

Use `op://` URLs in your scripts:

```bash
export API_KEY=$(op read "op://vault/item/field")
```

### Option 3: 1Password CLI in Scripts

```bash
op run --env-file=.env -- ./your-script.sh
```

## 🛠️ Troubleshooting

### Shell startup is slow

Measure startup time:
```bash
time zsh -i -c exit
```

If > 300ms, profile with:
```bash
zmodload zsh/zprof
# ... restart shell ...
zprof
```

### AI command generation not working

1. Ensure opencode is installed: `which opencode`
2. Check opencode is configured: `opencode config get model`
3. Verify zsh-ask-opencode is loaded: `bindkey '^O'`

### Quotes not showing

1. Check jq is installed: `brew install jq`
2. Verify quotes file exists: `ls ~/.dotfiles/quotes/tech-quotes.json`
3. Run MOTD manually: `~/.dotfiles/scripts/motd.sh`

### Git configuration issues

Run the setup script manually:
```bash
~/.dotfiles/scripts/setup-git.sh
```

### Homebrew not found

If Homebrew isn't in your PATH after install:
```bash
# For Apple Silicon
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# For Intel
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/usr/local/bin/brew shellenv)"
```

## 🔄 Keeping Updated

```bash
# Update dotfiles
dotfiles pull

# Update Homebrew packages
brew update && brew upgrade

# Update zsh plugins (if using git submodules)
# cd ~/.zsh/plugins && git pull

# Refresh AI quotes (weekly)
~/.dotfiles/scripts/refresh-quotes.sh
```

## 📝 Customization

### Change Tmux Prefix

Edit `~/.tmux.conf`:
```conf
# Change from Ctrl+A to Ctrl+B (default)
unbind C-a
set -g prefix C-b
bind C-b send-prefix
```

### Modify Starship Prompt

Edit `~/.config/starship.toml`:
```toml
[character]
success_symbol = "[>](bold green)"
error_symbol = "[>](bold red)"
```

### Add More Quotes

Edit `~/.dotfiles/quotes/tech-quotes.json`:
```json
{
  "quote": "Your custom quote here",
  "author": "Your Name"
}
```

## 🎯 2026 Tool Stack

| Category | Tool | Why |
|----------|------|-----|
| Terminal | Ghostty | GPU-accelerated, native macOS, Catppuccin |
| Shell | zsh | Default on macOS, rich ecosystem |
| Prompt | Starship | Fast, customizable, cross-platform |
| AI | zsh-ask-opencode | Natural language → shell commands |
| CD | zoxide | Learns your habits, frecency algorithm |
| LS | eza | Icons, git integration, tree view |
| Cat | bat | Syntax highlighting, pager |
| Grep | ripgrep | 10x faster, respects .gitignore |
| Find | fd | Intuitive, fast, colorful |
| Top | btop | Beautiful TUI, mouse support |
| Du | dust | Tree view, intuitive |
| Diff | delta | Syntax-highlighted git diffs |
| Node | fnm | Fast Node version manager |
| Python | uv | Ultra-fast pip replacement |

## 📜 License

MIT - Do whatever you want with this setup!

## 🙏 Credits

- [Ghostty](https://ghostty.org/) by Mitchell Hashimoto
- [Catppuccin](https://catppuccin.com/) theme
- [zsh-ask-opencode](https://github.com/andreacasarin/zsh-ask-opencode) by Andrea Casarin
- All the amazing Rust CLI tool authors

## 💬 Questions?

- [Open an issue](https://github.com/sammykins/dotfiles/issues)
- Check the [Ghostty docs](https://ghostty.org/docs)
- Join the [zoxide discussions](https://github.com/ajeetdsouza/zoxide/discussions)