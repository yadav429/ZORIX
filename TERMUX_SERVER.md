# ZORIX LAN Dedicated Server on Android (Termux)

This is an experimental **same-Wi-Fi/hotspot test path**, not a public production host. It uses the Linux ARM64 Godot 4.7 headless binary inside Ubuntu under Termux's proot environment.

## What this test proves

- The Android tablet can start the ZORIX ENet server process.
- A second Android device on the same Wi-Fi/hotspot can reach the tablet's private LAN IP over UDP 24560.
- The existing server fleet agent can attempt registration and heartbeats with the Render API.

It does **not** prove public internet reachability, stable 24/7 hosting, or 10–20 human-player capacity. Android battery management, thermal throttling, hotspot isolation, carrier NAT and proot compatibility can prevent or interrupt hosting.

## 1. Prepare Termux on the tablet

Install Termux from a trusted source such as F-Droid or the official Termux GitHub releases. Open Termux and run:

```sh
pkg update -y && pkg upgrade -y
pkg install -y proot-distro git curl wget unzip
termux-wake-lock
proot-distro install ubuntu
proot-distro login ubuntu --bind /storage/emulated/0:/mnt/shared
```

Inside Ubuntu:

```sh
apt update
apt install -y ca-certificates curl unzip libfontconfig1 libstdc++6 libgcc-s1
mkdir -p /opt/zorix
cd /opt/zorix
git clone --branch feature/udp-dedicated-server-deploy https://github.com/yadav429/ZORIX.git .
```

If the clone says the directory is not empty, use a fresh directory such as `/opt/zorix-src`.

## 2. Install the Godot Linux ARM64 headless binary

Inside Ubuntu (not the normal Termux shell):

```sh
cd /tmp
curl -fL --retry 3 \
  https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_linux.arm64.zip \
  -o godot-arm64.zip
unzip -o godot-arm64.zip -d godot-arm64
install -m 0755 godot-arm64/Godot_v4.7-stable_linux.arm64 /usr/local/bin/godot
godot --version
```

If the release asset is unavailable or the binary reports an architecture/library error, stop and send the exact error; do not install an unrelated x86_64 binary.

## 3. Configure the API

The Render Player API must have the **same** `ZORIX_SERVER_SECRET` value as the dedicated server (at least 32 characters). Set or verify it in the Render service environment settings. Never put the secret in the Android client APK or a public Git commit.

The API also needs a persistent database for anything beyond a disposable test; the current SQLite path may be ephemeral on a free Render service.

## 4. Find the tablet's private LAN IP

Keep the tablet and second phone on the same Wi-Fi or hotspot. In the normal Termux shell run:

```sh
pkg install -y iproute2
ip route get 1.1.1.1
```

Look for the `src` address (often `192.168.x.x` or `172.20.x.x`). Use that private address as `ZORIX_PUBLIC_HOST` for this LAN-only test. Do not use the tablet's public IP.

## 5. Start the server

Inside Ubuntu, in the cloned project directory:

```sh
export ZORIX_API_URL="https://zorix-player-api-dnz5.onrender.com"
export ZORIX_SERVER_SECRET="PASTE_THE_SAME_SECRET_CONFIGURED_IN_RENDER"
export ZORIX_SERVER_NAME="zorix-android-lan-test"
export ZORIX_SERVER_REGION="india"
export ZORIX_PUBLIC_HOST="TABLET_PRIVATE_LAN_IP"
godot --headless --audio-driver Dummy --path /opt/zorix -- \
  --server --port=24560 --max-players=20 --public-host="$ZORIX_PUBLIC_HOST"
```

Keep this process open. Expected log includes `ZORIX DEDICATED SERVER READY` and, if API credentials/schema are correct, `ZORIX SERVER FLEET REGISTERED`.

## 6. Connect the second phone

Both devices must remain on the same Wi-Fi/hotspot. UDP 24560 must not be blocked by the hotspot/router. Use the ZORIX Android client and its normal Guest/Google login and matchmaking flow. Queue two Solo players for the first test. The API allocator's minimum match size must be configured for two players and the server must be registered/healthy.

If the current lobby does not expose a manual LAN address field, do not expect typing the IP into an arbitrary UI field to work; use the existing API matchmaking path. If the API cannot return the private address to the client, a dedicated LAN-connect UI/code change is required before this test can complete.

## 7. Stop

Press Ctrl+C in the Ubuntu server terminal, then in Termux run:

```sh
termux-wake-unlock
```

## Troubleshooting checklist

- `Exec format error`: wrong CPU architecture binary; confirm Android tablet is ARM64 and the downloaded asset is `linux.arm64`.
- Missing shared library: copy the exact loader error; install the matching Ubuntu package.
- API HTTP 403: Render and tablet server secrets do not match.
- API HTTP 422: registration payload/port/host is invalid; inspect API logs.
- No registration: check Render API health, secret, and outbound internet.
- Registered but phone cannot connect: check same subnet, hotspot client isolation, UDP 24560 and the exact private IP.
- Server stops when screen sleeps: keep Termux wake lock active and disable battery optimization for Termux.

**Safety:** Never share the server secret, SSH private key, account password or payment details in chat. A LAN test is not an internet-facing production deployment.
