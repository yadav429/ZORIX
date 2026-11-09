# PR #21 - Complete Match Gameplay Foundation

This PR adds the next playable gameplay layer to ZORIX.

## Implemented in this branch

- Four weapon definitions: rifle, SMG, shotgun and sniper, each with distinct damage, fire interval, range and magazine capacity.
- Server-authoritative weapon pickup, inventory ownership, weapon switching and per-weapon magazine ammo.
- Mobile weapon-switch control and procedural weapon model variants with stock, magazine and sight geometry.
- 20-second downed/bleed-out window when a teammate can still revive the player.
- Teammate revive request is server validated by team and distance; revive channel takes 4 seconds and is cancelled if the reviver moves away, is downed, or the target is no longer valid.
- Server-side Solo, Duo and Squad assignment fills the least-numbered team with available capacity. Tactical mode assigns two five-player teams.
- Mobile minimap shows the local player, visible player positions, friendly/enemy markers and Battle Royale safe-zone boundary.
- Match-result overlay shows victory/defeat/draw, winning team, local kills and deaths. Battle Royale result evaluation waits until the selected team size plus one players have joined; Tactical results follow bomb defuse/explosion.
- Procedural character model details: shoulder armor, backpack, visor, straps and knee pads.

## Important limits

- Character and weapon visuals are procedural low-poly meshes, not licensed or production HD character/weapon asset packs. Replace with optimized authored GLB assets before claiming Free Fire-level visual fidelity.
- Weapon ammunition currently uses one shared reserve-ammo pool; magazine counts are tracked per weapon. Attachments, weapon recoil tuning, reload animations and weapon-specific pickup balancing remain future work.
- Match-result screen is a local summary, not yet a persistent server leaderboard or match-history service.
- The minimap is a player-relative tactical overlay and does not yet show named POIs, vehicles or terrain texture.
- Team assignment is performed by the dedicated game server from the selected team-size configuration. It does not yet use Supabase lobby party reservations or persistent friend-party grouping.
- The 4-second revive channel and 20-second bleed-out timer require real two-device validation.
- No claim is made about 50 real players, 500 concurrent players, stable 60 FPS or production matchmaking from CI builds alone.

## Validation required

1. Android APK and Linux dedicated-server GitHub Actions builds.
2. Offline smoke test: collect weapon pickups, switch between weapon types, fire and reload.
3. Two-device same-network test: Solo/Duo/Squad assignment, downed timer, 4-second teammate revive and match-result broadcast.
4. Tactical test: five players on each team, bomb plant, defuse and explosion outcomes.
5. Gradual real-client test at 2, 5, 10, 25 and finally 50 players per match. Record RTT, packet loss, disconnects, server CPU/RAM and Android FPS/thermal behavior.
