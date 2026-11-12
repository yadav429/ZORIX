# ZORIX Godot 4.7 ENet Dedicated Server

This container runs the existing Godot project headlessly and opens an ENet UDP listener. It is intended for a Linux x86_64 host that provides a **public UDP port** and a stable public IPv4/IPv6 address.

## Required host configuration

- Public UDP port: `24560/udp` (or set `ZORIX_SERVER_PORT` and open that exact port in the provider firewall)
- `ZORIX_PUBLIC_HOST`: public address reachable by Android clients (no scheme, path, or port)
- `ZORIX_API_URL`: defaults to the ZORIX Player API
- `ZORIX_SERVER_SECRET`: same server secret configured on the Player API; keep it private
- `ZORIX_SERVER_REGION`: defaults to `india`
- `ZORIX_MAX_PLAYERS`: defaults to 50

Do not deploy this as a normal Render Web Service: Render web services expose HTTP(S), not arbitrary public ENet UDP game traffic. Keep the Player API/matchmaking on Render and run this container on a UDP-capable VPS/game-server host.

## Run

```sh
docker build -t zorix-dedicated-server .
docker run -d --name zorix-game \
  --restart unless-stopped \
  -p 24560:24560/udp \
  -e ZORIX_PUBLIC_HOST=YOUR_PUBLIC_IP \
  -e ZORIX_SERVER_SECRET=YOUR_RENDER_SERVER_SECRET \
  -e ZORIX_SERVER_REGION=india \
  zorix-dedicated-server
```

The Godot lobby detects `--server`, starts `ENetMultiplayerPeer.create_server`, and changes to the match scene. The autoload server agent registers the host with the Player API and sends heartbeats. Confirm a real client join from a separate network before advertising the server as live.

## Important limitations

- A successful container build is not proof that UDP is reachable from the public internet.
- The API currently uses SQLite; verify the Render API's persistent storage/database configuration before production matchmaking.
- This is a first 50-slot staging server configuration, not a verified 50-human-player capacity claim. Load and gameplay tests are still required.
