# ZORIX player accounts and public lobby

This change adds a small account API and Godot register/login panel. It is a first deployment slice, not a public production service until it is hosted and protected by HTTPS.

## Included
- Username/password registration and login.
- Passwords stored as PBKDF2-HMAC-SHA256 hashes with per-user random salts.
- Signed, expiring bearer tokens; tokens are stored in the game's local user settings, not the password.
- Authenticated `/api/me` and `/api/lobby` endpoints.
- Persistent SQLite volume for player accounts.
- Lobby server discovery from the configured public game host.
- Online create/join buttons require a locally stored login token.

## VPS configuration

1. Copy `server/.env.example` to `server/.env`.
2. Set `ZORIX_JWT_SECRET` to a new random secret (at least 32 characters). Generate one with `openssl rand -hex 32`. Never commit the real secret.
3. Set `ZORIX_GAME_HOST` to the VPS public IPv4 address or DNS name.
4. Build/download the Linux dedicated server artifact from GitHub Actions and place the binary at `build/zorix-server.x86_64` (or select the ARM64 binary using `SERVER_BINARY`).
5. Start from the repository root: `docker compose --env-file server/.env -f server/compose.yml up -d --build`.
6. Expose UDP 24560 for the game server. Put the account API behind a TLS reverse proxy (HTTPS) and expose HTTPS publicly. Do not send real passwords over plain public HTTP.
7. In ZORIX, enter the HTTPS API base URL, register/login, then use the discovered server address in Join Room.

The account API listens on container port 8080. The Compose mapping defaults to host port 8080; keep it private behind the TLS proxy/firewall. The game server uses UDP 24560.

## API
- `GET /api/health` public health check.
- `POST /api/register` JSON: `{"username":"player_01","password":"minimum8chars"}`.
- `POST /api/login` same JSON shape.
- `GET /api/me` bearer-token protected.
- `GET /api/lobby` bearer-token protected; returns configured server host/port/mode/capacity.

## Important limitations
- This is username/password auth only; email/phone verification, password reset, moderation, bans, account recovery and rate limiting are not included.
- The API lobby endpoint is a directory/config response, not a matchmaking queue. It currently advertises one configured game server.
- Game ENet connections do not yet validate the account bearer token. The UI gate is not an anti-cheat/security boundary; a modified client could bypass it. Server-side token verification and account-to-peer binding must be added before public competitive play.
- Configure HTTPS before real players register. SQLite volume backups are the operator's responsibility.
- A 50-player setting is not a 50-client load-test result. Public hosting and real device testing are still required.
