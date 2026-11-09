# ZORIX 10K synthetic load profile

## What this test does

- Starts a fresh local FastAPI auth/lobby service in CI.
- Creates **10,000 Locust virtual users** with synthetic, short-lived HMAC tokens.
- Exercises `GET /api/me`, `GET /api/lobby`, and `GET /api/health`.
- Ramps up at 200 virtual users/second, then holds the profile for 90 seconds.
- Uploads HTML and CSV reports as a GitHub Actions artifact.

## What this test does NOT prove

- It does not create 10,000 real player accounts or test password registration/login hashing.
- It does not connect 10,000 clients to the Godot ENet game server.
- It does not test real Android devices, real networks, matchmaking quality, gameplay replication, or production capacity.
- A successful CI run means this local API handled the synthetic HTTP profile on that GitHub-hosted runner only. It is not a claim that production can support 10,000 players.

## Safety

The Locust profile refuses non-loopback targets. It uses only a CI-only signing secret and synthetic identities. Do not remove the local-target guard or point this profile at a public/production service. A separate, authorized staging test is required for real network capacity testing.
