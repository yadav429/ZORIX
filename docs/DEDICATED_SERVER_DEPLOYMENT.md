# ZORIX Dedicated Server (50-player Battle Royale)

## What this adds
- Headless Linux server startup using `--server`.
- Battle Royale default capacity: 50 remote players.
- Tactical 5v5 server capacity is capped at 10 players.
- Server owns player movement simulation and transform replication (20 Hz).
- Server validates movement RPC sender and rate-limits input updates.
- Existing server-side shot validation, health, loot and match rules from PR #6 run in the same dedicated process.
- Linux server export artifact is built by `.github/workflows/server.yml`.

## Important: this is not yet a proven production deployment
The code and container packaging are a dedicated-server deployment foundation. No cloud VM has been provisioned, no public endpoint has been assigned, and no 50-client soak/load test has been completed. Do not advertise a live 50-player production service until these tests pass.

## Build
1. Open GitHub Actions and run **ZORIX Dedicated Server**.
2. Download artifact **ZORIX-Linux-Dedicated-Server**.
3. Put the executable at `build/zorix-server.x86_64` in a checkout of this same branch.
4. Build and start the container:

```sh
docker compose -f server/compose.yml build
PORT=24560 MAX_PLAYERS=50 GAME_MODE=battle_royale docker compose -f server/compose.yml up -d
docker compose -f server/compose.yml logs -f
```

## VPS network requirements
- Linux x86_64 VPS with Docker.
- Public IPv4 or a supported UDP relay.
- Open inbound **UDP 24560** in both cloud firewall and host firewall.
- Keep the process running; use a region close to most players.
- Client enters the VPS public IP in ZORIX lobby. Port defaults to 24560.

## Capacity and testing gates
- Battle Royale: 50 remote clients configured.
- Tactical 5v5: 10 clients maximum.
- Start with 2 clients, then 5, 10, 25 and only then 50.
- Measure CPU, RAM, outbound bandwidth, packet loss, ping and server tick stability.
- A single Linux server process is not automatically sized for 50 simultaneous players; choose VPS resources after load tests.

## Known remaining production work
- Add a matchmaking allocator that reserves a server instance and returns its public endpoint to clients.
- Add authenticated player sessions and server-side team assignment (Tactical team assignment is still prototype peer-ID based).
- Add reconnect handling, match lifecycle/cleanup, server metrics, logs/alerts and graceful shutdown.
- Complete hit validation/anti-cheat, loot/inventory edge cases and full replication tests.
- Verify server build and run real two-device and 50-client tests before production launch.

## Security
Never put Supabase service-role keys or other server secrets in the Android APK. The dedicated game server does not need a Supabase service-role key for its ENet transport.
