# ZORIX bundled Battle Royale, social and progression update (PR #14)

This PR groups the requested player-platform systems into one backend release slice.

## Included API foundations
- Solo/Duo/Squad matchmaking queue; queue entries persist and the game server is configured for up to 50 players.
- Duo/Squad team creation, invite codes, joining, member listing and leaving.
- Player profiles with generated public ZORIX ID, display name, bio and rating/stat summary.
- Friend requests, accept, list and remove.
- Ranked leaderboard endpoint.
- Starter weapon skin inventory, catalog and equip endpoint.
- Match result writes are restricted to the dedicated server using ZORIX_SERVER_SECRET; clients cannot directly award rank.
- SQLite schema initializes lazily without replacing existing account tables.

## Endpoints
- GET/PATCH /api/profile
- GET /api/friends, POST /api/friends/request, POST /api/friends/{requester_id}/accept, DELETE /api/friends/{other_player_id}
- POST /api/teams, POST /api/teams/join, GET/DELETE /api/teams/me
- POST/DELETE /api/matchmaking/queue
- GET /api/leaderboard
- GET /api/inventory, POST /api/inventory/equip
- POST /api/internal/match-result (dedicated-server secret required)

Player endpoints except leaderboard require the existing bearer token. Set ZORIX_SERVER_SECRET on the API host before enabling authoritative result submission.

## Important scope / honest status
This is a bundled backend foundation, not a claim that every feature is already visible or live in the Android client. Godot UI screens and API calls for friends, teams, profiles, rank, inventory and queue status remain to be wired. The queue persists requests but does not yet allocate a ready match to a public game server; a server allocator/worker and authenticated ENet join-token validation are still required. Cosmetic skins are inventory metadata until matching 3D assets and weapon attachment rendering are added. A configured 50-player capacity is not proof of 50 concurrent live players; real 50-client load testing and public VPS deployment remain mandatory.
