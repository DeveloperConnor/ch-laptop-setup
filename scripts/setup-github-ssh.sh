#!/usr/bin/env bash

set -euo pipefail

readonly SSH_DIR="${HOME}/.ssh"
readonly SSH_CONFIG="${SSH_DIR}/config"
readonly DEFAULT_GITHUB_KEY="${SSH_DIR}/github"

# Override this when the key has a different filename:
# GITHUB_SSH_KEY=~/.ssh/github_fips ./scripts/setup-github-ssh.sh
GITHUB_SSH_KEY="${GITHUB_SSH_KEY:-$DEFAULT_GITHUB_KEY}"

readonly BLOCK_START="# BEGIN ch-laptop-setup GitHub"
readonly BLOCK_END="# END ch-laptop-setup GitHub"

log() {
  printf '[github-ssh] %s\n' "$*"
}

fail() {
  printf '[github-ssh] ERROR: %s\n' "$*" >&2
  exit 1
}

command -v ssh >/dev/null 2>&1 ||
  fail "The OpenSSH client is not installed or is unavailable in PATH."

[[ -f "$GITHUB_SSH_KEY" ]] ||
  fail "Private key not found at $GITHUB_SSH_KEY"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chmod 600 "$GITHUB_SSH_KEY"

# Public keys are not required for connecting, but correct the permission if
# a matching public key is present.
if [[ -f "${GITHUB_SSH_KEY}.pub" ]]; then
  chmod 644 "${GITHUB_SSH_KEY}.pub"
fi

# Back up an existing SSH configuration before changing it.
if [[ -f "$SSH_CONFIG" ]]; then
  backup="${SSH_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
  cp -p "$SSH_CONFIG" "$backup"
  log "Backed up the existing SSH configuration to $backup"
else
  touch "$SSH_CONFIG"
fi

# Remove the block previously managed by this script. This makes the script
# safe to run again without creating duplicate GitHub entries.
temporary_config="$(mktemp)"

awk \
  -v start="$BLOCK_START" \
  -v end="$BLOCK_END" '
    $0 == start { managed_block = 1; next }
    $0 == end   { managed_block = 0; next }
    !managed_block { print }
  ' "$SSH_CONFIG" > "$temporary_config"

cat >> "$temporary_config" <<EOF

$BLOCK_START
Host github.com
    HostName github.com
    User git
    IdentityFile $GITHUB_SSH_KEY
    IdentitiesOnly yes
    KexAlgorithms ecdh-sha2-nistp256
$BLOCK_END
EOF

mv "$temporary_config" "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

log "Configured GitHub SSH access."
log "Private key: $GITHUB_SSH_KEY"
log "Key exchange: ecdh-sha2-nistp256"

# Validate the effective SSH configuration before attempting a connection.
effective_kex="$(
  ssh -G github.com 2>/dev/null |
    awk 'tolower($1) == "kexalgorithms" { print $2; exit }'
)"

[[ -n "$effective_kex" ]] ||
  fail "Unable to read the effective SSH key-exchange configuration."

case ",${effective_kex}," in
  *,ecdh-sha2-nistp256,*)
    log "Verified the effective FIPS-compatible key-exchange configuration."
    ;;
  *)
    fail "The effective SSH configuration does not include ecdh-sha2-nistp256: $effective_kex"
    ;;
esac

printf '\n'
log "Testing authentication to GitHub..."

# GitHub successfully authenticates SSH users but does not provide an
# interactive shell. Consequently, ssh -T can return a non-zero exit status
# even when authentication succeeds, so capture and inspect its output.
set +e
ssh_output="$(
  ssh \
    -o BatchMode=yes \
    -o ConnectTimeout=15 \
    -T git@github.com 2>&1
)"
ssh_status=$?
set -e

printf '%s\n' "$ssh_output"

if grep -qi "successfully authenticated" <<< "$ssh_output"; then
  printf '\n'
  log "GitHub SSH authentication succeeded."
  exit 0
fi

printf '\n'
printf '[github-ssh] GitHub SSH test did not report successful authentication.\n' >&2
printf '[github-ssh] SSH exit status: %s\n' "$ssh_status" >&2
printf '\n' >&2
printf '[github-ssh] Diagnostic command:\n' >&2
printf '\n' >&2
printf '  ssh -vvv -T git@github.com\n' >&2
printf '\n' >&2

exit 1