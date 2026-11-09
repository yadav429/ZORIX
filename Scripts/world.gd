extends Node3D

const PLAYER = preload("res://Scenes/Player.tscn")
const MOBILE_UI = preload("res://Scripts/mobile_ui.gd")
const ENEMY = preload("res://Scripts/enemy.gd")
const FRIENDLY = preload("res://Scripts/friendly_soldier.gd")
const LOOT = preload("res://Scripts/loot_pickup.gd")
const MATCH_RULES = preload("res://Scripts/match_rules.gd")

var rng = RandomNumberGenerator.new()

func material(color: Color, metallic := 0.0, rough := 0.8) -> StandardMaterial3D:
    var m = StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = rough
    return m

func add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material):
    var mesh = BoxMesh.new()
    mesh.size = size
    var obj = MeshInstance3D.new()
    obj.mesh = mesh
    obj.material_override = mat
    obj.position = pos
    parent.add_child(obj)
    return obj

func add_tree(x: float, z: float, wood: Material, leaves: Material):
    var trunk_mesh = CylinderMesh.new()
    trunk_mesh.top_radius = 0.15
    trunk_mesh.bottom_radius = 0.25
    trunk_mesh.height = 2.4

    var trunk = MeshInstance3D.new()
    trunk.mesh = trunk_mesh
    trunk.material_override = wood
    trunk.position = Vector3(x, 1.2, z)
    trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(trunk)

    var crown_mesh = SphereMesh.new()
    var crown = MeshInstance3D.new()
    crown.mesh = crown_mesh
    crown.material_override = leaves
    crown.scale = Vector3(1.2, 1.5, 1.2)
    crown.position = Vector3(x, 2.8, z)
    crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(crown)

func add_mountain(x: float, z: float, height: float, mat: Material):
    # ConeMesh replaces the old cylinder-shaped mountains.
    var mesh = ConeMesh.new()
    mesh.top_radius = 0.0
    mesh.bottom_radius = height * 0.65
    mesh.height = height
    mesh.radial_segments = 9

    var obj = MeshInstance3D.new()
    obj.mesh = mesh
    obj.material_override = mat
    obj.position = Vector3(x, height / 2.0, z)
    obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(obj)

func add_building(x: float, z: float, h: float, concrete: Material, glass: Material):
    add_box(self, Vector3(x, h / 2.0, z),
        Vector3(7, h, 7), concrete)

    for y in range(2, int(h), 3):
        add_box(self, Vector3(x, float(y), z - 3.56),
            Vector3(5.0, 1.0, 0.12), glass)


func _build_tactical_mode():
    var floor_mat = material(Color("#343b3d"), 0.15, 0.85)
    var wall_mat = material(Color("#77766d"), 0.05, 0.9)
    var cover_mat = material(Color("#8b6847"), 0.0, 0.95)
    var blue_mat = material(Color("#1c456d"))
    var red_mat = material(Color("#762e2e"))
    var site_mat = material(Color("#d7b34d"), 0.1, 0.45)

    add_box(self, Vector3(0, -0.55, 0), Vector3(112, 1, 92), floor_mat)
    add_box(self, Vector3(0, 3, -46), Vector3(112, 6, 2), wall_mat)
    add_box(self, Vector3(0, 3, 46), Vector3(112, 6, 2), wall_mat)
    add_box(self, Vector3(-56, 3, 0), Vector3(2, 6, 92), wall_mat)
    add_box(self, Vector3(56, 3, 0), Vector3(2, 6, 92), wall_mat)

    for x in [-34.0, -17.0, 17.0, 34.0]:
        add_box(self, Vector3(x, 1.4, -10), Vector3(7, 2.8, 3), cover_mat)
        add_box(self, Vector3(x, 1.4, 12), Vector3(7, 2.8, 3), cover_mat)
    add_box(self, Vector3(-7, 1.8, 0), Vector3(5, 3.6, 10), wall_mat)
    add_box(self, Vector3(7, 1.8, 0), Vector3(5, 3.6, 10), wall_mat)
    add_box(self, Vector3(0, 1.2, -25), Vector3(14, 2.4, 5), cover_mat)
    add_box(self, Vector3(0, 1.2, 25), Vector3(14, 2.4, 5), cover_mat)

    add_box(self, Vector3(-34, 0.08, -28), Vector3(12, 0.12, 12), site_mat)
    add_box(self, Vector3(34, 0.08, 28), Vector3(12, 0.12, 12), site_mat)
    var site_a = Label3D.new()
    site_a.text = "SITE A"
    site_a.position = Vector3(-34, 3.2, -28)
    site_a.font_size = 48
    site_a.modulate = Color("#ffe28a")
    add_child(site_a)
    var site_b = Label3D.new()
    site_b.text = "SITE B"
    site_b.position = Vector3(34, 3.2, 28)
    site_b.font_size = 48
    site_b.modulate = Color("#ffe28a")
    add_child(site_b)

    add_box(self, Vector3(0, 0.08, 36), Vector3(28, 0.12, 5), blue_mat)
    add_box(self, Vector3(0, 0.08, -36), Vector3(28, 0.12, 5), red_mat)

    var quality := _graphics_quality()
    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -30, 0)
    sun.light_energy = 1.15
    sun.shadow_enabled = quality != "low"
    sun.directional_shadow_max_distance = 38.0 if quality == "low" else (55.0 if quality == "balanced" else 78.0)
    add_child(sun)

    var sky = Sky.new()
    var sky_mat = ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("#1b3655")
    sky_mat.sky_horizon_color = Color("#a0a9ad")
    sky.sky_material = sky_mat
    var env = Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.75
    var world_env = WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)

    var match_rules = Node3D.new()
    match_rules.name = "MatchRules"
    match_rules.add_to_group("match_rules")
    match_rules.set_script(MATCH_RULES)
    add_child(match_rules)

    var player = null
    if multiplayer.is_server() and not _is_dedicated_server():
        player = player_spawner.spawn({"peer_id": multiplayer.get_unique_id(), "team_id": 0, "spawn_position": Vector3(0, 0, 35)})

        var enemy_positions = [
            Vector3(-5, 0, -34), Vector3(5, 0, -34),
            Vector3(-15, 0, -30), Vector3(15, 0, -30),
            Vector3(0, 0, -38)
        ]
        for enemy_pos in enemy_positions:
            var enemy = ENEMY.new()
            enemy.position = enemy_pos
            enemy.move_speed = 2.4
            add_child(enemy)

        for squad_index in range(4):
            var squad = FRIENDLY.new()
            squad.name = "BlueTeam_%d" % (squad_index + 1)
            squad.follow_offset = Vector3(-3.0 if squad_index % 2 == 0 else 3.0, 0, 4.0 + float(squad_index / 2) * 2.5)
            squad.position = player.position + squad.follow_offset
            add_child(squad)

    var hud = CanvasLayer.new()
    var banner = Label.new()
    banner.text = "ZORIX TACTICAL 5v5  •  BLUE vs RED  •  SITES A / B"
    banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    banner.offset_top = 10
    banner.offset_bottom = 48
    banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    banner.add_theme_font_size_override("font_size", 17)
    banner.add_theme_color_override("font_color", Color("#ffe28a"))
    hud.add_child(banner)
    add_child(hud)

    var ui = CanvasLayer.new()
    ui.set_script(MOBILE_UI)
    add_child(ui)

var player_spawner: MultiplayerSpawner

func _spawn_network_player(data: Variant) -> Node:
    var entity_type := str(data.get("entity_type", "player"))
    if entity_type == "loot":
        var pickup := Area3D.new()
        pickup.set_script(LOOT)
        pickup.name = "Loot_%s_%d" % [str(data.get("pickup_kind", "ammo")), int(data.get("loot_id", 0))]
        pickup.pickup_kind = str(data.get("pickup_kind", "ammo"))
        pickup.amount = int(data.get("amount", 30))
        pickup.position = data.get("spawn_position", Vector3.ZERO)
        return pickup

    var peer_id := int(data.get("peer_id", 1))
    var player := PLAYER.instantiate()
    player.name = "Player_%d" % peer_id
    player.set_multiplayer_authority(peer_id)
    player.team_id = int(data.get("team_id", peer_id - 1))
    player.position = data.get("spawn_position", Vector3(0, 0, 25))
    return player

func _team_size() -> int:
    var config := ConfigFile.new()
    if config.load("user://zorix_settings.cfg") == OK:
        if str(config.get_value("game", "mode", "battle_royale")) == "tactical_5v5":
            return 5
        return clampi(int(config.get_value("game", "team_size", 4)), 1, 4)
    return 4

func _next_team_id() -> int:
    var team_size := _team_size()
    var joined_count := get_tree().get_nodes_in_group("player").size()
    if team_size == 5:
        return 0 if joined_count < 5 else 1
    return int(joined_count / team_size)

func _on_network_peer_connected(peer_id: int):
    if not multiplayer.is_server() or player_spawner == null:
        return
    if get_tree().get_nodes_in_group("player").size() >= 50:
        multiplayer.multiplayer_peer.disconnect_peer(peer_id)
        return
    var team_id := _next_team_id()
    var team_size := _team_size()
    var spawn_side := -1.0 if team_size == 5 and team_id == 0 else 1.0
    var spawn_position := Vector3(float((peer_id % 5) - 2) * 3.0, 0, 25.0 * spawn_side + float(peer_id % 3) * 3.0)
    player_spawner.spawn({"peer_id": peer_id, "team_id": team_id, "spawn_position": spawn_position})
    print("ZORIX PLAYER JOINED | peer=%d | count=%d/50" % [peer_id, get_tree().get_nodes_in_group("player").size()])

func _on_network_peer_disconnected(peer_id: int):
    if not multiplayer.is_server():
        return
    var player := get_node_or_null("Player_%d" % peer_id)
    if player != null:
        player.queue_free()
    print("ZORIX PLAYER LEFT | peer=%d" % peer_id)

func _graphics_quality() -> String:
    var config := ConfigFile.new()
    if config.load("user://zorix_settings.cfg") == OK:
        var quality := str(config.get_value("graphics", "quality", "performance" if bool(config.get_value("graphics", "performance", false)) else "balanced"))
        if quality in ["low", "balanced", "hd"]:
            return quality
    return "balanced"

func _is_dedicated_server() -> bool:
    return OS.has_feature("dedicated_server") or OS.get_cmdline_user_args().has("--server")

func _setup_player_networking():
    player_spawner = MultiplayerSpawner.new()
    player_spawner.name = "PlayerSpawner"
    player_spawner.spawn_path = NodePath("..")
    player_spawner.spawn_function = Callable(self, "_spawn_network_player")
    add_child(player_spawner)
    multiplayer.peer_connected.connect(_on_network_peer_connected)
    multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)
    # Client-host creates its own player; dedicated server waits for remote clients.

func _ready():
    rng.seed = 842771
    _setup_player_networking()

    var mode_config = ConfigFile.new()
    if mode_config.load("user://zorix_settings.cfg") == OK:
        if str(mode_config.get_value("game", "mode", "battle_royale")) == "tactical_5v5":
            _build_tactical_mode()
            return

    var grass = material(Color(0.16, 0.34, 0.13))
    var dark_grass = material(Color(0.07, 0.22, 0.09))
    var ocean = material(Color(0.005, 0.12, 0.30), 0.5, 0.25)
    var road = material(Color(0.09, 0.10, 0.11), 0.1, 0.9)
    var concrete = material(Color(0.38, 0.43, 0.48), 0.2)
    var glass = material(Color(0.03, 0.32, 0.48), 0.65, 0.2)
    var wood = material(Color(0.22, 0.11, 0.05))
    var leaves = material(Color(0.04, 0.25, 0.08))
    var sand = material(Color(0.68, 0.49, 0.25))
    var snow = material(Color(0.88, 0.92, 0.96))
    var mountain = material(Color(0.25, 0.30, 0.34))
    var military = material(Color(0.12, 0.20, 0.10))

    # OCEAN
    add_box(self, Vector3(0, -2.0, 0),
        Vector3(600, 1, 600), ocean)

    # INDIA BATTLEFIELD: expanded 18% for a larger playable island.
    var india = CSGPolygon3D.new()
    india.name = "IndiaBattlefield"
    india.polygon = PackedVector2Array([
        Vector2(-14, 52), Vector2(-5, 58), Vector2(8, 53),
        Vector2(18, 44), Vector2(26, 34), Vector2(34, 24),
        Vector2(43, 17), Vector2(50, 14), Vector2(53, 7),
        Vector2(46, 3), Vector2(40, 8), Vector2(34, 7),
        Vector2(31, -2), Vector2(25, -12), Vector2(20, -24),
        Vector2(14, -37), Vector2(8, -51), Vector2(1, -66),
        Vector2(-6, -53), Vector2(-12, -40), Vector2(-19, -27),
        Vector2(-25, -14), Vector2(-30, 0), Vector2(-31, 14),
        Vector2(-25, 26), Vector2(-20, 39), Vector2(-14, 52)
    ])
    india.depth = 1.0
    india.mode = CSGPolygon3D.MODE_DEPTH
    india.rotation_degrees.x = 90
    india.scale = Vector3(1.42, 1.42, 1.0)
    india.position = Vector3(0, -0.55, 0)
    india.material = grass
    india.use_collision = true
    add_child(india)

    # MAIN ROADS
    add_box(self, Vector3(0, 0.03, 5),
        Vector3(10, 0.08, 108), road)
    add_box(self, Vector3(5, 0.04, -5),
        Vector3(82, 0.08, 9), road)
    add_box(self, Vector3(15, 0.05, -25),
        Vector3(8, 0.08, 62), road)

    # EXTRA OUTER ROADS / CONNECTING AREAS
    add_box(self, Vector3(-20, 0.035, 18),
        Vector3(42, 0.07, 7), road)
    add_box(self, Vector3(29, 0.035, 18),
        Vector3(7, 0.07, 42), road)

    # DELHI STYLE CITY
    for x in range(12, 37, 9):
        for z in range(-15, 16, 10):
            var h = rng.randf_range(9.0, 23.0)
            add_building(float(x), float(z), h, concrete, glass)

    # RAJASTHAN DESERT
    add_box(self, Vector3(-19, 0.025, -8),
        Vector3(22, 0.04, 30), sand)
    for i in range(7):
        var x = -29.0 + float(i) * 4.0
        add_box(self, Vector3(x, 1.5, -8),
            Vector3(3, 3, 3), sand)

    # HIMALAYA: taller, low-poly cone mountains with snow caps.
    for i in range(15):
        var x = -31.0 + float(i) * 4.4
        var h = rng.randf_range(17.0, 29.0)
        add_mountain(x, 49.0, h, mountain)
        add_mountain(x, 49.0, h * 0.34, snow)

    # Quality presets scale decorative object density for mobile devices.
    var quality := _graphics_quality()
    var tree_count := 28 if quality == "low" else (52 if quality == "balanced" else 72)
    for i in range(tree_count):
        var x = rng.randf_range(-27.0, 28.0)
        var z = rng.randf_range(-49.0, 36.0)
        if abs(x) > 12.0 and abs(z) > 8.0:
            add_tree(x, z, wood, leaves)

    # MILITARY BASE
    add_box(self, Vector3(-25, 2, 12),
        Vector3(15, 4, 17), military)
    add_box(self, Vector3(-25, 4.1, 12),
        Vector3(9, 0.2, 10), concrete)
    add_box(self, Vector3(-34, 4, 12),
        Vector3(2, 8, 2), concrete)
    add_box(self, Vector3(-34, 8, 12),
        Vector3(5, 0.5, 5), military)

    # EXTRA ROCKS
    var rock_count := 10 if quality == "low" else (20 if quality == "balanced" else 32)
    for i in range(rock_count):
        var rock = SphereMesh.new()
        var obj = MeshInstance3D.new()
        obj.mesh = rock
        obj.material_override = mountain
        obj.scale = Vector3(
            rng.randf_range(0.5, 2.0),
            rng.randf_range(0.4, 1.2),
            rng.randf_range(0.5, 2.0)
        )
        obj.position = Vector3(
            rng.randf_range(-29, 29), 0.4,
            rng.randf_range(-58, 58)
        )
        obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(obj)

    # SUN / MOBILE-FRIENDLY SHADOW DISTANCE
    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -35, 0)
    sun.light_energy = 1.2
    sun.shadow_enabled = quality != "low"
    sun.directional_shadow_max_distance = 42.0 if quality == "low" else (65.0 if quality == "balanced" else 90.0)
    sun.add_to_group("world_lights")
    add_child(sun)

    # SKY AND AMBIENT LIGHT
    var sky = Sky.new()
    var sky_mat = ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.08, 0.30, 0.62)
    sky_mat.sky_horizon_color = Color(0.55, 0.72, 0.90)
    sky_mat.ground_bottom_color = Color(0.08, 0.12, 0.10)
    sky_mat.ground_horizon_color = Color(0.45, 0.55, 0.45)
    sky.sky_material = sky_mat

    var env = Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

    var world_env = WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)

    var match_rules = Node3D.new()
    match_rules.name = "MatchRules"
    match_rules.add_to_group("match_rules")
    match_rules.set_script(MATCH_RULES)
    add_child(match_rules)

    # PLAYER
    var player = null
    if multiplayer.is_server() and not _is_dedicated_server():
        player = player_spawner.spawn({"peer_id": multiplayer.get_unique_id(), "team_id": 0, "spawn_position": Vector3(0, 0, 25)})
    else:
        player = get_tree().get_first_node_in_group("local_player")

    # Server owns AI simulation; remote clients receive the player entities.
    if multiplayer.is_server():
        var enemy_positions = [
            Vector3(0, 0, 7), Vector3(-6, 0, 5),
            Vector3(6, 0, 5), Vector3(-10, 0, -4),
            Vector3(10, 0, -4), Vector3(0, 0, -12)
        ]
        for enemy_pos in enemy_positions:
            var enemy = ENEMY.new()
            enemy.position = enemy_pos
            add_child(enemy)

        # TWO FRIENDLY SQUAD SOLDIERS
        if player != null:
            for squad_index in range(2):
                var squad = FRIENDLY.new()
                squad.name = "FriendlySquad_%d" % (squad_index + 1)
                squad.follow_offset = Vector3(-2.4 if squad_index == 0 else 2.4, 0, 3.0)
                squad.position = player.position + squad.follow_offset
                add_child(squad)

    # MOBILE CONTROLS
    var ui = CanvasLayer.new()
    ui.set_script(MOBILE_UI)
    add_child(ui)
