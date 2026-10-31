#!/usr/bin/env bash
# Moves toolchain installs and build caches onto the ~/repos APFS volume and
# leaves a symlink at each default path. Previews by default; --apply moves.
#
# Adapted from elithrar/dotfiles tool-storage.sh (MIT). Unlike upstream it sets
# no environment variables: symlinks keep absolute paths baked into mise
# shims and shebangs valid, work for GUI apps that never read shell config
# (Xcode, Android Studio), and leave mise in charge of npm's global prefix.
set -euo pipefail

repos="$HOME/repos"
tools="$repos/.tools"
apply=false
case "${1:-}" in
    "") ;;
    --apply) apply=true ;;
    *) echo "usage: $0 [--apply]" >&2; exit 2 ;;
esac

fail() { printf 'tool storage: %s\n' "$*" >&2; exit 1; }

# Moving onto an unmounted ~/repos would land on the internal disk, under a
# directory repos-volume.sh made root-owned. The marker proves it's our volume.
[[ "$(df -P "$repos" 2>/dev/null | awk 'NR == 2 { print $NF }')" == "$repos" &&
    -e "$repos/.dotfiles-repos-volume" ]] || fail "$repos is not mounted. Run scripts/repos-volume.sh first."

$apply || echo "Preview only; rerun with --apply after quitting Xcode, Android Studio and running 'gradle --stop'."
# Each line: default location<TAB>name under ~/repos/.tools
while IFS=$'\t' read -r original name; do
    target="$tools/$name"
    if [[ -L "$original" ]]; then
        [[ "$(readlink "$original")" == "$target" ]] || fail "$original links elsewhere: $(readlink "$original")"
        echo "linked   $original"
    elif [[ ! -e "$original" ]]; then
        # Not installed here; rerun after installing it.
        echo "absent   $original"
    elif [[ -e "$target" || -L "$target" ]]; then
        # Usually an interrupted cross-volume move: mv copies first, so the
        # original is still complete. Remove the partial target, then rerun.
        fail "both $original and $target exist; check which is complete."
    elif $apply; then
        mkdir -p "$tools"
        mv "$original" "$target"
        ln -s "$target" "$original"
        echo "moved    $original"
    else
        echo "move     $original -> $target"
    fi
done <<EOF
$HOME/.local/share/mise	mise
$HOME/Library/Caches/mise	mise-cache
$HOME/.cargo	cargo
$HOME/.rustup	rustup
$HOME/.npm	npm
$HOME/Library/pnpm	pnpm
$HOME/Library/Caches/pnpm	pnpm-cache
$HOME/.cache/uv	uv-cache
$HOME/Library/Caches/pip	pip-cache
$HOME/go	go
$HOME/Library/Caches/go-build	go-build-cache
$HOME/.bun/install/cache	bun-cache
$HOME/.gradle	gradle
$HOME/Library/Caches/org.swift.swiftpm	swiftpm-cache
$HOME/Library/Developer/Xcode/DerivedData	xcode-derived-data
EOF
