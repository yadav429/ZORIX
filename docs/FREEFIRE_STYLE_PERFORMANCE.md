# Free Fire-style graphics and smoother gameplay update

## Included in this change
- Lobby graphics presets: Low (performance), Balanced (default), and HD.
- Lobby frame-rate targets: 30, 60, and 90 FPS. The selected value is a cap/target; actual FPS depends on the device, thermal state, battery mode, and scene load.
- Graphics settings are saved in `user://zorix_settings.cfg` and remain compatible with the older performance boolean.
- Battle Royale and Tactical arena lighting use the selected quality preset.
- Battle Royale decorative tree/rock density scales by quality to reduce load on lower-end Android devices.
- Match HUD shows a live FPS estimate to help device testing.
- Holding the FIRE touch control repeats shots at the weapon's configured fire cooldown; releasing it stops firing.
- Removed a per-touch movement debug print that was generating unnecessary log traffic.
- Safe-zone ring now reuses one TorusMesh and changes its scale instead of allocating a new mesh every frame.

## Current gameplay foundation
The project already contains prototype implementations for third-person movement, mobile joystick/camera controls, jump, sprint state, hitscan shooting, health/death, ammo/reload, medkit/ammo pickups, a shrinking safe zone, and a Tactical 5v5 bomb objective. Lobby/account, matchmaking, teams/friends, server fleet allocation, and the 50-player match path are still prototype foundations and require end-to-end integration and tests.

## Not yet production-complete
- No original HD texture/character/weapon asset pack is included by this change; the existing low-poly procedural visuals remain.
- No device has yet been benchmarked to prove stable 60/90 FPS.
- No real-client network gameplay test has proved 50 players per match or 500 concurrent players across the fleet.
- Client-side prediction/interpolation, robust team assignment, full weapon inventory/switching, timed revive, minimap, staged random safe zones, and complete match-result flow remain follow-up work.
- The 500-player launcher is staging infrastructure only; it is not evidence of 500-player capacity and does not provide autoscaling.

## Verification required
1. GitHub Actions must successfully import the Godot project and export the Android APK and dedicated-server artifacts for this exact commit.
2. Install the APK on low-, mid-, and high-range Android devices and compare Low/Balanced/HD presets.
3. Record average and 1% low FPS, temperature, memory, packet loss, RTT, and disconnects during real gameplay.
4. Progress real-client tests gradually: 2, 5, 10, 25, then 50 clients per match. Only publish a capacity claim after the measured tests pass.
