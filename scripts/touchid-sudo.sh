#!/usr/bin/env bash
# Opt-in local PAM configuration; never rewrite Apple's main sudo stack.
set -euo pipefail

case "${1:-}" in
    '') apply=0 ;;
    --apply) apply=1 ;;
    *) echo 'Usage: bash scripts/touchid-sudo.sh [--apply]' >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { echo 'Too many arguments.' >&2; exit 2; }
[[ $(uname -s) == Darwin ]] || { echo 'macOS only.' >&2; exit 1; }

target=/etc/pam.d/sudo_local
template=/etc/pam.d/sudo_local.template
if [[ -L "$target" ]]; then
    echo 'sudo_local is a symlink; inspect it manually.' >&2
    exit 1
fi
if [[ -e "$target" ]]; then
    if grep -Eq '^auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so[[:space:]]*$' "$target"; then
        echo 'sudo_local already enables Touch ID. Test it in a fresh local Terminal.'
        exit 0
    fi
    echo 'sudo_local already exists; preserve it and review manually.' >&2
    exit 1
fi
[[ -f "$template" && ! -L "$template" ]] || { echo 'Apple sudo_local template is missing or a symlink.' >&2; exit 1; }
grep -Eq '^auth[[:space:]]+include[[:space:]]+sudo_local[[:space:]]*$' /etc/pam.d/sudo || {
    echo 'The sudo PAM stack does not include sudo_local; review manually.' >&2; exit 1;
}
[[ $(grep -Ec '^#auth[[:space:]]+sufficient[[:space:]]+pam_tid\.so[[:space:]]*$' "$template") == 1 ]] || {
    echo 'Unexpected sudo_local template; review manually.' >&2; exit 1;
}

echo 'Create /etc/pam.d/sudo_local from the Apple template, enabling pam_tid.so.'
echo 'The main sudo stack and its password fallback remain unchanged.'
if [[ "$apply" == 0 ]]; then
    sed 's/^#auth/auth/' "$template"
    echo 'Preview only. Run with --apply in a local Terminal to install (asks for sudo).'
    exit 0
fi

# Authenticate before preparing the file; never accept passwords as arguments.
sudo -v
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sed 's/^#auth/auth/' "$template" > "$tmp/sudo_local"
# Recheck after authentication to avoid replacing a file created in the meantime.
[[ ! -e "$target" && ! -L "$target" ]] || { echo 'sudo_local appeared; refusing to replace it.' >&2; exit 1; }
sudo install -o root -g wheel -m 444 "$tmp/sudo_local" "$target"
cmp -s "$tmp/sudo_local" "$target" || { echo 'Installed configuration differs.' >&2; exit 1; }
echo 'Installed. In a fresh local Terminal run: sudo -k; sudo -v'
echo 'Confirm the Touch ID prompt and fingerprint acceptance, then test password fallback.'
