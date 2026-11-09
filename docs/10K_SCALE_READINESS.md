# ZORIX 10K Concurrent Player Readiness

## Target definition

The first 10K target means **10,000 authenticated players online at the same time across multiple matches**, not 10,000 players in one Battle Royale instance.

With the current 50-player match cap, the theoretical minimum is:

- 200 simultaneous full 50-player match instances for 10,000 connected players.
- Additional headroom is required for partially filled matches, reconnects, spectators (if added), rolling deploys and failed instances.
- Solo, Duo and Squad are matchmaking/team modes; they do not change the 50-player server cap.

A single 50-player game server cannot host 10,000 players. Do not increase MAX_PLAYERS to 10,000 as a shortcut.

## Current verified baseline (2026-11-09)

The GitHub Actions synthetic profile spawned 10,000 Locust virtual users against a local FastAPI process. It generated 67,272 HTTP requests and recorded 46 connection failures (0.0684%). Aggregate throughput was about 709 requests/second; median latency was 110 ms and maximum latency was about 19.7 seconds.

The runner log explicitly reported CPU usage above 90%. The 46 errors were RemoteDisconnected responses on /api/me (23), /api/lobby (19) and /api/health (4).

This is a **failed synthetic API test**, not a successful 10K production test. It did not connect any Godot/Android clients to the ENet game server, did not create real player accounts, and did not simulate 10,000 players moving/shooting in matches. The GitHub-hosted load generator itself was CPU-constrained, so this run does not isolate the API server's maximum capacity.

## Required production architecture

### 1. Stateless player/API tier

- Run multiple API replicas behind an HTTPS load balancer.
- Use PostgreSQL (managed or properly operated HA deployment) for durable accounts, profiles, inventory, match history and ranking. Do not use one SQLite file as the shared multi-replica production database.
- Use Redis for ephemeral matchmaking queues, presence, rate limits, short-lived session state and server leases. Keep durable match results in PostgreSQL.
- Add database connection pooling, bounded worker counts, query indexes, timeouts, request limits and graceful shutdown.
- Keep JWT signing secrets and dedicated-server shared secrets in the deployment secret manager; rotate them and never put them in the Android client.
- Add API rate limits, registration/login abuse protection and audit logs.

### 2. Matchmaking and match allocator

- Replace the current persisted queue-only behavior with a queue worker that groups compatible Solo/Duo/Squad parties.
- Maintain a registry of healthy game-server instances with mode, region, build version, current player count, capacity and heartbeat time.
- Allocate a match only when a server has reserved capacity; atomically reserve slots to prevent overbooking.
- Return a short-lived, signed join ticket bound to player ID, match ID, server ID, expiry and nonce.
- The dedicated server must validate the ticket before accepting an ENet peer. Clients must never choose arbitrary server IDs or claim their own match results.
- Handle queue cancellation, party integrity, server startup failure, full-server races, reconnects, disconnect timeouts, match completion and abandoned matches.

### 3. Game-server fleet

- Keep each Battle Royale server capped at 50 until measured gameplay tests prove a different cap is safe.
- For 10,000 connected players, plan for at least 200 full match instances plus spare capacity. These may run on multiple machines/VMs; do not put all instances on one small VPS.
- Measure per-instance CPU, RAM, network ingress/egress, packet loss, tick rate, simulation time, replication bandwidth and player latency under actual gameplay.
- Use regional placement and UDP-capable infrastructure with DDoS protection. HTTP-only/free web hosts are not game-server hosts.
- Add autoscaling based on queue depth and healthy free slots, with warm capacity to avoid long waits. Drain servers safely before deployment.

## Required test ladder

Do not jump from a local synthetic API test to a public 10K launch.

1. API unit/integration tests: auth, profile, queue, party, reservation, ticket validation and match-result authorization.
2. API load: 100, 500, 1,000, 2,500, 5,000 and 10,000 concurrent authenticated sessions against a dedicated staging deployment. Use separate load-generator machines so the generator does not share CPU with the API.
3. Match-server tests: 2, 5, 10, 25 and 50 real/simulated Godot clients per server, including movement, firing, damage, loot, safe zone and reconnects.
4. Fleet tests: increase the number of match instances and clients gradually; validate allocator behavior and regional network limits.
5. Soak test: hold target load for at least 30-60 minutes and test deploy/restart/failure recovery.
6. Release gate: zero unexplained disconnects; agreed p95/p99 latency, tick-rate, packet-loss and error-rate thresholds; no data loss or cross-match authorization leaks.

Every report must identify the commit, deployment size, load-generator size, number of virtual users, number of actual game clients, match instances, duration, request rate, p50/p95/p99, failures, CPU, RAM and network. Never label synthetic HTTP sessions as real players.

## Current blockers before a 10K claim

- PR #14's matchmaking queue is a database-backed queue only; it does not yet allocate public game servers.
- The current API uses SQLite and the container starts one Uvicorn worker; this is not a horizontally scaled 10K production tier.
- Dedicated-server join-ticket validation, allocator, fleet orchestration, telemetry and production deployment are not complete.
- The current CI 10K synthetic run failed with 46 RemoteDisconnected errors while the shared GitHub runner reported CPU above 90%.
- No 10K real-client ENet/gameplay test has passed.

## Safe next milestones

A realistic order is: finish and merge PR #14 after all checks pass; implement PostgreSQL/Redis-backed queue and allocator; add signed join tickets and server registration/heartbeat; deploy a staging API and one game server; pass 2/5/10/25/50-client gameplay tests; then scale the fleet and run 1K, 2.5K, 5K and 10K staged tests. Production launch remains blocked until the final 10K soak test passes.
