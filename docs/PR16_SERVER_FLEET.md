# PR #16 — Dedicated server fleet and join-ticket API

This PR adds the first executable server-allocation slice on top of PR #14's SQLite matchmaking queue.

## Configuration

Set these environment variables on the API service:

- `ZORIX_SERVER_SECRET`: required shared server/API secret, at least 32 characters.
- `ZORIX_JOIN_TICKET_SECRET`: optional separate HMAC secret, at least 32 characters. If omitted, the server secret is used.
- `ZORIX_SERVER_HEARTBEAT_TTL`: server considered stale after this many seconds (default 45).
- `ZORIX_MATCH_SIZE`: reserved for future allocator tuning; server capacity remains capped at 50.

Do not commit real secrets to Git.

## Dedicated-server lifecycle

1. Register a server with `POST /api/internal/servers/register` and header `X-Zorix-Server-Secret`.
2. Save the returned `server_id` in that server process.
3. Send `POST /api/internal/servers/{server_id}/heartbeat` periodically with both `X-Zorix-Server-Secret` and `X-Zorix-Server-Id`. Report active and reserved player counts.
4. A trusted matchmaking worker calls `POST /api/internal/matches/allocate` with the same server secret and a mode. The allocator reserves a healthy server and atomically moves a full set of queued players into a match.
5. An authenticated player polls `GET /api/matchmaking/status`. When allocated, the API returns the server address and a short-lived signed join ticket.
6. The dedicated server calls `POST /api/internal/join-ticket/consume` with the ticket, server secret and its own server ID. Tickets expire after 120 seconds and can be consumed only once, only by the server assigned to that match.

## Match sizing

- The server registration API caps each instance at 50 player slots.
- Solo and Duo allocation require the requested capacity (50 by default).
- Squad allocation preserves complete four-player teams; a 50-slot server can therefore start with 48 players (12 complete squads), never splitting a squad.
- The allocator returns `waiting` if no healthy server or enough queued players are available.

## Important limits

- This is an initial SQLite-backed allocator, not a horizontally scaled 10K-player production system.
- A trusted worker/scheduler must call the allocation endpoint; queue insertion does not automatically start a match yet.
- Dedicated-server game code must call ticket-consume before admitting a client. The API endpoint alone does not wire Godot ENet authentication.
- SQLite remains a single-node bottleneck. PostgreSQL/Redis migration, regional fleet orchestration, autoscaling, rate limits, TLS/network hardening, telemetry, and real ENet gameplay load tests remain future work.
- A passing API test proves the API workflow only; it does not prove 50 real players per game server or 10,000 concurrent gameplay clients.
