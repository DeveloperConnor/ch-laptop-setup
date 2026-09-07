#!/usr/bin/env bash

set -euo pipefail

DOCKER_SOCKET="/var/run/docker.sock"

if [[ -z "${CONTAINER_ID:-}" ]]; then
  echo "ERROR: Run this script from inside the Distrobox." >&2
  exit 1
fi

if [[ ! -S "$DOCKER_SOCKET" ]]; then
  echo "ERROR: Docker socket not found at $DOCKER_SOCKET." >&2
  exit 1
fi

current_user="$(id -un)"
docker_gid="$(stat -Lc '%g' "$DOCKER_SOCKET")"
docker_group="$(getent group "$docker_gid" | cut -d: -f1 || true)"

echo "Container:     $CONTAINER_ID"
echo "User:          $current_user"
echo "Docker socket: $DOCKER_SOCKET"
echo "Socket GID:    $docker_gid"

if [[ -z "$docker_group" ]]; then
  docker_group="host-docker"

  echo "Creating group '$docker_group' with GID $docker_gid..."
  sudo groupadd --gid "$docker_gid" "$docker_group"
else
  echo "Matching group: $docker_group"
fi

if id -nG "$current_user" | tr ' ' '\n' | grep -qx "$docker_group"; then
  echo "$current_user is already a member of $docker_group."
else
  echo "Adding $current_user to $docker_group..."
  sudo usermod --append --groups "$docker_group" "$current_user"
fi

echo
echo "Docker access configured."
echo
echo "Restart the Distrobox session to activate membership:"
echo
echo "  exit"
echo "  distrobox stop $CONTAINER_ID"
echo "  distrobox enter $CONTAINER_ID"
echo
echo "Then verify with:"
echo
echo "  id"
echo "  docker ps"