#!/usr/bin/env bats

setup() {
    DOTFILES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    export REMOTE_HOME="$BATS_TEST_TMPDIR/server"
    export VERIFY_CONFIG="$BATS_TEST_TMPDIR/verify-config"
    export SSH_CALLS="$BATS_TEST_TMPDIR/ssh-calls"
    key="$BATS_TEST_TMPDIR/device"
    mkdir -p "$BATS_TEST_TMPDIR/bin" "$REMOTE_HOME/.ssh"
    touch "$key"
    printf '%s\n' 'sk-ecdsa-sha2-nistp256@openssh.com FAKEPUBLICKEY ssh:' > "$key.pub"
    cat > "$BATS_TEST_TMPDIR/bin/ssh-keygen" <<'MOCK'
#!/bin/sh
exit 0
MOCK
    cat > "$BATS_TEST_TMPDIR/bin/ssh" <<'MOCK'
#!/bin/bash
set -eu
printf 'call\n' >> "$SSH_CALLS"
printf '%s\n' "$@" >> "$SSH_CALLS"
if [[ $1 == -G ]]; then
    printf 'host example.invalid\nhostname example.invalid\nuser admin\nidentityfile /old/private/key\ncertificatefile /old/certificate\nidentityagent /old/agent\n'
    exit 0
fi
for ((i=1; i<=$#; i++)); do
    arg=${!i}
    if [[ $arg == -F ]]; then
        ((i+=1))
        cp "${!i}" "$VERIFY_CONFIG"
        if [[ " $* " != *' PreferredAuthentications=publickey '* || " $* " != *' PasswordAuthentication=no '* || " $* " != *' KbdInteractiveAuthentication=no '* ]]; then
            echo 'Verification permitted a non-key login' >&2
            exit 1
        fi
        exit "${VERIFY_FAILURE:-0}"
    fi
done
if [[ ${ENROLL_FAILURE:-0} != 0 ]]; then exit 255; fi
if [[ ${REQUIRE_PASSWORD:-0} == 1 ]]; then
    if [[ " $* " != *' PreferredAuthentications=publickey,keyboard-interactive,password '* || " $* " != *' PasswordAuthentication=yes '* || " $* " != *' KbdInteractiveAuthentication=yes '* || " $* " != *' BatchMode=no '* ]]; then
        echo 'Server rejects keys; password login was disabled' >&2
        exit 255
    fi
    echo 'Existing account password authenticated'
fi
HOME="$REMOTE_HOME" /bin/sh -c "${!#}"
MOCK
    chmod +x "$BATS_TEST_TMPDIR/bin/ssh" "$BATS_TEST_TMPDIR/bin/ssh-keygen"
}

@test "enrollment preserves an existing key without a final newline and backs it up" {
    printf 'ssh-ed25519 EXISTING' > "$REMOTE_HOME/.ssh/authorized_keys"
    run bash "$DOTFILES_DIR/scripts/ssh-enroll-device.sh" admin@example.invalid "$key"
    [ "$status" -eq 0 ]
    [ "$(head -n 1 "$REMOTE_HOME/.ssh/authorized_keys")" = 'ssh-ed25519 EXISTING' ]
    [ "$(tail -n 1 "$REMOTE_HOME/.ssh/authorized_keys")" = "$(cat "$key.pub")" ]
    backup=$(find "$REMOTE_HOME/.ssh" -name 'authorized_keys.before-device.*')
    [ "$(cat "$backup")" = 'ssh-ed25519 EXISTING' ]
    ! rg 'identityfile|identityagent|certificatefile' "$VERIFY_CONFIG"
}

@test "repeated enrollment does not append or back up an existing device key again" {
    cp "$key.pub" "$REMOTE_HOME/.ssh/authorized_keys"
    run bash "$DOTFILES_DIR/scripts/ssh-enroll-device.sh" admin@example.invalid "$key"
    [ "$status" -eq 0 ]
    cmp "$key.pub" "$REMOTE_HOME/.ssh/authorized_keys"
    [ -z "$(find "$REMOTE_HOME/.ssh" -name 'authorized_keys.before-device.*')" ]
}

@test "refuses a symlinked authorized_keys without changing its target" {
    printf 'existing\n' > "$BATS_TEST_TMPDIR/other"
    ln -s "$BATS_TEST_TMPDIR/other" "$REMOTE_HOME/.ssh/authorized_keys"
    run bash "$DOTFILES_DIR/scripts/ssh-enroll-device.sh" admin@example.invalid "$key"
    [ "$status" -ne 0 ]
    [ "$(cat "$BATS_TEST_TMPDIR/other")" = existing ]
}

@test "supports a .ssh directory symlink to persistent server storage" {
    mv "$REMOTE_HOME/.ssh" "$REMOTE_HOME/persistent-ssh"
    ln -s persistent-ssh "$REMOTE_HOME/.ssh"
    run bash "$DOTFILES_DIR/scripts/ssh-enroll-device.sh" admin@example.invalid "$key"
    [ "$status" -eq 0 ]
    [ -L "$REMOTE_HOME/.ssh" ]
    [ "$(tail -n 1 "$REMOTE_HOME/persistent-ssh/authorized_keys")" = "$(cat "$key.pub")" ]
}

@test "failed hardware login is reported as failure while existing keys are preserved" {
    export VERIFY_FAILURE=255
    printf 'ssh-ed25519 EXISTING\n' > "$REMOTE_HOME/.ssh/authorized_keys"
    run bash "$DOTFILES_DIR/scripts/ssh-enroll-device.sh" admin@example.invalid "$key"
    [ "$status" -ne 0 ]
    [[ "$output" == *'Device login failed'* ]]
    [ "$(head -n 1 "$REMOTE_HOME/.ssh/authorized_keys")" = 'ssh-ed25519 EXISTING' ]
}

@test "rejects destination options before invoking ssh" {
    run bash "$DOTFILES_DIR/scripts/ssh-enroll-device.sh" '-oProxyCommand=bad' "$key"
    [ "$status" -eq 2 ]
    [ ! -e "$SSH_CALLS" ]
}

@test "enrollment permits password bootstrap but verification still requires the device key" {
    export REQUIRE_PASSWORD=1
    run bash "$DOTFILES_DIR/scripts/ssh-enroll-device.sh" admin@example.invalid "$key"
    [ "$status" -eq 0 ]
    [[ "$output" == *'Existing account password authenticated'* ]]
    [[ "$output" == *'Verified: device-key SSH authentication succeeded.'* ]]
    [ -f "$REMOTE_HOME/.ssh/authorized_keys" ]
}

@test "failed bootstrap reports the prerequisite and does not attempt verification" {
    export ENROLL_FAILURE=1
    run bash "$DOTFILES_DIR/scripts/ssh-enroll-device.sh" admin@example.invalid "$key"
    [ "$status" -ne 0 ]
    [[ "$output" == *'Enrollment did not complete'* ]]
    [[ "$output" != *'Verifying a fresh login'* ]]
    [ ! -e "$REMOTE_HOME/.ssh/authorized_keys" ]
    [ ! -e "$VERIFY_CONFIG" ]
}
