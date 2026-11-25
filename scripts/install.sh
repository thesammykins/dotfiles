#!/usr/bin/env bash
# Links this repo's config into $HOME. Anything it replaces is copied to
# ~/.dotfiles.backup/<timestamp> first. new-mac runs this after Homebrew;
# it is safe to rerun.
set -euo pipefail

# Physical path, so links survive removing a symlinked parent such as the old
# ~/Development -> ~/repos compatibility links.
DOTFILES="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DRY_RUN="${DOTFILES_DRY_RUN:-0}"
APPLY_MACOS_DEFAULTS="${DOTFILES_APPLY_MACOS_DEFAULTS:-0}"
# Commit signing is linked only where this signer exists (not on CI runners).
GIT_SIGNER="${DOTFILES_GIT_SIGNER:-/Applications/1Password.app/Contents/MacOS/op-ssh-sign}"
BACKUP_DIR="$HOME/.dotfiles.backup/$(date +%Y%m%d_%H%M%S)"

run() {
    if [[ "$DRY_RUN" == 1 ]]; then
        printf '[dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# Physical path, so a checkout reached through a symlink, or a relative link,
# still counts as linked. A missing directory returns the path unchanged.
physical_path() {
    local dir
    if dir="$(cd -P -- "$(dirname -- "$1")" 2>/dev/null && pwd -P)"; then
        printf '%s/%s\n' "$dir" "$(basename -- "$1")"
    else
        printf '%s\n' "$1"
    fi
}

links_to() {
    local target
    [[ -L "$1" ]] || return 1
    target="$(readlink "$1")"
    [[ "$target" == /* ]] || target="$(dirname -- "$1")/$target"
    [[ "$(physical_path "$target")" == "$(physical_path "$2")" ]]
}

link() {
    local relative="$1" source="$DOTFILES/$1" target="$HOME/$1"
    if links_to "$target" "$source"; then
        # Already ours. Repoint a link spelled through another path (e.g. the
        # pre-move ~/Development checkout); there is nothing to back up.
        [[ "$(readlink "$target")" == "$source" ]] && return 0
        run ln -sfn "$source" "$target"
        echo "repointed $target"
        return 0
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        run mkdir -p "$(dirname "$BACKUP_DIR/$relative")"
        # cp -P keeps a replaced symlink as a symlink instead of its target.
        run cp -RP "$target" "$BACKUP_DIR/$relative"
        run rm -rf "$target"
    fi
    run mkdir -p "$(dirname "$target")"
    run ln -s "$source" "$target"
    echo "linked $target"
}

[[ "$(uname)" == Darwin ]] || { echo "macOS only." >&2; exit 1; }

while IFS= read -r relative; do
    [[ -n "$relative" ]] || continue
    if [[ "$relative" == .config/git/signing.gitconfig && ! -x "$GIT_SIGNER" ]]; then
        # The shared git config includes this file; git skips a missing
        # include, but every commit fails if it points at an absent signer.
        if links_to "$HOME/$relative" "$DOTFILES/$relative"; then
            run rm -f "$HOME/$relative"
            echo "unlinked commit signing: $GIT_SIGNER is missing"
        fi
        continue
    fi
    link "$relative"
done < "$DOTFILES/scripts/managed-paths.txt"

if [[ ! -e "$HOME/.zshrc.local" ]]; then
    run touch "$HOME/.zshrc.local"
fi
# Without this file, `git config --global` (gh auth login, for one) writes
# through the ~/.config/git/config link into this repo.
if [[ ! -e "$HOME/.gitconfig" ]]; then
    run touch "$HOME/.gitconfig"
fi

# ~/.ssh/config stays this Mac's own (Rex and OrbStack write to it too), so
# include the tracked tailnet hosts instead of linking it. ssh takes the first
# value it sees, so the include goes at the top.
ssh_include="Include ~/.ssh/tailnet.conf"
if ! grep -qxF "$ssh_include" "$HOME/.ssh/config" 2>/dev/null; then
    if [[ "$DRY_RUN" == 1 ]]; then
        echo "[dry-run] add '$ssh_include' to the top of ~/.ssh/config"
    else
        existing="$(cat "$HOME/.ssh/config" 2>/dev/null || true)"
        printf '%s\n%s\n' "$ssh_include" "$existing" > "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
        echo "included tailnet hosts in ~/.ssh/config"
    fi
fi

# 1Password registers its browser helper with the Chromium browsers it knows.
# Aside is not one of them, so hand it the same file once 1Password has run.
aside="$HOME/Library/Application Support/Aside"
if [[ -d "$aside" && ! -e "$aside/NativeMessagingHosts/com.1password.1password.json" ]]; then
    for host in "$HOME/Library/Application Support/Google"/Chrome*/NativeMessagingHosts/com.1password.1password.json; do
        [[ -f "$host" ]] || continue
        run mkdir -p "$aside/NativeMessagingHosts"
        run cp "$host" "$aside/NativeMessagingHosts/"
        echo "connected 1Password to Aside"
        break
    done
fi

if [[ "$APPLY_MACOS_DEFAULTS" == 1 ]]; then
    run mkdir -p "$HOME/Pictures/Screenshots"
    run defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    run defaults write com.apple.finder ShowPathbar -bool true
    run defaults write com.apple.finder ShowStatusBar -bool true
    run defaults write com.apple.finder _FXSortFoldersFirst -bool true
    run defaults write NSGlobalDomain AppleInterfaceStyle -string Dark
    run defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
    run defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.5
    run defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
    run defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    run defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    run defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
    run defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
    run defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
    run defaults write com.apple.menuextra.clock ShowSeconds -bool true
    run defaults write com.apple.menuextra.clock ShowDate -int 1
    run defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
    run defaults write com.apple.dock show-recents -bool false
    run defaults write com.apple.dock tilesize -int 62
    run defaults write com.apple.dock magnification -bool true
    run defaults write com.apple.dock largesize -int 78
    run defaults write com.apple.screencapture type -string png
    run defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
    [[ "$DRY_RUN" == 1 ]] || killall Finder Dock SystemUIServer >/dev/null 2>&1 || true
fi

[[ -d "$BACKUP_DIR" ]] && echo "Replaced files saved to $BACKUP_DIR"
echo "Dotfiles linked. Open a new shell to pick up changes."
