# ZORIX 500-player server foundation

## Capacity definition

The first target is **500 concurrent players across ten independent Battle Royale match instances**, with a maximum of 50 players in each match. It is not one 500-player match.

## Included in this change

- `server/start-500-fleet.sh` launches ten dedicated-server containers from an already-built `zorix-server:local` image.
- Each container has its own name and host UDP port (24560–24569 by default), and advertises a 50-player cap.
- The script refuses to overwrite existing containers and cleans up containers it started if a later launch fails.

## Build and launch

From the repository root:

```bash
docker build -f server/Dockerfile -t zorix-server:local .
bash server/start-500-fleet.sh
```

Optional settings:

- `ZORIX_SERVER_IMAGE`: image tag (default `zorix-server:local`)
- `ZORIX_BASE_PORT`: first public UDP port (default `24560`)
- `ZORIX_CONTAINER_PREFIX`: container-name prefix (default `zorix-br`)

Stop the staging instances:

```bash
for i in $(seq -w 1 10); do docker rm -f "zorix-br-$i"; done
```

## Important limits / next engineering gates

This is a **single-Docker-host staging launcher**, not an autoscaler or production deployment. Ten containers on one VPS do not guarantee 500 simultaneous real players. CPU, RAM, packet rate, UDP bandwidth, physics cost, map complexity and tick rate must be measured with the actual exported Godot server and real clients.

The current matchmaking/server-fleet API has registration, heartbeat, allocation and signed join-ticket endpoints, but the Godot dedicated server is not yet wired to register/heartbeat or consume tickets. This launcher also does not automatically register its ten endpoints with that API. Do not advertise these instances as public matchmaking capacity until that integration is completed.

Before production:
1. Deploy across multiple hosts / availability zones, not ten containers on one host.
2. Wire each game server to register and heartbeat with the fleet API; secure each server with its own credential.
3. Make matchmaking allocate ten healthy 50-slot instances and return signed join tickets.
4. Enforce one-time ticket consumption before admitting a client to ENet.
5. Test in steps (50, 100, 250, 500 real game clients) and record server CPU/RAM, packet loss, tick time, p95 latency, disconnects and bandwidth.
6. Set autoscaling, health checks, monitoring, DDoS protection, backups and a rollback procedure.

## Acceptance criteria for claiming 500-player support

- Ten healthy instances are visible to the allocator.
- No match exceeds 50 players.
- 500 real clients complete login, matchmaking, join and a sustained gameplay session.
- No server exceeds its agreed CPU/RAM/tick-time limits; latency, packet loss and disconnect rates meet release thresholds.
- Test report and exact VPS/network configuration are published.

A successful container launch or synthetic HTTP test alone is not evidence of 500-player gameplay capacity.
