# ZORIX Legacy Supabase Matchmaking Prototype — Not Used by Current Game

> **Deprecated / do not deploy for production.** The active ZORIX lobby uses the authenticated player API and dedicated-server fleet allocator (`/api/matchmaking/queue`, `/api/matchmaking/status`, and one-time join tickets). This Supabase queue is an older standalone prototype and is not connected to the current lobby or dedicated-server handoff.

Do not run the SQL migration for a production ZORIX deployment, and do not attach `ZorixMatchmakingClient` to the active lobby. Doing so would create a second independent queue that cannot allocate the current Godot game servers or validate server join tickets.

## Historical prototype scope

This folder preserves the original Supabase Free-tier experiment for reference only:
- Anonymous Supabase Auth sign-in.
- Solo, Duo and Squad queue RPCs.
- A 50-player threshold and team-number assignment.

## Why it is not production-ready

- It returns a Supabase match ID only; it does not register a server, reserve server capacity, issue signed join tickets, or connect clients to a running Godot match.
- It has no lifecycle/requeue cleanup for completed matches and should not be used as a live queue.
- Anonymous identities are prototype-grade and do not replace ZORIX Google/Guest account authentication.
- Supabase Free projects may pause and have plan quotas.

## Current ZORIX integration

Use the player account API and dedicated-server flow already present in `auth/app.py` and `auth/server_fleet.py`:
1. Sign in through the ZORIX Google or Guest account API.
2. Join/cancel through `/api/matchmaking/queue`.
3. Poll `/api/matchmaking/status`.
4. When allocated, connect to the returned host/port and submit the one-time join ticket for server validation.

Never put a Supabase `service_role` key in the Android APK. This legacy prototype remains in the repository only to document the earlier experiment.
