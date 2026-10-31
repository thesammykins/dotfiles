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

# --global would write through ~/.config/git/config, a link into this repo,
# when ~/.gitconfig doesn't exist yet; machine settings belong in ~/.gitconfig.
dotfiles_alias="!git -C \"$DOTFILES\""
if [[ "$(git config --file "$HOME/.gitconfig" --get alias.dotfiles 2>/dev/null)" != "$dotfiles_alias" ]]; then
    run git config --file "$HOME/.gitconfig" alias.dotfiles "$dotfiles_alias"
fi

if [[ ! -e "$HOME/.zshrc.local" ]]; then
    run touch "$HOME/.zshrc.local"
fi

if [[ "$APPLY_MACOS_DEFAULTS" == 1 ]]; then
    run mkdir -p "$HOME/Pictures/Screenshots"
    run defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    run defaults write com.apple.finder ShowPathbar -bool true
    run defaults write com.apple.finder ShowStatusBar -bool true
    run defaults write com.apple.finder _FXSortFoldersFirst -bool true
    run defaults write com.apple.dock show-recents -bool false
    run defaults write com.apple.screencapture type -string png
    run defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
    [[ "$DRY_RUN" == 1 ]] || killall Finder Dock SystemUIServer >/dev/null 2>&1 || true
fi

[[ -d "$BACKUP_DIR" ]] && echo "Replaced files saved to $BACKUP_DIR"
echo "Dotfiles linked. Open a new shell to pick up changes."
