# Device authentication

Use 1Password for portable SSH credentials and Git signing. Use a distinct,
non-exportable Secure Enclave SSH key per Mac for interactive administration.
Keep an independently tested recovery credential before retiring any old key.
An SSH key proves possession of a credential; it does not attest that macOS is
patched, the device is managed, or its current software is trustworthy.

## 1Password

The shared shell configuration selects the 1Password SSH agent. Keep its key
allowlist in `.config/1Password/ssh/agent.toml`. Choose per-application and
terminal-session approval, or per-request approval for sensitive credentials;
avoid approving every application when a coding agent needs just one task.

For a host restricted with `IdentitiesOnly yes`, download that item's **public
key** in 1Password and save it at the configured `IdentityFile`. The public file
must exist on every Mac: linking the agent config does not install it. Keep
machine-specific hostnames, public keys and SSH config outside this repository.

```sshconfig
Host server.example.invalid
    User admin
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    IdentityFile ~/.ssh/server.pub
    IdentitiesOnly yes
    ForwardAgent no
```

Do not disable identity selection to work around a missing file. Prefer
`ProxyJump` to agent forwarding for transit through a bastion. An authorized
agent can still sign requests for allowed processes; approval scope matters.

## Secure Enclave SSH trial

Run these commands in a local Terminal as the logged-in user, using Apple's
`/usr/bin` SSH tools. Creating the identity requires Touch ID. The `-ne` suffix
makes it non-exportable; `-t bio` requires biometric authorization. Do not
substitute `-t none` to accommodate unattended jobs.

First inspect existing identities. If the label already exists, reuse it rather
than creating duplicates. If enumeration fails, stop and resolve the error.

```sh
/usr/sbin/sc_auth list-ctk-identities
/usr/sbin/sc_auth create-ctk-identity -l ssh-device -k p-256-ne -t bio
/usr/sbin/sc_auth list-ctk-identities
```

Retrieve handles into a fresh temporary directory, not directly over existing
SSH files. This enumerates all eligible identities, so inspect the generated
filenames before copying the matching handle and `.pub` into `~/.ssh`.

```sh
trial_dir=$(mktemp -d)
(cd "$trial_dir" && /usr/bin/ssh-keygen -w /usr/lib/ssh-keychain.dylib -K -N '')
ls -l "$trial_dir"
```

The handle is device-bound; copying it does not back up the private key. The
public key is safe to register on the server. Add it alongside existing keys,
then create a separate host alias **before any matching wildcard defaults**:

```sshconfig
Host server-device
    HostName server.example.invalid
    User admin
    IdentityAgent none
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_ecdsa_sk_rk_ssh-device
    SecurityKeyProvider /usr/lib/ssh-keychain.dylib
    ForwardAgent no
```

Use the actual generated handle filename if it differs. The per-host provider
keeps 1Password as the default elsewhere. Test with
`/usr/bin/ssh -v server-device true`: verify it offers the hardware key, asks for Touch ID, and
reports successful public-key authentication. Test after locking/unlocking,
from the usual terminal, and in the normal docked or closed-lid arrangement.
Biometric availability can limit use with the lid closed. Never assume a
password fallback exists for a biometric-only key.

Register a separate recovery key/device and test it independently. Rebuilding
or losing the Mac can make its Secure Enclave identity unusable. Check the
identity's certificate validity and renewal behavior before relying on it.
Do not migrate scheduled jobs to an identity requiring a human fingerprint.

## Touch ID for sudo

Apple's `/etc/pam.d/sudo` includes `/etc/pam.d/sudo_local`. Configure the local
file using the supplied template, which is intended to survive system updates:

```sh
bash scripts/touchid-sudo.sh          # preview
bash scripts/touchid-sudo.sh --apply  # run locally; asks for sudo
```

The helper refuses an existing custom file. It is intentionally separate from
`install.sh`: linking dotfiles must not silently change administrator
authentication. It does not install pam_reattach or change SSH/sudo privileges.

In a fresh local Terminal, run `sudo -k` followed by `sudo -v` and confirm the
fingerprint succeeds. Test the password path as well. An active PAM line alone
does not prove biometric authentication works. Remote sessions, terminal
multiplexers and closed-lid use need separate testing; retain password access.

## References

- [1Password agent security](https://www.1password.dev/ssh/agent/security)
- [1Password per-host public-key selection](https://www.1password.dev/ssh/agent/advanced)
- [Apple persistent tokens](https://support.apple.com/guide/deployment/use-persistent-tokens-dep4e2622249/web)
- Local Apple manuals: `man sc_auth`, `man ssh-keychain`, `man ssh_config`.

## Enroll this Mac on another server

From a local Terminal, use the destination that already authenticates through
1Password:

```sh
bash ~/repos/dotfiles/scripts/ssh-enroll-device.sh admin@server.example.invalid
```

An SSH host alias works too. An optional second argument selects a different
local device-key handle. The helper uses existing SSH hostname, port and
jump-host settings, tries existing keys first, then permits account-password
or keyboard-interactive authentication for enrollment. A server that does not
trust the 1Password key can therefore still be enrolled using an existing
account login. The helper adds only the public key to the remote account's
`~/.ssh/authorized_keys`.
It backs up an existing file before appending and preserves a missing final
newline. Existing exact entries are not duplicated; a symlinked
`authorized_keys` is refused.
A .ssh directory symlink to persistent server storage is resolved and preserved.

It then opens a fresh connection with the device key and Apple's provider,
with other identities, certificates, agents and password fallback excluded.
Approve Touch ID. A successful verification does not change the destination's
default key selection; configure a separate device alias as above to use it
routinely. Servers with a custom authorized-key location or centrally managed
access need their own enrollment procedure. A failed verification leaves the
new public key registered and keeps previous keys; inspect before retrying.

The shared zsh alias is `ssh-device-add`. Open a new shell (or reload `.zshrc`),
then run `ssh-device-add admin@server.example.invalid`. The full script command
above also works before the alias is loaded.
