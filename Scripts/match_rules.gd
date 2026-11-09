extends Node3D

const LOOT_SCRIPT = preload("res://Scripts/loot_pickup.gd")

var tactical_mode := false
var safe_zone_radius: float = 78.0
var safe_zone_elapsed: float = 0.0
var safe_zone_tick: float = 0.0
var safe_zone_ring: MeshInstance3D

var bomb_planted := false
var bomb_defused := false
var bomb_exploded := false
var bomb_timer: float = 0.0
var defuse_progress: float = 0.0
var bomb_position := Vector3.ZERO
var bomb_visual: MeshInstance3D
var match_finished := false
var match_started := false

func _ready():
    var config = ConfigFile.new()
    if config.load("user://zorix_settings.cfg") == OK:
        tactical_mode = str(config.get_value("game", "mode", "battle_royale")) == "tactical_5v5"

    if tactical_mode:
        bomb_position = Vector3(-34, 0.5, -28)
        _create_bomb_visual()
    else:
        _create_safe_zone_ring()

    var sync = MultiplayerSynchronizer.new()
    sync.name = "RulesSync"
    sync.root_path = NodePath("..")
    var replication = SceneReplicationConfig.new()
    replication.add_property(NodePath(".:safe_zone_radius"))
    replication.add_property(NodePath(".:bomb_planted"))
    replication.add_property(NodePath(".:bomb_defused"))
    replication.add_property(NodePath(".:bomb_exploded"))
    replication.add_property(NodePath(".:bomb_timer"))
    replication.add_property(NodePath(".:bomb_position"))
    if tactical_mode:
        replication.add_property(NodePath("BombDevice:visible"))
        replication.add_property(NodePath("BombDevice:position"))
    sync.replication_config = replication
    sync.set_multiplayer_authority(1)
    add_child(sync)

    if multiplayer.is_server() and not tactical_mode:
        _spawn_loot()

func _process(delta: float):
    if not multiplayer.is_server():
        if not tactical_mode and safe_zone_ring != null:
            _update_safe_zone_ring()
        return

    if not tactical_mode and safe_zone_radius > 8.0:
        safe_zone_elapsed += delta
        safe_zone_tick += delta
        safe_zone_radius = maxf(8.0, 78.0 - safe_zone_elapsed * 0.28)
        if safe_zone_ring != null:
            _update_safe_zone_ring()
        if safe_zone_tick >= 1.0:
            safe_zone_tick = 0.0
            _damage_players_outside_zone()

    if not match_finished and (tactical_mode or match_started):
        if tactical_mode:
            if bomb_defused:
                _finish_match(1, "BOMB DEFUSED")
            elif bomb_exploded:
                _finish_match(0, "BOMB EXPLODED")
        else:
            _evaluate_battle_royale_result()

    if tactical_mode and bomb_planted and not bomb_defused and not bomb_exploded:
        bomb_timer = maxf(0.0, bomb_timer - delta)
        if bomb_timer <= 0.0:
            bomb_exploded = true
            print("ZORIX: BOMB EXPLODED - DEFENDERS LOSE")

func _create_safe_zone_ring():
    safe_zone_ring = MeshInstance3D.new()
    safe_zone_ring.name = "SafeZoneBoundary"
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.1, 0.8, 1.0, 0.72)
    mat.emission_enabled = true
    mat.emission = Color(0.05, 0.45, 0.9)
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    safe_zone_ring.material_override = mat
    var ring = TorusMesh.new()
    ring.inner_radius = 0.997
    ring.outer_radius = 1.003
    ring.rings = 48
    ring.ring_segments = 6
    safe_zone_ring.mesh = ring
    add_child(safe_zone_ring)
    _update_safe_zone_ring()

func _update_safe_zone_ring():
    # Reuse one torus mesh; only scale it as the zone shrinks.
    # Rebuilding a mesh every frame caused avoidable allocations and frame spikes.
    safe_zone_ring.scale = Vector3(safe_zone_radius, 1.0, safe_zone_radius)
    safe_zone_ring.position = Vector3(0, 0.12, 0)

func _damage_players_outside_zone():
    for player in get_tree().get_nodes_in_group("player"):
        if not is_instance_valid(player) or player.is_dead:
            continue
        var flat_position = Vector2(player.global_position.x, player.global_position.z)
        if flat_position.length() > safe_zone_radius:
            player.take_damage(5)

func _spawn_loot():
    var rng = RandomNumberGenerator.new()
    rng.seed = 481209
    var points = [
        Vector3(-20, 0, 15), Vector3(18, 0, 12),
        Vector3(25, 0, -10), Vector3(-24, 0, -18),
        Vector3(2, 0, -32), Vector3(-8, 0, 35),
        Vector3(30, 0, 30), Vector3(-30, 0, 2),
        Vector3(10, 0, 42), Vector3(-12, 0, -42),
        Vector3(0, 0, 5), Vector3(22, 0, -35)
    ]
    var spawner = get_parent().get("player_spawner")
    if spawner == null:
        push_warning("ZORIX: MultiplayerSpawner unavailable; loot not spawned.")
        return
    for index in range(points.size()):
        var kind = "medkit" if index % 4 == 0 else ("weapon" if index % 5 == 0 else "ammo")
        spawner.spawn({
            "entity_type": "loot",
            "pickup_kind": kind,
            "amount": 50 if kind == "ammo" else 35,
            "weapon_index": 1 + (index % 3),
            "loot_id": index,
            "spawn_position": points[index]
        })

func _create_bomb_visual():
    bomb_visual = MeshInstance3D.new()
    bomb_visual.name = "BombDevice"
    var mesh = BoxMesh.new()
    mesh.size = Vector3(0.55, 0.35, 0.55)
    bomb_visual.mesh = mesh
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color("#d49a34")
    mat.emission_enabled = true
    mat.emission = Color("#6b3a0c")
    bomb_visual.material_override = mat
    bomb_visual.position = bomb_position
    bomb_visual.visible = false
    add_child(bomb_visual)

func interact():
    if not tactical_mode:
        return
    if multiplayer.is_server():
        _server_tactical_action(multiplayer.get_unique_id())
    else:
        request_tactical_action.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func request_tactical_action():
    if not multiplayer.is_server() or not tactical_mode:
        return
    _server_tactical_action(multiplayer.get_remote_sender_id())

func _server_tactical_action(peer_id: int):
    if peer_id <= 0:
        return
    var player = get_parent().get_node_or_null("Player_%d" % peer_id)
    if player == null or player.is_dead:
        return

    var is_attacker = player.team_id == 0
    if not bomb_planted:
        if not is_attacker:
            return
        var site_a = Vector3(-34, 0, -28)
        var site_b = Vector3(34, 0, 28)
        var site = site_a if player.global_position.distance_to(site_a) < player.global_position.distance_to(site_b) else site_b
        if player.global_position.distance_to(site) <= 9.0:
            bomb_position = site + Vector3(0, 0.5, 0)
            bomb_planted = true
            bomb_timer = 40.0
            bomb_visual.position = bomb_position
            bomb_visual.visible = true
            print("ZORIX: BOMB PLANTED")
    elif not bomb_defused and not bomb_exploded:
        if is_attacker or player.global_position.distance_to(bomb_position) > 4.5:
            return
        defuse_progress += 1.0
        if defuse_progress >= 5.0:
            bomb_defused = true
            bomb_timer = 0.0
            bomb_visual.visible = false
            print("ZORIX: BOMB DEFUSED - DEFENDERS WIN")


func _evaluate_battle_royale_result():
    var players := get_tree().get_nodes_in_group("player")
    var config := ConfigFile.new()
    var team_size := 4
    if config.load("user://zorix_settings.cfg") == OK:
        team_size = clampi(int(config.get_value("game", "team_size", 4)), 1, 4)
    if players.size() < team_size + 1:
        return
    match_started = true
    var living_teams: Array[int] = []
    for player in players:
        if not is_instance_valid(player) or player.is_dead:
            continue
        var team := int(player.team_id)
        if team < 0:
            team = int(player.get_multiplayer_authority())
        if not living_teams.has(team):
            living_teams.append(team)
    if living_teams.size() <= 1:
        _finish_match(living_teams[0] if not living_teams.is_empty() else -1, "LAST TEAM STANDING")

func _finish_match(winner_team_id: int, reason: String):
    if match_finished or not multiplayer.is_server():
        return
    match_finished = true
    print("ZORIX MATCH RESULT | winner_team=%d | reason=%s" % [winner_team_id, reason])
    show_match_result.rpc(winner_team_id, reason)

@rpc("authority", "call_local", "reliable")
func show_match_result(winner_team_id: int, reason: String):
    var layer := CanvasLayer.new()
    layer.name = "MatchResultOverlay"
    layer.layer = 30
    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.035, 0.055, 0.88)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(shade)
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.position = Vector2(-190, -125)
    panel.size = Vector2(380, 250)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#102b38")
    style.border_color = Color("#53d6c1")
    style.set_border_width_all(3)
    style.set_corner_radius_all(18)
    panel.add_theme_stylebox_override("panel", style)
    var column := VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    panel.add_child(column)
    var heading := Label.new()
    heading.text = "MATCH COMPLETE"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 27)
    heading.add_theme_color_override("font_color", Color("#ffe08a"))
    column.add_child(heading)
    var result := Label.new()
    var local_player = get_tree().get_first_node_in_group("local_player")
    var local_team := int(local_player.team_id) if local_player != null else -99
    result.text = "VICTORY" if winner_team_id == local_team else ("DRAW" if winner_team_id < 0 else "DEFEAT")
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.add_theme_font_size_override("font_size", 34)
    result.add_theme_color_override("font_color", Color("#ffffff"))
    column.add_child(result)
    var details := Label.new()
    details.text = "%s\\nTeam %d\\nKills: %d  |  Deaths: %d" % [reason, winner_team_id, int(local_player.kills) if local_player != null else 0, int(local_player.deaths) if local_player != null else 0]
    details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    details.add_theme_font_size_override("font_size", 16)
    column.add_child(details)
    get_tree().current_scene.add_child(layer)
    layer.add_child(panel)
