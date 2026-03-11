#!/bin/bash
set -euo pipefail

REPO_ROOT="${DOTFILES_REPO_ROOT:-$HOME/Development/dotfiles}"

if [[ ! -e "$REPO_ROOT/.git" ]]; then
  echo "[ERROR] Dotfiles repo not found at: $REPO_ROOT" >&2
  exit 1
fi

warn() { echo "[WARN] $*"; }
info() { echo "[INFO] $*"; }
ok() { echo "[OK]   $*"; }

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
    tmux)
      printf '%s\n' "$value" | sed -n 's/^[[:space:]]*url ".*releases\/download\/\([^/]*\)\/.*".*/\1/p' | head -n1
      ;;
    jq)
      printf '%s\n' "$value" | sed -n 's/^[[:space:]]*url ".*jq-\([0-9.]*\)\.tar\.gz".*/\1/p' | head -n1
      ;;
    llama)
      printf '%s\n' "$value" | sed -n 's/^[[:space:]]*tag:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
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
    'shell-integration-features = cursor,sudo,title'
    'font-family = "TX02 Nerd Font"'
    'cursor-style-blink = false'
    'scrollback-limit = 10000000'
  )

  for line in "${required[@]}"; do
    if grep -Fqx "$line" "$cfg"; then
      ok "$line"
    else
      warn "Missing required Ghostty setting: $line"
    fi
  done

  local library_cfg="$REPO_ROOT/Library/Application Support/com.mitchellh.ghostty/config"
  if [[ -f "$library_cfg" ]]; then
    if cmp -s "$cfg" "$library_cfg"; then
      ok "Repo mirror config matches source Ghostty config"
    else
      warn "Repo mirror Ghostty config is drifted from .config/ghostty/config"
    fi
  fi
}

check_install_reliability() {
  printf '\n== Install reliability checks ==\n'

  if grep -Eq 'gtimeout[[:space:]]+5[[:space:]]+op account list|perl.*alarm shift; exec @ARGV.*op account list' "$REPO_ROOT/.dotfiles/scripts/install.sh"; then
    ok "install.sh uses a timeout check compatible with macOS"
  else
    warn "install.sh timeout check may be incompatible with macOS"
  fi

  if grep -q 'DOTFILES="$HOME/Development/dotfiles"' "$REPO_ROOT/.zshrc"; then
    ok "DOTFILES path points to canonical repo location"
  else
    warn "DOTFILES path in .zshrc is not canonical"
  fi

  if grep -Eq ' = "(latest|lts)"' "$REPO_ROOT/.config/mise/config.toml"; then
    warn "mise config uses floating versions (latest/lts); this can cause machine drift"
  else
    ok "mise config appears pinned for reproducibility"
  fi
}

check_version_signals() {
  printf '\n== Upstream version signals ==\n'

  # Version checks are pulled from upstream formula/cask definitions so this audit can run without brew installed.
  local ghostty mise starship tmux jq llama
  ghostty="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-cask/master/Casks/g/ghostty.rb ghostty || true)"
  mise="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/m/mise.rb tarball || true)"
  starship="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/s/starship.rb tarball || true)"
  tmux="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/t/tmux.rb tmux || true)"
  jq="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/j/jq.rb jq || true)"
  llama="$(fetch_version_signal https://raw.githubusercontent.com/Homebrew/homebrew-core/master/Formula/l/llama.cpp.rb llama || true)"

  info "Homebrew cask latest Ghostty: ${ghostty:-unknown}"
  info "Homebrew formula latest mise: ${mise:-unknown}"
  info "Homebrew formula latest starship: ${starship:-unknown}"
  info "Homebrew formula latest tmux: ${tmux:-unknown}"
  info "Homebrew formula latest jq: ${jq:-unknown}"
  info "Homebrew formula latest llama.cpp tag: ${llama:-unknown}"

  local declared_copilot latest_copilot
  if ! command -v jq &>/dev/null || ! command -v npm &>/dev/null; then
    warn "Skipping @github/copilot-sdk version signal check; jq and/or npm not found on PATH"
    return 0
  fi

  declared_copilot="$(jq -r '.dependencies["@github/copilot-sdk"] // empty' "$REPO_ROOT/.dotfiles/zsh/plugins/mcrn-ai/package.json")"
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

  local runtime_formulas=(
    node
    python
    python@3
    go
    openjdk
    temurin
    terraform
    gradle
    dotnet
    asdf
    fnm
    pyenv
    rbenv
  )

  if ! command -v brew &>/dev/null; then
    warn "brew not installed in this environment; runtime overlap check skipped"
    return 0
  fi

  local installed
  installed="$(brew list --formula 2>/dev/null || true)"

  local overlaps=()
  local formula
  for formula in "${runtime_formulas[@]}"; do
    if echo "$installed" | grep -Fxq "$formula"; then
      overlaps+=("$formula")
    fi
  done

  if [[ "${#overlaps[@]}" -gt 0 ]]; then
    warn "Found runtime formulas still on Homebrew: ${overlaps[*]}"
    warn "Use .dotfiles/scripts/migrate-to-mise.sh to reconcile package replacement"
  else
    ok "No Homebrew runtime overlap detected (mise migration clean)"
  fi
}

check_mcrn_ai_sdk_alignment() {
  printf '\n== MCRN AI Copilot SDK alignment ==\n'

  local helper="$REPO_ROOT/.dotfiles/zsh/plugins/mcrn-ai/copilot-helper.mjs"
  local package_json="$REPO_ROOT/.dotfiles/zsh/plugins/mcrn-ai/package.json"

  if grep -Fq 'mode: "append"' "$helper"; then
    ok "copilot-helper uses systemMessage append mode (SDK guardrails retained)"
  else
    warn "copilot-helper is not using append mode; may bypass SDK default guardrails"
  fi

  if grep -Fq 'session.disconnect()' "$helper"; then
    ok "copilot-helper uses session.disconnect() per current SDK guidance"
  else
    warn "copilot-helper does not call session.disconnect(); check SDK lifecycle usage"
  fi

  if grep -Eq '"node"[[:space:]]*:[[:space:]]*">=[[:space:]]*20(\.[0-9]+\.[0-9]+)?"|"node"[[:space:]]*:[[:space:]]*"\^20"' "$package_json"; then
    ok "zsh plugin does not require global copilot CLI binary"
  else
    warn "zsh plugin may still depend on a global copilot CLI setup"
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
2) Pin mise runtime versions in .config/mise/config.toml before rollout.
3) Run installer with safe links first:
   DOTFILES_LINK_MODE=safe SKIP_MODEL_DOWNLOAD=1 ~/.dotfiles/scripts/install.sh
4) Resolve any skipped links manually, then rerun with force only if needed.
5) After install: run bats tests and a manual Ghostty verification pass.
6) Roll into bootstrap automation (MDM/Ansible) by calling install.sh + this audit script.
TXT
}

check_ghostty_policy
check_install_reliability
check_version_signals
check_runtime_migration
check_mcrn_ai_sdk_alignment
pathway
