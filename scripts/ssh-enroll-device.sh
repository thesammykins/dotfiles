#!/usr/bin/env bash
# Run from a local Terminal so 1Password and Touch ID can ask for approval.
set -euo pipefail

[[ $# -ge 1 && $# -le 2 ]] || { echo 'Usage: bash scripts/ssh-enroll-device.sh [user@]host [key-handle]' >&2; exit 2; }
target=$1
key=${2:-$HOME/.ssh/id_ecdsa_sk_rk_ssh-device}
[[ -n "$target" && "$target" != -* && "$target" != *[[:space:]]* ]] || { echo 'Invalid SSH destination.' >&2; exit 2; }
[[ "$target" != *\"* && "$target" != *\\* && "$target" != *\** && "$target" != *\?* && "$target" != *\!* ]] || { echo 'Use a literal SSH destination, not a pattern.' >&2; exit 2; }
[[ -f "$key" && -f "$key.pub" ]] || { echo 'Device handle or public key is missing.' >&2; exit 1; }
[[ $(awk 'NF {n++} END {print n+0}' "$key.pub") == 1 ]] || { echo 'Expected one public key.' >&2; exit 1; }
IFS= read -r public_key < "$key.pub" || [[ -n "$public_key" ]]
[[ "$public_key" == 'sk-ecdsa-sha2-nistp256@openssh.com '* ]] || { echo 'Expected an Apple Secure Enclave ECDSA-SK public key.' >&2; exit 1; }
ssh-keygen -l -f "$key.pub" >/dev/null

# This script is passed as a quoted argument to sh, independent of the remote
# login shell. Keep it free of single quotes; only the public key uses stdin.
# Expansion belongs to the remote shell.
# shellcheck disable=SC2016

remote_script='
set -eu
umask 077
IFS= read -r key
case "$key" in sk-ecdsa-sha2-nistp256@openssh.com\ *) ;; *) echo "Unexpected public key" >&2; exit 1;; esac
mkdir -p "$HOME/.ssh"
directory=$(cd "$HOME/.ssh" && pwd -P)
file="$directory/authorized_keys"
if [ -L "$file" ] || { [ -e "$file" ] && [ ! -f "$file" ]; }; then
    echo "Refusing a non-regular authorized_keys; review server configuration" >&2; exit 1
fi
if [ -f "$file" ] && grep -qxF "$key" "$file"; then
    echo "Device public key already registered"
else
    if [ -f "$file" ]; then
        backup=$(mktemp "$HOME/.ssh/authorized_keys.before-device.XXXXXX")
        cp -p "$file" "$backup"
        echo "Previous authorized_keys backed up to $backup"
    fi
    printf "\n%s\n" "$key" >> "$file"
    echo "Device public key registered"
fi
'

# Enrollment needs an existing login, which may be a key, password or MFA.
# Only the final device-key verification must exclude password fallback.
ssh_options=(-T -S none -o ClearAllForwardings=yes -o RemoteCommand=none)
enroll_options=(-o BatchMode=no -o "PreferredAuthentications=publickey,keyboard-interactive,password"
    -o PasswordAuthentication=yes -o KbdInteractiveAuthentication=yes)
verify_options=(-o PreferredAuthentications=publickey -o PasswordAuthentication=no
    -o KbdInteractiveAuthentication=no)

# Build the verification config before changing the server. Remove every old
# identity and certificate so success must use this device key. The temporary
# config contains local host details and is removed on exit.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ssh -G "$target" > "$tmp/effective"
{
    printf 'Host "%s"\n' "${target##*@}"
    awk '$1 !~ /^(host|identityfile|certificatefile|identityagent|identitiesonly|securitykeyprovider)$/ {print}' "$tmp/effective"
    # Jump hosts retain their original identities and aliases. The target
    # never reads the original config, which could append other identities.
    printf 'Host * "!%s"\n    Include ~/.ssh/config /etc/ssh/ssh_config\n' "${target##*@}"
} > "$tmp/verify"

# Only the constant script expands here; the key uses stdin.
# shellcheck disable=SC2029

if ! printf '%s\n' "$public_key" | ssh "${ssh_options[@]}" "${enroll_options[@]}" "$target" "sh -c '$remote_script'"; then
    echo 'Enrollment did not complete; device-key login has not been verified.' >&2
    echo 'Use the SSH error above to check the hostname, port and route for connection failures, or the account and credentials for authentication failures. Run in a local Terminal for prompts.' >&2
    exit 1
fi
echo 'Verifying a fresh login with the device key. Approve Touch ID.'
if ! ssh "${ssh_options[@]}" "${verify_options[@]}" -F "$tmp/verify" -o IdentityAgent=none \
    -o IdentitiesOnly=yes -o CanonicalizeHostname=no -o SecurityKeyProvider=/usr/lib/ssh-keychain.dylib \
    -i "$key" "$target" true; then
    echo 'Device login failed; existing server keys were kept. Review the server authorized-key path/policy and Touch ID availability.' >&2
    exit 1
fi
echo 'Verified: device-key SSH authentication succeeded.'
