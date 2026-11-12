# ZORIX Dedicated Server deployment

## Free test-hosting option: Oracle Cloud Always Free ARM64

The current low-cost/free test path is an Oracle Cloud Infrastructure (OCI) Ampere A1 VM in the account's home region. Oracle's current Always Free allowance is up to 1,500 OCPU-hours and 9,000 GB-hours per month, equivalent to 2 OCPUs and 12 GB RAM running for a full month. The tenancy also includes 200 GB combined boot/block storage and 10 TB monthly outbound transfer. Always Free compute is capacity-dependent; an "out of host capacity" message means the selected home region currently has no available host capacity.

Official references:
- https://www.oracle.com/cloud/free/
- https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm

Important account notes:
- Always Free compute can only be provisioned in the tenancy's home region. Choose the closest available India region at signup if offered; the home region cannot simply be changed later.
- Oracle generally requires a valid phone number and payment card for verification. A card is not a promise of a free account; do not upgrade to Pay As You Go or create paid resources unless you intentionally accept charges.
- Set a budget/usage alert and check every resource's console label says Always Free before creating it.
- OCI may show temporary capacity errors. Do not repeatedly create extra accounts; wait or use another permitted availability domain in the same home region.

## What this free VM is suitable for

- Initial development and 2-10 client network tests.
- Short controlled tests at 10-25 clients if CPU, RAM, bandwidth and server tick remain healthy.
- It is NOT a promise of 50-player production capacity. The free VM is only 2 OCPUs / 12 GB RAM, and 50-player performance must be load-tested. Start with 2, then 5, 10, 25, and only then 50 simulated/real clients.

## ARM64 server artifact

OCI Ampere A1 uses 64-bit ARM processors. Download the GitHub Actions artifact named ZORIX-Linux-ARM64-Server from the ZORIX Dedicated Server workflow. Do not use the x86_64 artifact on the A1 VM.

The repository now has two export presets:
- Linux Server -> build/zorix-server.x86_64
- Linux ARM64 Server -> build/zorix-server.arm64

## OCI VM setup

1. Create one OCI Ampere A1 VM using Ubuntu 24.04 ARM64 in your home region.
2. Keep the shape within the Always Free allowance: no more than 2 OCPUs and 12 GB RAM total.
3. Use the default 50 GB boot volume initially; this counts toward the tenancy's 200 GB total Always Free block-volume allowance.
4. Create or select a VCN subnet with a public IPv4 address. Configure an internet gateway and route table.
5. In the subnet's Security List or a Network Security Group, add an ingress UDP rule for destination port 24560 from the intended test-client IP range. For broad public testing, 0.0.0.0/0 exposes the game port to the internet; only do this knowingly.
6. On the VM, configure Ubuntu's firewall to allow UDP 24560. Example: sudo ufw allow 24560/udp
7. SSH to the VM and install Docker Engine and the Docker Compose plugin using Docker's official Ubuntu instructions.

## Deploy the ARM64 server

1. Download and extract the ZORIX-Linux-ARM64-Server artifact from GitHub Actions.
2. Clone the ZORIX repository and check out the branch/commit whose server code matches that artifact.
3. Copy the exported binary to build/zorix-server.arm64 in the repository checkout and make it executable: chmod +x build/zorix-server.arm64
4. Build the ARM64 image and start the server:

~~~sh
SERVER_BINARY=build/zorix-server.arm64 docker compose --env-file server/.env -f server/compose.yml build zorix-server
PORT=24560 MAX_PLAYERS=50 GAME_MODE=battle_royale SERVER_BINARY=build/zorix-server.arm64 docker compose --env-file server/.env -f server/compose.yml up -d zorix-server
docker compose --env-file server/.env -f server/compose.yml logs -f
~~~

5. In ZORIX, connect to the VM's public IPv4 address on UDP port 24560. Confirm the client build contains the matching multiplayer protocol.

For Tactical 5v5 use GAME_MODE=tactical_5v5 and MAX_PLAYERS=10.

## Other hosting platforms

- Render Free Web Services are for HTTP/web apps, spin down after 15 minutes idle, and do not provide the always-on raw UDP dedicated-server runtime required by this ENet server. They are not a suitable ZORIX game-server host.
- Fly.io is not a permanently free VPS replacement; current allowances are limited and usage can be billed. Check current pricing before creating Machines.
- Free web hosting can still host a website or matchmaking dashboard, but it is not the same thing as a persistent UDP game simulation server.

## Automatic matchmaking and server registration (current branch)

The API and Godot server now use this flow:

1. A signed-in player taps **Find Match** and selects Solo, Duo or Squad.
2. The API persists the queue entry. Duo/Squad players can be auto-filled with other solo-queued players; a premade team can also queue together.
3. The client polls `/api/matchmaking/status`. The API attempts allocation when a healthy registered server has enough free capacity (minimum: 2 Solo, 4 Duo or 8 Squad players, ensuring two complete teams).
4. The API issues a short-lived HMAC-signed, one-time join ticket tied to player, match and server.
5. The client connects to the assigned UDP endpoint and sends the ticket. The dedicated server asks the API to consume it; the world spawns that player only after successful validation.
6. The server submits each player's verified placement and kills to the progression API after the match result.

### API service environment

Set these on the public ZORIX API service (Render Dashboard -> service -> Environment):

- `ZORIX_SERVER_SECRET`: random secret, at least 32 characters; shared only with the dedicated server.
- `ZORIX_JOIN_TICKET_SECRET`: a separate random secret, at least 32 characters.
- `ZORIX_MIN_MATCH_PLAYERS=2`: lower-bound queue threshold. The allocator still requires two complete teams: 2 Solo, 4 Duo or 8 Squad players.
- Keep `ZORIX_JWT_SECRET` configured as before.

Generate secrets privately with `openssl rand -hex 32`. Do not paste secret values into chat or commit them to GitHub.

### Dedicated server environment

Copy `server/.env.example` to `server/.env`, fill in the same server secret, the API HTTPS URL, and the VM's public IPv4/DNS name. Use the ARM64 artifact on OCI Ampere. Open UDP 24560 in both OCI network rules and Ubuntu firewall. The compose file passes the API URL and server credentials into the game-server process, which registers and sends heartbeats automatically.

A server is locked to one match after the first ticket is validated; deploy one dedicated-server process per active match for this first staging iteration. A server fleet autoscaler, process recycle/match reset and reconnect recovery are not yet implemented.

## Production gates and remaining work

- Merge the PR chain and run the Linux x86_64/ARM64 dedicated-server and API test workflows.
- Configure the API secrets and provision a public UDP-capable VM; Render's existing HTTP API service is not a UDP game server.
- Verify one Android client can connect to the registered server, then test two devices with real matchmaking.
- Test 2, 5, 10, 25 and 50 clients while measuring CPU, RAM, outbound bandwidth, packet loss, ping and tick stability.
- Add fleet autoscaling/orchestration, server recycling after a match, reconnect handling, metrics, alerts and graceful shutdown.
- A successful export or queue allocation does not prove that 50-player gameplay capacity has been sustained.
