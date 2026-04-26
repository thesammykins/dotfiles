#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
VARLOCK_PATH="${VARLOCK_PATH:-$DOTFILES_ROOT/.config/varlock/opencode}"
VARLOCK_FALLBACK_PATH="${VARLOCK_FALLBACK_PATH:-$DOTFILES_ROOT/.config/varlock}"
MCRN_OPENCODE_RESOLVE_CONTEXT7="${MCRN_OPENCODE_RESOLVE_CONTEXT7:-0}"
MCRN_OPENCODE_VARLOCK_TIMEOUT_SEC="${MCRN_OPENCODE_VARLOCK_TIMEOUT_SEC:-2}"
MCRN_OPENCODE_SERVER_MODE="${MCRN_OPENCODE_SERVER_MODE:-1}"
MCRN_OPENCODE_SERVER_HOST="${MCRN_OPENCODE_SERVER_HOST:-127.0.0.1}"
MCRN_OPENCODE_SERVER_PORT="${MCRN_OPENCODE_SERVER_PORT:-4097}"
MCRN_OPENCODE_SERVER_START_TIMEOUT_SEC="${MCRN_OPENCODE_SERVER_START_TIMEOUT_SEC:-8}"
MCRN_OPENCODE_SERVER_LOG="${MCRN_OPENCODE_SERVER_LOG:-/tmp/mcrn-opencode-serve.log}"

_run_with_timeout() {
	local timeout_sec="$1"
	shift

	if ! command -v python3 >/dev/null 2>&1; then
		return 1
	fi

	python3 - "$timeout_sec" "$@" <<'PY'
import subprocess
import sys

timeout = float(sys.argv[1])
cmd = sys.argv[2:]

try:
    out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, timeout=timeout, text=True)
except Exception:
    raise SystemExit(1)

sys.stdout.write(out)
PY
}

_resolve_context7_key() {
	local key="${CONTEXT7_API_KEY:-}"
	local path=""

	[[ -n "$key" ]] && return 0
	command -v varlock >/dev/null 2>&1 || return 1

	if [[ -d "$VARLOCK_PATH" || -f "$VARLOCK_PATH" ]]; then
		path="$VARLOCK_PATH"
	elif [[ -d "$VARLOCK_FALLBACK_PATH" || -f "$VARLOCK_FALLBACK_PATH" ]]; then
		path="$VARLOCK_FALLBACK_PATH"
	else
		return 1
	fi

	key="$(_run_with_timeout "$MCRN_OPENCODE_VARLOCK_TIMEOUT_SEC" varlock printenv --path "$path" CONTEXT7_API_KEY || true)"
	key="${key//$'\n'/}"
	[[ -n "$key" ]] || return 1
	export CONTEXT7_API_KEY="$key"
	return 0
}

_is_interactive_launch() {
	if [[ $# -eq 0 ]]; then
		return 0
	fi

	case "$1" in
	-h | --help | --version | debug | providers | auth | models | stats | session | plugin | agent | mcp | completion | upgrade | uninstall | serve | attach | run | web | pr | db)
		return 1
		;;
	esac

	if [[ $# -eq 1 && ("$1" == "." || "$1" == ".." || -d "$1") ]]; then
		return 0
	fi

	return 1
}

_resolve_target_dir() {
	if [[ $# -eq 0 ]]; then
		printf '%s\n' "$PWD"
		return
	fi

	if [[ "$1" == "." || "$1" == ".." || -d "$1" ]]; then
		local resolved
		if resolved="$(cd "$1" 2>/dev/null && pwd -P)"; then
			printf '%s\n' "$resolved"
		else
			printf '%s\n' "$PWD"
		fi
		return
	fi

	printf '%s\n' "$PWD"
}

_server_is_ready() {
	command -v nc >/dev/null 2>&1 || return 1
	nc -z "$MCRN_OPENCODE_SERVER_HOST" "$MCRN_OPENCODE_SERVER_PORT" >/dev/null 2>&1
}

_ensure_server() {
	local elapsed=0

	if _server_is_ready; then
		return 0
	fi

	nohup opencode serve --hostname "$MCRN_OPENCODE_SERVER_HOST" --port "$MCRN_OPENCODE_SERVER_PORT" >"$MCRN_OPENCODE_SERVER_LOG" 2>&1 &

	while ((elapsed < MCRN_OPENCODE_SERVER_START_TIMEOUT_SEC * 10)); do
		if _server_is_ready; then
			return 0
		fi
		sleep 0.1
		elapsed=$((elapsed + 1))
	done

	return 1
}

if [[ "$MCRN_OPENCODE_RESOLVE_CONTEXT7" == "1" ]]; then
	_resolve_context7_key >/dev/null 2>&1 || true
fi

if [[ "$MCRN_OPENCODE_SERVER_MODE" == "1" ]] && _is_interactive_launch "$@"; then
	if _ensure_server; then
		target_dir="$(_resolve_target_dir "$@")"
		exec opencode attach "http://${MCRN_OPENCODE_SERVER_HOST}:${MCRN_OPENCODE_SERVER_PORT}" --dir "$target_dir"
	fi
fi

exec opencode "$@"
