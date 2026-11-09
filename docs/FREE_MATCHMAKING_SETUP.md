# ZORIX Free-tier Matchmaking Backend (Supabase)

This adds a first matchmaking queue backend for Solo, Duo and Squad. It is a **queue prototype**, not a complete authoritative battle server.

## Free setup
1. Create a Supabase project on the Free plan: https://supabase.com/dashboard
2. In Authentication > Providers, enable **Anonymous Sign-Ins**.
3. Open SQL Editor and run `supabase/migrations/001_zorix_matchmaking.sql`.
4. Copy the Project URL and the **anon/public** key from Project Settings > API.
5. Configure these values in the game client using `ZorixMatchmakingClient.configure(project_url, anon_key)`. Never put a service_role key in the game.
6. Add the client node to the lobby, connect `status_received` and `request_failed`, call `join_queue("Solo"|"Duo"|"Squad")`, poll `refresh_status()` every 3-5 seconds while searching, and call `leave_queue()` when cancelling.

## Queue behavior
- A mode-specific queue waits for 50 players.
- At 50, the SQL RPC atomically creates a match and assigns team numbers (Solo=1, Duo=2, Squad=4 players per team).
- Anonymous Supabase Auth supplies a per-install identity; reinstalling/clearing app data may create a new identity.
- Queue entries older than 10 minutes are expired during join operations.

## Important limitations
- Supabase Free projects can pause after inactivity and have quotas/limits that change; check the current Supabase dashboard before launch.
- This only matches players and returns a match ID/team number. It does **not** host the 3D game simulation, replicate movement/shooting, prevent cheating, or guarantee 50-player frame-rate/network performance.
- A separate always-on authoritative Godot dedicated server (or managed game-server host) and gameplay networking are required before a real online battle can start.
- Anonymous accounts are convenient for prototype testing but are not durable player accounts. Add account linking, rate limits, moderation and abuse controls before public release.
- Clients should poll with a 3-5 second interval, not continuously. Do not expose Supabase service_role credentials.

## Testing
Use two devices with the same Supabase project to verify sign-in, queue join/cancel and status. The 50-player threshold needs 50 test identities or a controlled test harness. Do not consider a match ready merely because the queue RPC works; test dedicated-server handoff separately.
