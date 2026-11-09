# ZORIX Gameplay Systems - PR #6

This branch layers gameplay rules on top of PR #5's player-spawn/transform prototype.

## Implemented prototype systems
- Server-authoritative hitscan shooting requests, server-side raycast and 25 damage.
- Player health, death state, ammo and reserve-ammo replication.
- Server-spawned ammo and medkit pickups using MultiplayerSpawner.
- Battle Royale safe-zone boundary that shrinks over time and applies damage outside it.
- Tactical 5v5 bomb plant at Site A/B, 40-second bomb timer and defender defuse interaction (five valid interactions).
- 50-player room capacity remains configured as one host plus up to 49 peers.

## Important limitations
- This is a gameplay prototype, not a production-grade authoritative dedicated server.
- Team assignment currently uses peer ID parity for the Tactical prototype; a proper lobby/team allocator is still needed.
- Defuse interaction is tap-count based, not a timed hold/progress bar yet.
- Loot positions are fixed prototype points; inventory, weapon switching, attachments and persistence are not included.
- Safe zone is circular and centered on the map; no staged random zones or minimap overlay yet.
- MultiplayerSynchronizer and ENet setup are code-level foundations only. No 50-client load test has been run.
- Direct-IP ENet still requires a reachable host/UDP 24560; mobile carrier CGNAT may block inbound connections. A relay or hosted dedicated server is a separate deployment requirement.
- PR #6 is stacked on PR #5, which itself depends on PR #4. Merge order: PR #4, then #5, then #6.

## Test plan
1. Build Android APK with GitHub Actions.
2. Run offline Battle Royale: fire at bots, collect ammo/medkit, verify health and safe-zone damage.
3. Run offline Tactical 5v5: move to Site A/B, plant, then use a defender peer to defuse.
4. Test two devices on the same Wi-Fi.
5. Increase clients gradually (2, 5, 10...) before considering a 50-player test.
