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

func _ready():
    var config = ConfigFile.new()
    if config.load("user://zorix_settings.cfg") == OK:
        tactical_mode = str(config.get_value("game", "mode", "battle_royale")) == "tactical_5v5"

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
    sync.replication_config = replication
    add_child(sync)

    if tactical_mode:
        bomb_position = Vector3(-34, 0.5, -28)
        _create_bomb_visual()
    else:
        _create_safe_zone_ring()

    if multiplayer.is_server():
        _spawn_loot()

func _process(delta: float):
    if not multiplayer.is_server():
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
    add_child(safe_zone_ring)
    _update_safe_zone_ring()

func _update_safe_zone_ring():
    var ring = TorusMesh.new()
    ring.inner_radius = maxf(0.1, safe_zone_radius - 0.22)
    ring.outer_radius = safe_zone_radius + 0.22
    ring.rings = 48
    ring.ring_segments = 6
    safe_zone_ring.mesh = ring
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
        var kind = "medkit" if index % 4 == 0 else "ammo"
        spawner.spawn({
            "entity_type": "loot",
            "pickup_kind": kind,
            "amount": 50 if kind == "ammo" else 35,
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

@rpc("any_peer", "call_remote", "reliable")
func request_tactical_action():
    if not multiplayer.is_server() or not tactical_mode:
        return
    var peer_id = multiplayer.get_remote_sender_id()
    if peer_id <= 0:
        return
    var player = get_parent().get_node_or_null("Player_%d" % peer_id)
    if player == null or player.is_dead:
        return

    var is_attacker = (peer_id % 2) == 1
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
