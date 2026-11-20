#!/usr/bin/env bash
# Installs Rex, the terminal, from the newest DMG in its own update feed. Rex
# has no Homebrew cask. An installed copy is left alone: Rex updates itself
# from the same feed. Apple silicon only; the feed has no Intel build.
#
# Rex puts its `rex` command on PATH only inside panes it creates, so other
# shells, hooks and agents can't find it. This links it into ~/.local/bin,
# which is where Rex itself installs the command on remote machines.
#
# It also installs rex-fingers (letter hints over paths and URLs, bound in
# init.lua), which has no prebuilt download: the Go program and its Lua plugin
# at one pinned tag.
#
#   scripts/install-rex.sh            install if missing
#   DOTFILES_DRY_RUN=1 scripts/...    say what would be downloaded
set -euo pipefail

# SUFeedURL from the app's Info.plist.
FEED="https://blob.superlogical.com/public/rex-app/preview-arm64/appcast.xml"
# Superlogical, Inc. The app must be signed by this team and notarized.
TEAM_ID="AG92C3PT77"
# The app was "Rex Beta" until preview.32 renamed it "Rex"; an installed copy
# keeps whichever name it had, so accept either.
APP_NAMES=("Rex.app" "Rex Beta.app")
APP="/Applications/${APP_NAMES[0]}"
for name in "${APP_NAMES[@]}"; do
    [[ -d "/Applications/$name" ]] && { APP="/Applications/$name"; break; }
done
LINK="$HOME/.local/bin/rex"

link_cli() {
    # Inside the signed app, which Rex updates in place, so the link survives updates.
    local CLI="$APP/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex"
    if [[ "${DOTFILES_DRY_RUN:-0}" == 1 ]]; then
        echo "[dry-run] link $LINK -> $CLI"
    elif [[ ! -x "$CLI" ]]; then
        echo "Rex has no command at $CLI; not linking." >&2
        exit 1
    elif [[ -e "$LINK" && ! -L "$LINK" ]]; then
        echo "Leaving $LINK alone: it is a real file, not a link."
    else
        mkdir -p "$(dirname "$LINK")"
        ln -sfn "$CLI" "$LINK"
        echo "Linked $LINK"
    fi
}

FINGERS_VERSION="v0.4.1"
FINGERS_PLUGIN="$HOME/.config/rex/plugins/rex-fingers"

install_fingers() {
    if [[ "${DOTFILES_DRY_RUN:-0}" == 1 ]]; then
        echo "[dry-run] install rex-fingers $FINGERS_VERSION"
        return
    fi
    if [[ "$("$HOME/.local/bin/rex-fingers" version 2>/dev/null)" != "$FINGERS_VERSION" ]]; then
        GOBIN="$HOME/.local/bin" mise exec go@1.26 -- \
            go install "github.com/xeind/rex-fingers@$FINGERS_VERSION"
    fi
    if [[ "$(git -C "$FINGERS_PLUGIN" describe --tags 2>/dev/null)" != "$FINGERS_VERSION" ]]; then
        rm -rf "$FINGERS_PLUGIN"
        git clone -q --branch "$FINGERS_VERSION" --depth 1 \
            https://github.com/xeind/rex-fingers "$FINGERS_PLUGIN"
    fi
    echo "rex-fingers $FINGERS_VERSION ready"
}

if [[ -d "$APP" ]]; then
    echo "Rex is already installed; it updates itself."
    link_cli
    install_fingers
    exit 0
fi
if [[ "$(uname -m)" != arm64 ]]; then
    echo "Rex's feed has only an Apple silicon build." >&2
    exit 1
fi

# Builds are named Rex-<version>-<build>.dmg; version sort puts the newest last.
url="$(curl -fsSL "$FEED" | grep -o 'https://[^"]*\.dmg' | sort -V | tail -n 1 || true)"
if [[ "$url" != https://blob.superlogical.com/* ]]; then
    echo "No Rex download found in $FEED" >&2
    exit 1
fi
if [[ "${DOTFILES_DRY_RUN:-0}" == 1 ]]; then
    echo "[dry-run] install $APP from $url"
    link_cli
    install_fingers
    exit 0
fi

work="$(mktemp -d)"
cleanup() {
    hdiutil detach -quiet "$work/mount" >/dev/null 2>&1 || true
    rm -rf "$work"
}
trap cleanup EXIT

echo "Downloading $url"
curl -fL --progress-bar -o "$work/rex.dmg" "$url"
mkdir "$work/mount"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$work/mount" "$work/rex.dmg"

source_app=""
for name in "${APP_NAMES[@]}"; do
    [[ -d "$work/mount/$name" ]] && { source_app="$work/mount/$name"; break; }
done
if [[ -z "$source_app" ]]; then
    echo "The Rex download has no ${APP_NAMES[*]}." >&2
    exit 1
fi
APP="/Applications/$(basename "$source_app")"
codesign --verify --deep --strict "$source_app"
team="$(codesign -dv --verbose=2 "$source_app" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
if [[ "$team" != "$TEAM_ID" ]]; then
    echo "Refusing to install: signed by team '$team', expected $TEAM_ID." >&2
    exit 1
fi
spctl --assess --type execute "$source_app"

ditto "$source_app" "$APP"
echo "Installed $APP"
link_cli
install_fingers
