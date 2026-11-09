# ZORIX 10K Concurrent Player Readiness

## Target definition

The first 10K target means **10,000 authenticated players online at the same time across multiple matches**, not 10,000 players in one Battle Royale instance.

With the current 50-player match cap, the theoretical minimum is 200 simultaneous full match instances, plus headroom for partial matches, reconnects, rolling deploys and failures. A single 50-player game server cannot host 10,000 players.

## Current verified baseline (2026-11-09)

The GitHub Actions synthetic profile spawned 10,000 Locust virtual users against a local FastAPI process. It generated 67,272 HTTP requests and recorded 46 connection failures (0.0684%). Aggregate throughput was about 709 requests/second; median latency was 110 ms and maximum latency was about 19.7 seconds.

The runner reported CPU usage above 90%. Errors were RemoteDisconnected responses on /api/me (23), /api/lobby (19) and /api/health (4).

This is a **failed synthetic API test**, not a successful 10K production test. It did not connect Godot/Android clients to ENet game servers or simulate real gameplay. The shared runner was CPU-constrained, so this run does not isolate API maximum capacity.

## Required production architecture

### API tier
- Multiple stateless API replicas behind an HTTPS load balancer.
- PostgreSQL for durable accounts, profiles, inventory, match history and rankings.
- Redis for ephemeral queues, presence, rate limits, short-lived session state and server leases.
- Connection pooling, bounded workers, indexes, timeouts, rate limits, graceful shutdown and secret rotation.
- Never put JWT or dedicated-server secrets in the Android client.

### Matchmaking and allocator
- Queue worker groups compatible Solo/Duo/Squad parties.
- Registry tracks healthy game servers, region, build, capacity and heartbeat.
- Atomically reserve slots to prevent overbooking.
- Issue short-lived signed join tickets bound to player, match, server, expiry and nonce.
- Dedicated server validates tickets before admitting ENet peers.
- Handle cancellation, party integrity, server startup failure, reconnects and match completion.

### Game-server fleet
- Keep each Battle Royale instance capped at 50 until real gameplay tests prove otherwise.
- Plan at least 200 full match instances for 10,000 concurrent players, plus spare capacity.
- Measure CPU, RAM, bandwidth, packet loss, tick rate and latency under actual gameplay.
- Use UDP-capable infrastructure, regional placement, DDoS protection and autoscaling.

## Required test ladder

1. API unit/integration tests for auth, profiles, queue, parties, reservation, tickets and result authorization.
2. API load at 100, 500, 1,000, 2,500, 5,000 and 10,000 concurrent sessions against staging, with separate load generators.
3. Godot gameplay tests at 2, 5, 10, 25 and 50 clients per game server.
4. Gradually scale match instances and validate allocator/fleet behavior.
5. Run a 30–60 minute soak test including deploy/restart/failure recovery.
6. Release only after agreed p95/p99 latency, tick-rate, packet-loss and error-rate gates pass with no data loss or authorization leaks.

Reports must distinguish virtual HTTP users from actual game clients.

## Current blockers

- PR #14's queue is database-backed; it does not itself allocate public game servers.
- The current API uses SQLite and one Uvicorn worker; it is not a horizontally scaled 10K production tier.
- Godot ENet ticket validation, fleet orchestration, telemetry and production deployment remain incomplete.
- The 10K synthetic CI run failed with 46 RemoteDisconnected errors while the shared runner reported CPU above 90%.
- No 10K real-client ENet/gameplay test has passed.

## Safe milestones

Implement PostgreSQL/Redis queue and allocator; connect dedicated-server registration, heartbeat and ticket validation; deploy staging API and one game server; pass 2/5/10/25/50-client gameplay tests; then scale the fleet and run 1K, 2.5K, 5K and 10K staged tests. Production launch remains blocked until the final 10K soak test passes.
