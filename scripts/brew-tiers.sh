#!/bin/bash
# Install or remove Brewfile tiers.
#
#   brew-tiers.sh list
#   brew-tiers.sh choose                       # pick tiers interactively; prints them
#   brew-tiers.sh install [--dry-run] TIER...
#   brew-tiers.sh uninstall [--apply] [--keep TIER,...|none] [--remove-tailscale] TIER...
#
# Tiers: core (Brewfile), workstation, dev, ci (Brewfile.<tier>). A Brewfile
# file name works anywhere a tier name does.
#
# uninstall removes only entries of the named tiers that no kept tier also
# lists. Without --keep, the layered tiers (core, workstation, dev) not being
# removed are kept. It previews unless --apply is given, and never touches
# anything outside the Brewfiles.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
ALL_TIERS=(core workstation dev ci)

die() { echo "error: $*" >&2; exit 1; }

tier_name() {
    case "$1" in
        core | Brewfile) echo core ;;
        workstation | dev | ci) echo "$1" ;;
        Brewfile.workstation | Brewfile.dev | Brewfile.ci) echo "${1#Brewfile.}" ;;
        *) die "unknown tier: $1 (expected one of: ${ALL_TIERS[*]})" ;;
    esac
}

brewfile_for() {
    if [[ "$1" == core ]]; then
        echo "$DOTFILES_ROOT/Brewfile"
    else
        echo "$DOTFILES_ROOT/Brewfile.$1"
    fi
}

# Prints "kind<TAB>name" for every entry; mas entries use their numeric id.
entries() {
    local tier file
    for tier in "$@"; do
        file="$(brewfile_for "$tier")"
        [[ -f "$file" ]] || die "missing Brewfile: $file"
        sed -nE \
            -e 's/^(tap|brew|cask)[[:space:]]+"([^"]+)".*/\1	\2/p' \
            -e 's/^mas[[:space:]]+"[^"]+",[[:space:]]*id:[[:space:]]*([0-9]+).*/mas	\1/p' \
            "$file"
    done | sort -u
}

# Sets RESOLVED to the tier names of the arguments; exits on an unknown one.
resolve_tiers() {
    RESOLVED=()
    local arg tier
    for arg in "$@"; do
        tier="$(tier_name "$arg")" || exit 1
        RESOLVED+=("$tier")
    done
}

cmd_list() {
    local tier
    for tier in "${ALL_TIERS[@]}"; do
        printf '%-12s %s\n' "$tier" "$(brewfile_for "$tier")"
    done
}

# A checkbox-style picker on stderr; the chosen tiers go to stdout.
cmd_choose() {
    local -a picked=(1 0 0 0)
    local i reply
    while true; do
        {
            echo "Brewfile tiers (type a number to toggle, Enter to accept):"
            for i in "${!ALL_TIERS[@]}"; do
                printf '  %d) [%s] %s\n' "$((i + 1))" "$([[ ${picked[i]} == 1 ]] && echo x || echo ' ')" "${ALL_TIERS[i]}"
            done
        } >&2
        read -r -p "> " reply
        [[ -z "$reply" ]] && break
        if [[ "$reply" =~ ^[1-4]$ ]]; then
            i=$((reply - 1))
            picked[i]=$((1 - picked[i]))
        fi
    done
    for i in "${!ALL_TIERS[@]}"; do
        [[ ${picked[i]} == 1 ]] && echo "${ALL_TIERS[i]}"
    done
    return 0
}

run() {
    if [[ "$DRY_RUN" == 1 ]]; then
        printf '[dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

cmd_install() {
    resolve_tiers "$@"
    local -a tiers=("${RESOLVED[@]+"${RESOLVED[@]}"}")
    [[ ${#tiers[@]} -gt 0 ]] || die "name at least one tier"
    command -v brew >/dev/null 2>&1 || die "Homebrew is required"

    # Homebrew refuses formulae from taps nobody trusted. Trust exactly the
    # taps these Brewfiles list, which were reviewed when they were added.
    local kind name tier
    while IFS=$'\t' read -r kind name; do
        [[ "$kind" == tap ]] && run brew trust --tap "$name"
    done < <(entries "${tiers[@]}")

    for tier in "${tiers[@]}"; do
        run brew bundle install --no-upgrade --file="$(brewfile_for "$tier")"
    done
}

cmd_uninstall() {
    local apply=0 keep_arg="" arg remove_tailscale=0
    local -a remove=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --apply) apply=1 ;;
            --remove-tailscale) remove_tailscale=1 ;;
            --keep) keep_arg="${2:?--keep needs a tier list}"; shift ;;
            *) remove+=("$1") ;;
        esac
        shift
    done
    [[ ${#remove[@]} -gt 0 ]] || die "name at least one tier to remove"
    resolve_tiers "${remove[@]}"
    remove=("${RESOLVED[@]}")

    # Without --keep, keep the layered tiers (core, workstation, dev) that are
    # not being removed. ci is only kept when named, since it is a separate
    # machine role rather than a layer.
    local -a keep=()
    if [[ "$keep_arg" == none ]]; then
        keep=()
    elif [[ -n "$keep_arg" ]]; then
        local -a named=()
        IFS=',' read -r -a named <<< "$keep_arg"
        resolve_tiers "${named[@]}"
        keep=("${RESOLVED[@]+"${RESOLVED[@]}"}")
    else
        for arg in core workstation dev; do
            [[ " ${remove[*]} " == *" $arg "* ]] || keep+=("$arg")
        done
    fi

    local -a doomed=()
    local line
    if [[ ${#keep[@]} -gt 0 ]]; then
        while IFS= read -r line; do doomed+=("$line"); done < <(comm -23 <(entries "${remove[@]}") <(entries "${keep[@]}"))
    else
        while IFS= read -r line; do doomed+=("$line"); done < <(entries "${remove[@]}")
    fi

    echo "Removing tiers: ${remove[*]}; keeping: ${keep[*]:-none}"
    if [[ ${#doomed[@]} -eq 0 ]]; then
        echo "Nothing to remove: every entry is also in a kept tier."
        return 0
    fi

    DRY_RUN=$((1 - apply))
    local entry kind name failed=0
    # Packages before taps, so a tap is only removed once nothing uses it.
    for entry in "${doomed[@]}"; do
        IFS=$'\t' read -r kind name <<< "$entry"
        case "$kind" in
            brew) run brew uninstall --formula "$name" || failed=1 ;;
            cask)
                # Tailscale is often the only way into a remote Mac (SSH,
                # Screen Sharing, a reattached tmux), and removing it cuts that
                # off mid-run. It goes only when asked for by name.
                if [[ "$name" == tailscale-app && "$remove_tailscale" != 1 ]]; then
                    echo "Keeping tailscale-app; pass --remove-tailscale to remove it too."
                else
                    run brew uninstall --cask "$name" || failed=1
                fi
                ;;
            mas) echo "App Store app $name: remove it from /Applications or run: sudo mas uninstall $name" ;;
        esac
    done
    for entry in "${doomed[@]}"; do
        IFS=$'\t' read -r kind name <<< "$entry"
        [[ "$kind" == tap ]] && { run brew untap "$name" || failed=1; }
    done

    if [[ "$apply" == 0 ]]; then
        echo "Preview only. Run again with --apply to remove these."
    elif [[ "$failed" == 1 ]]; then
        echo "Some entries were not removed, usually because a kept package depends on them." >&2
        return 1
    fi
}

RESOLVED=()
DRY_RUN=0
command="${1:-}"
[[ $# -gt 0 ]] && shift
case "$command" in
    list) cmd_list ;;
    choose) cmd_choose ;;
    install)
        if [[ "${1:-}" == --dry-run ]]; then
            DRY_RUN=1
            shift
        fi
        cmd_install "$@"
        ;;
    uninstall) cmd_uninstall "$@" ;;
    *)
        sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//' >&2
        exit 2
        ;;
esac
