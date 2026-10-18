#!/usr/bin/env bash
# -E carries the ERR traps into functions, so a failure while staging still
# reports and cleans up instead of exiting silently.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
MANAGED_PATHS_FILE="$SCRIPT_DIR/managed-paths.txt"
BACKUP_DIR="$HOME/.dotfiles.backup"
DRY_RUN=0
ASSUME_YES=0
ROLLBACK_DIR=""
RESTORE_ITEMS=()
RESTORE_TYPES=()
RESTORE_VALUES=()
STAGED_PATHS=()
ITEM_HAD_TARGET=()
SAVE_STARTED=()
PROMOTION_STARTED=()

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

usage() {
    echo "Usage: $0 [--dry-run] [--yes] [/path/to/backup]"
    echo "If omitted, uses the newest backup under ~/.dotfiles.backup that holds original files."
}

parse_args() {
    local backup_seen=0
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --yes) ASSUME_YES=1 ;;
            -h|--help) usage; exit 0 ;;
            --*) log_error "Unknown option: $1"; usage; exit 1 ;;
            *)
                [[ "$backup_seen" == "0" ]] || { log_error "Only one backup path may be supplied."; exit 1; }
                BACKUP_DIR="$1"
                backup_seen=1
                ;;
        esac
        shift
    done
}

backup_contains_managed_item() {
    local root="$1" relative
    while IFS= read -r relative || [[ -n "$relative" ]]; do
        [[ -n "$relative" ]] || continue
        [[ -e "$root/$relative" || -L "$root/$relative" || -f "$root/$relative.symlink" ]] && return 0
    done < "$MANAGED_PATHS_FILE"
    return 1
}

# Resolve symlinked directories in a path, so a checkout reached through a
# link (the installer records paths as it was invoked) compares equal to
# REPO_ROOT. A path whose directory no longer exists is returned unchanged.
physical_path() {
    local dir
    if dir="$(cd -P -- "$(dirname -- "$1")" 2>/dev/null && pwd -P)"; then
        printf '%s/%s\n' "$dir" "$(basename -- "$1")"
    else
        printf '%s\n' "$1"
    fi
}

# True when a backup holds something other than links back into this repo.
# Re-running the installer backs up the repo's own links, and restoring those
# would bring back nothing.
backup_has_originals() {
    local root="$1" relative marker link_target
    while IFS= read -r relative || [[ -n "$relative" ]]; do
        [[ -n "$relative" ]] || continue
        marker="$root/$relative.symlink"
        if [[ -f "$marker" ]]; then
            link_target="$(physical_path "$(cat "$marker")")"
            [[ "$link_target" == "$REPO_ROOT"/* ]] || return 0
        elif [[ -e "$root/$relative" || -L "$root/$relative" ]]; then
            return 0
        fi
    done < "$MANAGED_PATHS_FILE"
    return 1
}

resolve_backup_dir() {
    local root="$BACKUP_DIR" candidate
    [[ -d "$root" ]] || return 1
    if backup_contains_managed_item "$root"; then
        return 0
    fi
    while IFS= read -r candidate; do
        if backup_has_originals "$candidate"; then
            BACKUP_DIR="$candidate"
            return 0
        fi
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort -r)
    log_error "No backup under $root holds original files; newer backups only link back to this repo."
    return 1
}

resolved_link_target() {
    local relative="$1" link_target="$2"
    if [[ "$link_target" == /* ]]; then
        printf '%s\n' "$link_target"
    else
        printf '%s/%s\n' "$(dirname "$HOME/$relative")" "$link_target"
    fi
}

preflight() {
    [[ -f "$MANAGED_PATHS_FILE" ]] || { log_error "Managed paths file is missing: $MANAGED_PATHS_FILE"; return 1; }
    local relative source marker link_target target_index
    while IFS= read -r relative || [[ -n "$relative" ]]; do
        [[ -n "$relative" ]] || continue
        source="$BACKUP_DIR/$relative"
        marker="$source.symlink"
        if [[ (-e "$source" || -L "$source") && -f "$marker" ]]; then
            log_error "Backup has both content and a symlink marker: $relative"
            return 1
        fi
        if [[ -f "$marker" ]]; then
            if [[ "$(wc -l < "$marker" | tr -d ' ')" != "1" ]]; then
                log_error "Invalid symlink marker (expected one line): $relative"
                return 1
            fi
            link_target="$(cat "$marker")"
            [[ -n "$link_target" ]] || { log_error "Empty symlink target: $relative"; return 1; }
            if [[ ! -e "$(resolved_link_target "$relative" "$link_target")" ]]; then
                log_error "Backup symlink target does not exist: $relative -> $link_target"
                return 1
            fi
            RESTORE_ITEMS+=("$relative")
            RESTORE_TYPES+=("link")
            RESTORE_VALUES+=("$link_target")
        elif [[ -e "$source" || -L "$source" ]]; then
            RESTORE_ITEMS+=("$relative")
            RESTORE_TYPES+=("copy")
            RESTORE_VALUES+=("$source")
        fi
    done < "$MANAGED_PATHS_FILE"
    target_index="${#RESTORE_ITEMS[@]}"
    [[ "$target_index" -gt 0 ]] || { log_error "Backup contains no managed paths: $BACKUP_DIR"; return 1; }
}

confirm_restore() {
    [[ "$DRY_RUN" == "1" || "$ASSUME_YES" == "1" ]] && return 0
    if [[ ! -t 0 ]]; then
        log_error "Restore requires --yes when stdin is not interactive."
        return 1
    fi
    local response
    read -r -p "Restore ${#RESTORE_ITEMS[@]} managed path(s) from $BACKUP_DIR? [y/N] " response
    [[ "$response" == "y" || "$response" == "yes" ]] || { log_error "Restore cancelled."; return 1; }
}

stage_replacements() {
    local index relative target stage
    for ((index = 0; index < ${#RESTORE_ITEMS[@]}; index++)); do
        relative="${RESTORE_ITEMS[$index]}"
        target="$HOME/$relative"
        stage="$(dirname "$target")/.$(basename "$target").restore-new.$$"
        [[ ! -e "$stage" && ! -L "$stage" ]] || { log_error "Staging path already exists: $stage"; return 1; }
        mkdir -p "$(dirname "$target")"
        if [[ "${RESTORE_TYPES[$index]}" == "link" ]]; then
            ln -s "${RESTORE_VALUES[$index]}" "$stage"
        else
            cp -R "${RESTORE_VALUES[$index]}" "$stage"
        fi
        STAGED_PATHS+=("$stage")
    done
}

cleanup_staging() {
    local stage cleanup_failed=0
    for stage in ${STAGED_PATHS[@]+"${STAGED_PATHS[@]}"}; do
        if [[ -e "$stage" || -L "$stage" ]]; then
            rm -rf "$stage" || cleanup_failed=1
        fi
    done
    return "$cleanup_failed"
}

abort_staging() {
    local trapped_status=$?
    local exit_status="${1:-$trapped_status}"
    trap - ERR INT TERM HUP
    set +e
    if cleanup_staging; then
        log_error "Restore staging failed; no live files were changed."
    else
        log_error "Restore staging failed; no live files were changed, but staging cleanup is incomplete."
    fi
    exit "$exit_status"
}

rollback_applied() {
    local trapped_status=$?
    local exit_status="${1:-$trapped_status}" index relative target saved rollback_failed=0 promoted=0
    trap - ERR INT TERM HUP
    set +e
    for ((index = ${#SAVE_STARTED[@]} - 1; index >= 0; index--)); do
        relative="${RESTORE_ITEMS[$index]}"
        target="$HOME/$relative"
        saved="$ROLLBACK_DIR/$relative"
        promoted=0
        if [[ "${PROMOTION_STARTED[$index]:-0}" == "1" && (-e "$target" || -L "$target") ]]; then
            if [[ "${ITEM_HAD_TARGET[$index]:-0}" == "0" || -e "$saved" || -L "$saved" ]]; then
                promoted=1
            fi
        fi

        if [[ "$promoted" == "1" ]] && ! rm -rf "$target"; then
            log_error "Rollback could not remove promoted replacement: $relative"
            rollback_failed=1
            continue
        fi
        if [[ -e "$saved" || -L "$saved" ]]; then
            if [[ -e "$target" || -L "$target" ]]; then
                log_error "Rollback found both live and saved originals; left both untouched: $relative"
                rollback_failed=1
                continue
            fi
            if ! mkdir -p "$(dirname "$target")" || ! mv "$saved" "$target"; then
                log_error "Rollback could not restore original; recovery copy retained at: $saved"
                rollback_failed=1
            fi
        elif [[ "${ITEM_HAD_TARGET[$index]:-0}" == "1" && "${SAVE_STARTED[$index]:-0}" == "1" && ! -e "$target" && ! -L "$target" ]]; then
            log_error "Rollback cannot locate the original for: $relative"
            rollback_failed=1
        fi
    done
    cleanup_staging || rollback_failed=1
    if [[ "$rollback_failed" == "1" ]]; then
        log_error "Restore failed; rollback is incomplete. Recovery files retained at: $ROLLBACK_DIR"
    else
        log_error "Restore failed; applied changes were rolled back. Rollback retained at: $ROLLBACK_DIR"
    fi
    exit "$exit_status"
}

apply_restore() {
    local index relative target saved stage rollback_root
    rollback_root="$HOME/.dotfiles.restore-rollback"
    mkdir -p "$rollback_root"
    ROLLBACK_DIR="$(mktemp -d "$rollback_root/restore.XXXXXXXX")"
    trap 'rollback_applied $?' ERR
    trap 'rollback_applied 130' INT
    trap 'rollback_applied 143' TERM
    trap 'rollback_applied 129' HUP
    for ((index = 0; index < ${#RESTORE_ITEMS[@]}; index++)); do
        relative="${RESTORE_ITEMS[$index]}"
        target="$HOME/$relative"
        saved="$ROLLBACK_DIR/$relative"
        stage="${STAGED_PATHS[$index]}"
        ITEM_HAD_TARGET[index]=0
        SAVE_STARTED[index]=0
        PROMOTION_STARTED[index]=0
        if [[ -e "$target" || -L "$target" ]]; then
            ITEM_HAD_TARGET[index]=1
            mkdir -p "$(dirname "$saved")"
            SAVE_STARTED[index]=1
            mv "$target" "$saved"
        fi
        PROMOTION_STARTED[index]=1
        mv "$stage" "$target"
        log_info "Restored: $relative"
    done
    trap - ERR INT TERM HUP
    cleanup_staging
    log_info "Rollback retained at: $ROLLBACK_DIR"
}

main() {
    parse_args "$@"
    resolve_backup_dir || { log_error "Backup directory not found or empty: $BACKUP_DIR"; exit 1; }
    preflight
    log_step "Restore plan from $BACKUP_DIR"
    local relative
    for relative in "${RESTORE_ITEMS[@]}"; do
        if [[ "$DRY_RUN" == "1" ]]; then
            log_info "Would restore: $relative"
        else
            log_info "Ready to restore: $relative"
        fi
    done
    confirm_restore
    [[ "$DRY_RUN" == "1" ]] && { log_info "Dry-run complete; no files changed."; return 0; }
    trap 'abort_staging $?' ERR
    trap 'abort_staging 130' INT
    trap 'abort_staging 143' TERM
    trap 'abort_staging 129' HUP
    stage_replacements
    trap - ERR INT TERM HUP
    apply_restore
    log_info "Restore complete."
}

main "$@"
