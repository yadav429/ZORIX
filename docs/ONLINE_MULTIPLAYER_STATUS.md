# ZORIX online multiplayer prototype

## What this branch adds
- Host and join now enter the selected game scene automatically.
- The host creates network player nodes with MultiplayerSpawner.
- Player position and body rotation are replicated with MultiplayerSynchronizer.
- Each device's mobile controls are bound to its locally-authoritative player.
- Both Battle Royale and Tactical 5v5 use the same player-spawn path.

## Current test path
1. Install the same build on two Android devices.
2. Connect both devices to the same Wi-Fi network.
3. On device A, choose a mode and tap CREATE ROOM (HOST).
4. Find device A's local IPv4 address in Android Wi-Fi details.
5. On device B, enter that address and tap JOIN ROOM BY IP.
6. Move both characters and confirm each device sees the other player moving.

The host listens on UDP port 24560. The host's firewall/router must allow this port.

## Important limitations
This is an early peer-hosted networking foundation, not a finished online battle game:
- Direct IP hosting may fail across mobile carriers because of carrier-grade NAT, router NAT or blocked UDP. Public internet play needs a reachable dedicated server or a relay/NAT-traversal service.
- Only player transforms are synchronized in this prototype. Weapon fire, hit validation, health, deaths, loot, safe zone, score/round state and bot replication still need authoritative server implementation.
- The host currently owns the AI simulation; bot state is not yet replicated to joining clients.
- A 50-player load test has not been run. Do not advertise 50-player live gameplay as verified.
- Supabase matchmaking is a separate PR and is not connected to this direct-IP prototype. Supabase database functions cannot relay real-time 3D movement or host a Godot game server.
- Never place Supabase service_role keys or server secrets in the Android APK.

## Production direction
For public matches, deploy a headless authoritative Godot server on an always-on UDP-capable host. Use Supabase only for accounts, queue formation and match metadata, then return a server address and short-lived join token to each client.
