#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${DOTFILES_REPO_ROOT:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"

if [[ ! -e "$REPO_ROOT/.git" ]]; then
  echo "[ERROR] Dotfiles repo not found at: $REPO_ROOT" >&2
  exit 1
fi

warn() { echo "[WARN] $*"; }
info() { echo "[INFO] $*"; }
ok() { echo "[OK]   $*"; }

load_runtime_formulas() {
  local formulas_file="$REPO_ROOT/scripts/runtime-formulas.txt"
  local line

  if [[ ! -f "$formulas_file" ]]; then
    warn "Missing runtime formulas file: $formulas_file"
    return 1
  fi

  RUNTIME_FORMULAS=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    RUNTIME_FORMULAS+=("$line")
  done < "$formulas_file"
}

fetch_version_signal() {
  local url="$1"
  local mode="$2"
  local value=""

  if ! value="$(curl -fsSL "$url" 2>/dev/null)"; then
    warn "Unable to fetch upstream version signal from $url"
    return 1
  fi

  case "$mode" in
    ghostty)
      printf '%s\n' "$value" | sed -n 's/^[[:space:]]*version "\([^"]*\)".*/\1/p' | head -n1
      ;;
    tarball)
      printf '%s\n' "$value" | extract_version_from_url
      ;;
    jq)
      printf '%s\n' "$value" | sed -n 's/^[[:space:]]*url ".*jq-\([0-9.]*\)\.tar\.gz".*/\1/p' | head -n1
      ;;
  esac
}

extract_minimum_major() {
  local version_spec="$1"
  printf '%s\n' "$version_spec" | grep -oE '[0-9]+' | head -n1
}

extract_version_from_url() {
  sed -n 's/.*\/v\{0,1\}\([0-9][^\"/]*\)\.tar\.gz.*/\1/p' | head -n1
}

check_ghostty_policy() {
  local cfg="$REPO_ROOT/.config/ghostty/config"
  printf '\n== Ghostty policy checks ==\n'

  [[ -f "$cfg" ]] || { warn "Missing $cfg"; return; }

  local required=(
    'background = #1a0b0c'
    'foreground = #ffd34e'
    'unfocused-split-opacity = 0.85'
    'shell-integration = detect'
    'shell-integration-features = cursor,sudo,title,ssh-env'
    'font-family = "TX02 Nerd Font"'
    'cursor-style-blink = false'
    'scrollback-limit = 10000000'
    'window-inherit-working-directory = true'
    'macos-titlebar-style = native'
    'confirm-close-surface = true'
    'copy-on-select = clipboard'
  )

  for line in "${required[@]}"; do
    if [[ "$line" == 'shell-integration-features = cursor,sudo,title,ssh-env' ]]; then
      local feature_line features required_features feature missing_features=()
      feature_line="$(grep -E '^shell-integration-features[[:space:]]*=' "$cfg" | head -n1 || true)"
      features="${feature_line#*=}"
      features="${features//[[:space:]]/}"
      required_features="cursor sudo title ssh-env"
      for feature in $required_features; do
        if [[ ",$features," != *",$feature,"* ]]; then
          missing_features+=("$feature")
        fi
      done
      if [[ "${#missing_features[@]}" -eq 0 ]]; then
        ok "$line"
      else
        warn "Missing Ghostty shell integration features: ${missing_features[*]}"
      fi
      continue
    fi

    if grep -Fqx "$line" "$cfg"; then
      ok "$line"
    else
      warn "Missing required Ghostty setting: $line"
    fi
  done

}

check_install_reliability() {
  printf '\n== Install reliability checks ==\n'

  if grep -Eq 'gtimeout[[:space:]]+5[[:space:]]+op account list|perl.*alarm shift; exec @ARGV.*op account list' "$REPO_ROOT/scripts/install.sh"; then
    ok "install.sh uses a timeout check compatible with macOS"
  else
    warn "install.sh timeout check may be incompatible with macOS"
  fi

  if grep -q "DOTFILES=\"\$HOME/.dotfiles\"" "$REPO_ROOT/.zshrc"; then
    ok "DOTFILES path points to canonical repo location"
  else
    warn "DOTFILES path in .zshrc is not canonical"
  fi

  if grep -Eq "source \"\\\$HOME/\\.zshrc\"|source \"\\\$ZDOTDIR/\\.zshrc\"|source \"\\\$HOME/\\.config/[^ ]*zshrc\"" "$REPO_ROOT/.zprofile"; then
    warn ".zprofile sources .zshrc; login shells will double-load shell init"
  else
    ok ".zprofile does not source .zshrc"
  fi

  if grep -Eq '[[:space:]]*=[[:space:]]*"(latest|lts)"' "$REPO_ROOT/.config/mise/config.toml"; then
    warn "mise config uses floating versions (latest/lts); this can cause machine drift"
  else
    ok "mise config appears pinned for reproducibility"
  fi
}

check_version_signals() {
  printf '\n== Upstream version signals ==\n'

  # Version checks are pulled from upstream formula/cask definitions so this audit can run without brew installed.
  local ghostty mise starship jq opencode orbstack
  ghostty="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/g/ghostty.rb ghostty || true)"
  mise="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/m/mise.rb tarball || true)"
  starship="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/s/starship.rb tarball || true)"
  jq="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/j/jq.rb jq || true)"
  opencode="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/o/opencode.rb tarball || true)"
  orbstack="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/o/orbstack.rb ghostty || true)"

  info "Homebrew cask latest Ghostty: ${ghostty:-unknown}"
  info "Homebrew formula latest mise: ${mise:-unknown}"
  info "Homebrew formula latest starship: ${starship:-unknown}"
  info "Homebrew formula latest jq: ${jq:-unknown}"
  info "Homebrew formula latest opencode: ${opencode:-unknown}"
  info "Homebrew cask latest OrbStack: ${orbstack:-unknown}"

  local declared_copilot latest_copilot
  if ! command -v jq &>/dev/null || ! command -v npm &>/dev/null; then
    warn "Skipping @github/copilot-sdk version signal check; jq and/or npm not found on PATH"
    return 0
  fi

  declared_copilot="$(jq -r '.dependencies["@github/copilot-sdk"] // empty' "$REPO_ROOT/zsh/plugins/mcrn-ai/package.json")"
  latest_copilot="$(npm view @github/copilot-sdk version --json 2>/dev/null | tr -d '"')"

  if [[ -n "$declared_copilot" ]]; then
    local normalized_declared
    normalized_declared="${declared_copilot#^}"
    normalized_declared="${normalized_declared#~}"
    info "Declared @github/copilot-sdk: $declared_copilot"
    info "npm latest @github/copilot-sdk: ${latest_copilot:-unknown}"
    if [[ -n "$latest_copilot" && "$normalized_declared" != "$latest_copilot" ]]; then
      warn "@github/copilot-sdk is behind latest; evaluate upgrade risk"
    fi
  fi
}


check_runtime_migration() {
  printf '\n== Runtime migration checks (Homebrew -> mise) ==\n'

  load_runtime_formulas || return 0

  if ! command -v brew &>/dev/null; then
    warn "brew not installed in this environment; runtime overlap check skipped"
    return 0
  fi

  local installed
  installed="$(brew list --formula 2>/dev/null || true)"

  local overlaps=()
  local installed_formula runtime_formula installed_family runtime_family
  while IFS= read -r installed_formula || [[ -n "$installed_formula" ]]; do
    [[ -n "$installed_formula" ]] || continue
    installed_family="${installed_formula%@*}"
    for runtime_formula in "${RUNTIME_FORMULAS[@]}"; do
      runtime_family="${runtime_formula%@*}"
      if [[ "$installed_formula" == "$runtime_formula" || "$installed_family" == "$runtime_family" ]]; then
        overlaps+=("$installed_formula")
        break
      fi
    done
  done <<< "$installed"

  if [[ "${#overlaps[@]}" -eq 0 ]]; then
    ok "No Homebrew runtime overlap detected (mise migration clean)"
    return 0
  fi

  local removable=()
  local dependency_owned=()
  local users
  for installed_formula in "${overlaps[@]}"; do
    users="$(brew uses --installed "$installed_formula" 2>/dev/null || true)"
    if [[ -n "$users" ]]; then
      dependency_owned+=("$installed_formula")
    else
      removable+=("$installed_formula")
    fi
  done

  if [[ "${#removable[@]}" -gt 0 ]]; then
    warn "Found removable Homebrew runtime formulas that should move to mise: ${removable[*]}"
    warn "Use scripts/migrate-to-mise.sh to reconcile package replacement"
  else
    ok "No removable Homebrew runtime overlap detected"
  fi

  if [[ "${#dependency_owned[@]}" -gt 0 ]]; then
    info "Homebrew still owns dependency runtimes required by formulas: ${dependency_owned[*]}"
  fi
}

check_mcrn_ai_sdk_alignment() {
  printf '\n== MCRN AI Copilot SDK alignment ==\n'

  local helper="$REPO_ROOT/zsh/plugins/mcrn-ai/lib/copilot-helper.mjs"
  local package_json="$REPO_ROOT/zsh/plugins/mcrn-ai/package.json"

  if grep -Fq 'mode: "append"' "$helper"; then
    ok "copilot-helper uses systemMessage append mode (SDK guardrails retained)"
  else
    warn "copilot-helper is not using append mode; may bypass SDK default guardrails"
  fi

  if grep -Eq 'session\.disconnect\(\)|disconnectSession' "$helper"; then
    ok "copilot-helper uses current session disconnect lifecycle"
  else
    warn "copilot-helper does not use current session disconnect lifecycle"
  fi

  if grep -Eq 'MCRN_COPILOT_MODEL.*gpt-5-mini|process\.env\.MCRN_COPILOT_MODEL \|\| "gpt-5-mini"' "$helper" "$REPO_ROOT/zsh/plugins/mcrn-ai.zsh"; then
    ok "gpt-5-mini is the canonical default Copilot model"
  else
    warn "gpt-5-mini default model is not configured consistently"
  fi

  if grep -Eq '_mcrn_ai_call_local|_mcrn_ensure_server|MCRN_AI_PROVIDER|MCRN_LLM_' "$REPO_ROOT/zsh/plugins/mcrn-ai.zsh"; then
    warn "Legacy local-model fallback code still exists in the zsh widget"
  else
    ok "Legacy local-model fallback code has been removed from the zsh widget"
  fi

  if grep -Eq '"node"[[:space:]]*:[[:space:]]*">=[[:space:]]*20(\.[0-9]+\.[0-9]+)?"|"node"[[:space:]]*:[[:space:]]*"\^20"' "$package_json"; then
    ok "package.json declares a Node 20+ baseline for the Copilot SDK path"
  else
    warn "package.json does not clearly declare the Node 20+ baseline for the Copilot SDK path"
  fi

  local declared_engine declared_sdk sdk_engine
  if ! command -v jq &>/dev/null || ! command -v npm &>/dev/null; then
    warn "Skipping package metadata checks; jq and/or npm not found on PATH"
    return 0
  fi

  declared_engine="$(jq -r '.engines.node // empty' "$package_json")"
  declared_sdk="$(jq -r '.dependencies["@github/copilot-sdk"] // empty' "$package_json")"
  sdk_engine="$(npm view @github/copilot-sdk engines.node --json 2>/dev/null | tr -d '"')"

  if [[ -n "$declared_engine" ]]; then
    info "Declared plugin node engine: $declared_engine"
  fi
  if [[ -n "$declared_sdk" ]]; then
    info "Declared @github/copilot-sdk: $declared_sdk"
  fi
  if [[ -n "$sdk_engine" ]]; then
    info "npm @github/copilot-sdk node engine: $sdk_engine"
  fi

  local min_major sdk_min_major
  min_major="$(extract_minimum_major "$declared_engine")"
  sdk_min_major="$(extract_minimum_major "$sdk_engine")"

  if [[ -n "$min_major" && -n "$sdk_min_major" && "$min_major" -ge "$sdk_min_major" ]]; then
    ok "Plugin node engine matches Copilot SDK requirement baseline"
  else
    warn "Plugin node engine may be incompatible with current Copilot SDK"
  fi
}
pathway() {
  cat <<'TXT'

== Migration pathway (new + existing Macs) ==
1) On existing Macs, run this audit first and capture output to a ticket/docs.
2) Install base + dev + workstation bundles with safe links first:
   DOTFILES_LINK_MODE=safe DOTFILES_INSTALL_DEV=1 DOTFILES_INSTALL_WORKSTATION=1 ~/.dotfiles/scripts/install.sh
3) Install Dia manually, launch it once, then restore the saved profile if needed.
4) Reconcile package replacement with mise using scripts/migrate-to-mise.sh.
5) Resolve any skipped links manually, then rerun with force only if needed.
6) After install: run bats tests and a manual Ghostty verification pass.
TXT
}

check_ghostty_policy
check_install_reliability
check_version_signals
check_runtime_migration
check_mcrn_ai_sdk_alignment
pathway
