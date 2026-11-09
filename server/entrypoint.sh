#!/bin/sh
set -eu

PORT="${PORT:-24560}"
MAX_PLAYERS="${MAX_PLAYERS:-50}"
GAME_MODE="${GAME_MODE:-battle_royale}"

case "$GAME_MODE" in
  battle_royale|tactical_5v5) ;;
  *) echo "Unsupported GAME_MODE: $GAME_MODE" >&2; exit 2 ;;
esac

case "$PORT" in
  *[!0-9]*|'') echo "PORT must be numeric" >&2; exit 2 ;;
esac

case "$MAX_PLAYERS" in
  *[!0-9]*|'') echo "MAX_PLAYERS must be numeric" >&2; exit 2 ;;
esac

echo "Starting ZORIX dedicated server: UDP $PORT, max $MAX_PLAYERS, mode $GAME_MODE"
exec /app/zorix-server --headless -- --server --port="$PORT" --max-players="$MAX_PLAYERS" --mode="$GAME_MODE"
