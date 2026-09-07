#!/usr/bin/env bash

set -euo pipefail

# VS Code launches this script directly, so ~/.zshrc is not loaded.
# Initialise Linuxbrew explicitly before locating Distrobox.
BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"

if [[ -x "$BREW_BIN" ]]; then
  eval "$("$BREW_BIN" shellenv)"
fi

# Include standard and user-local locations as a fallback.
export PATH="$HOME/.local/bin:$HOME/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

readonly DEVBOX_NAME="devbox"
readonly DEVBOX_IMAGE="devbox:latest"
readonly SETUP_REPO="$HOME/Documents/git/ch-laptop-setup"
readonly DOCKER_SOCKET="/var/run/docker.sock"

log() {
  printf '[devbox] %s\n' "$*"
}

fail_to_host_shell() {
  printf '[devbox] ERROR: %s\n' "$1" >&2
  printf '[devbox] Opening a VDE Zsh session instead.\n' >&2
  exec /usr/bin/zsh -l
}

# Avoid recursively entering Devbox if this script is invoked from inside it.
if [[ -n "${CONTAINER_ID:-}" ]]; then
  exec /usr/bin/zsh -l
fi

# Check host dependencies.
command -v docker >/dev/null 2>&1 ||
  fail_to_host_shell "Docker is not installed or is not available in PATH."

command -v distrobox >/dev/null 2>&1 ||
  fail_to_host_shell "Distrobox is not installed or is not available in PATH."

# Check whether the Distrobox container already exists.
if docker container inspect "$DEVBOX_NAME" >/dev/null 2>&1; then
  log "Entering existing Devbox."

  exec distrobox enter \
    --name "$DEVBOX_NAME" \
    -- /usr/bin/zsh -l
fi

log "Devbox does not currently exist."

# Do not trigger an unexpected image build just because a terminal was opened.
if ! docker image inspect "$DEVBOX_IMAGE" >/dev/null 2>&1; then
  printf '\n'
  printf 'The Docker image %s has not been built.\n' "$DEVBOX_IMAGE"
  printf '\n'
  printf 'Build it with:\n'
  printf '\n'
  printf '  cd %s\n' "$SETUP_REPO"
  printf '  docker build --tag %s .\n' "$DEVBOX_IMAGE"
  printf '\n'

  fail_to_host_shell "The Devbox image is unavailable."
fi

# Add the group that owns the host Docker socket to the new container.
create_args=(
  --yes
  --name "$DEVBOX_NAME"
  --image "$DEVBOX_IMAGE"
)

if [[ -S "$DOCKER_SOCKET" ]]; then
  docker_gid="$(stat -c '%g' "$DOCKER_SOCKET")"

  log "Docker socket group ID is $docker_gid."

  create_args+=(
    --additional-flags
    "--group-add $docker_gid"
  )
else
  log "Docker socket was not found. Creating Devbox without Docker access."
fi

log "Creating Devbox from $DEVBOX_IMAGE."

if ! distrobox create "${create_args[@]}"; then
  fail_to_host_shell "Distrobox could not create Devbox."
fi

log "Devbox created successfully."
log "Entering Devbox."

exec distrobox enter \
  --name "$DEVBOX_NAME" \
  -- /usr/bin/zsh -l