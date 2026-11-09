#!/usr/bin/env bash
set -Eeuo pipefail

# Starts ten independent 50-player ZORIX dedicated-server containers.
# This is a staging deployment helper, not proof of 500-player capacity.
IMAGE="${ZORIX_SERVER_IMAGE:-zorix-server:local}"
BASE_PORT="${ZORIX_BASE_PORT:-24560}"
PREFIX="${ZORIX_CONTAINER_PREFIX:-zorix-br}"
INSTANCES=10
CONTAINER_PORT=24560
MAX_PLAYERS=50
MODE="${ZORIX_GAME_MODE:-battle_royale}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required." >&2
  exit 1
fi
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Image '$IMAGE' not found. Build it first using server/Dockerfile." >&2
  exit 1
fi
if ! [[ "$BASE_PORT" =~ ^[0-9]+$ ]] || (( BASE_PORT < 1 || BASE_PORT + INSTANCES - 1 > 65535 )); then
  echo "ZORIX_BASE_PORT must leave room for ten UDP ports." >&2
  exit 2
fi
if [[ "$MODE" != "battle_royale" ]]; then
  echo "The 500-player staging fleet currently supports battle_royale only." >&2
  exit 2
fi

started=()
cleanup_on_error() {
  local status=$?
  if (( status != 0 )); then
    for name in "${started[@]}"; do docker rm -f "$name" >/dev/null 2>&1 || true; done
  fi
  exit "$status"
}
trap cleanup_on_error EXIT

for ((i=0; i<INSTANCES; i++)); do
  name="${PREFIX}-$(printf '%02d' "$((i+1))")"
  host_port=$((BASE_PORT+i))
  if docker container inspect "$name" >/dev/null 2>&1; then
    echo "Container '$name' already exists; refusing to replace it." >&2
    exit 1
  fi
  docker run --detach --init --restart unless-stopped \
    --name "$name" \
    --label zorix.fleet=staging-500 \
    --label zorix.match-capacity="$MAX_PLAYERS" \
    --publish "$host_port:$CONTAINER_PORT/udp" \
    --env PORT="$CONTAINER_PORT" \
    --env MAX_PLAYERS="$MAX_PLAYERS" \
    --env GAME_MODE="$MODE" \
    "$IMAGE" >/dev/null
  started+=("$name")
  printf 'Started %-16s UDP %s -> container %s (%s players)\n' "$name" "$host_port" "$CONTAINER_PORT" "$MAX_PLAYERS"
done

echo "Created ten 50-slot instances (nominal aggregate slots: 500)."
echo "This does NOT establish 500-player gameplay capacity; run staged real-client tests."
trap - EXIT
