#!/data/data/com.termux/files/usr/bin/bash
# Run this helper from Termux after entering the Ubuntu proot.
set -euo pipefail
PROJECT_DIR="${ZORIX_PROJECT_DIR:-/opt/zorix}"
GODOT_BIN="${GODOT_BIN:-/usr/local/bin/godot}"
if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot headless binary not found at $GODOT_BIN. Follow TERMUX_SERVER.md first."
  exit 1
fi
if [[ ! -f "$PROJECT_DIR/project.godot" ]]; then
  echo "ZORIX project not found at $PROJECT_DIR"
  exit 1
fi
read -r -p "Tablet private LAN IP (e.g. 192.168.1.20): " LAN_IP
if [[ -z "$LAN_IP" ]]; then echo "LAN IP is required"; exit 1; fi
read -r -s -p "Render ZORIX_SERVER_SECRET (input hidden): " ZORIX_SERVER_SECRET
echo
if [[ ${#ZORIX_SERVER_SECRET} -lt 32 ]]; then
  echo "Secret must contain at least 32 characters."
  exit 1
fi
export ZORIX_API_URL="${ZORIX_API_URL:-https://zorix-player-api-dnz5.onrender.com}"
export ZORIX_SERVER_SECRET
export ZORIX_PUBLIC_HOST="$LAN_IP"
export ZORIX_SERVER_NAME="${ZORIX_SERVER_NAME:-zorix-android-lan-test}"
export ZORIX_SERVER_REGION="${ZORIX_SERVER_REGION:-india}"
cd "$PROJECT_DIR"
exec "$GODOT_BIN" --headless --audio-driver Dummy --path "$PROJECT_DIR" -- \
  --server --port="${ZORIX_SERVER_PORT:-24560}" \
  --max-players="${ZORIX_MAX_PLAYERS:-20}" --public-host="$LAN_IP"
