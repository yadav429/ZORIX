extends CharacterBody3D

@export var speed: float = 6.0
@export var sprint_speed: float = 10.0
@export var jump_force: float = 5.0
@export var gravity: float = 15.0
@export var mouse_sensitivity: float = 0.004
@export var acceleration: float = 22.0
@export var shoot_cooldown: float = 0.18
@export var bullet_range: float = 150.0

var mobile_input := Vector2.ZERO
var is_sprinting := false
var shoot_timer := 0.0
var health: int = 100
var ammo: int = 30
var reserve_ammo: int = 120
var is_dead: bool = false
var is_downed: bool = false
var downed_timer: float = 0.0
var team_id: int = -1
var kills: int = 0
var deaths: int = 0
var weapon_inventory: Array[int] = [0]
var weapon_ammo: Array[int] = [30, 36, 8, 5, 6, 30, 8, 60]
var current_weapon_index: int = 0
var downed_by_peer_id: int = 0
var revive_target = null
var revive_progress: float = 0.0
var weapon_switch_cooldown: float = 0.0
var last_model_weapon_index := -1
const WEAPON_DATA := [
    {"name": "VEER-47", "class": "ASSAULT RIFLE", "damage": 25, "cooldown": 0.18, "range": 150.0, "mag": 30},
    {"name": "KALKA-7", "class": "SMG", "damage": 17, "cooldown": 0.095, "range": 95.0, "mag": 36},
    {"name": "TRISHUL", "class": "SHOTGUN", "damage": 12, "cooldown": 0.72, "range": 32.0, "mag": 8},
    {"name": "SHER-X", "class": "SNIPER RIFLE", "damage": 85, "cooldown": 1.15, "range": 240.0, "mag": 5},
    {"name": "BRAHMOS", "class": "HEAVY LAUNCHER", "damage": 100, "cooldown": 1.6, "range": 220.0, "mag": 1},
    {"name": "AGNI-X", "class": "ASSAULT RIFLE", "damage": 29, "cooldown": 0.16, "range": 165.0, "mag": 30},
    {"name": "RUDRA-99", "class": "HEAVY RIFLE", "damage": 32, "cooldown": 0.22, "range": 175.0, "mag": 8},
    {"name": "GARUD-5", "class": "LIGHT MACHINE GUN", "damage": 21, "cooldown": 0.13, "range": 145.0, "mag": 60}
]
var last_server_shot_msec: int = 0
var server_move_input := Vector2.ZERO
var server_sprint := false
var server_camera_yaw := 0.0
var jump_pending := false
var input_send_accumulator := 0.0
var last_input_msec := 0

var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var gun_node: Node3D

func _ready():
    add_to_group("player")
    floor_snap_length = 0.3

    var sync = MultiplayerSynchronizer.new()
    sync.name = "NetworkSync"
    sync.root_path = NodePath("..")
    var replication = SceneReplicationConfig.new()
    replication.add_property(NodePath(".:position"))
    replication.add_property(NodePath(".:rotation"))
    sync.replication_config = replication
    sync.set_multiplayer_authority(1)
    sync.replication_interval = 0.05
    sync.delta_interval = 0.05
    add_child(sync)

    var health_sync = MultiplayerSynchronizer.new()
    health_sync.name = "HealthSync"
    health_sync.root_path = NodePath("..")
    var health_replication = SceneReplicationConfig.new()
    health_replication.add_property(NodePath(".:health"))
    health_replication.add_property(NodePath(".:ammo"))
    health_replication.add_property(NodePath(".:reserve_ammo"))
    health_replication.add_property(NodePath(".:is_dead"))
    health_replication.add_property(NodePath(".:is_downed"))
    health_replication.add_property(NodePath(".:downed_timer"))
    health_replication.add_property(NodePath(".:team_id"))
    health_replication.add_property(NodePath(".:kills"))
    health_replication.add_property(NodePath(".:deaths"))
    health_replication.add_property(NodePath(".:current_weapon_index"))
    health_replication.add_property(NodePath(".:weapon_inventory"))
    health_replication.add_property(NodePath(".:weapon_ammo"))
    health_sync.replication_config = health_replication
    health_sync.set_multiplayer_authority(1)
    health_sync.replication_interval = 0.1
    health_sync.delta_interval = 0.1
    add_child(health_sync)

    create_gun()

    if not is_multiplayer_authority():
        return

    add_to_group("local_player")
    camera_pivot = Node3D.new()
    camera_pivot.name = "CameraPivot"
    camera_pivot.position = Vector3(0, 1.65, 0)
    camera_pivot.top_level = true
    add_child(camera_pivot)
    camera_pivot.global_position = global_position + Vector3(0, 1.65, 0)

    spring_arm = SpringArm3D.new()
    spring_arm.name = "CameraArm"
    spring_arm.spring_length = 5.5
    spring_arm.margin = 0.2
    spring_arm.collision_mask = 1
    camera_pivot.add_child(spring_arm)

    camera = Camera3D.new()
    camera.name = "ThirdPersonCamera"
    camera.fov = 75.0
    spring_arm.add_child(camera)
    camera.current = true


func refresh_gun_model():
    if gun_node != null and is_instance_valid(gun_node):
        gun_node.queue_free()
    create_gun()

func create_gun():
    gun_node = Node3D.new()
    last_model_weapon_index = current_weapon_index
    gun_node.name = "SoldierGun"
    gun_node.position = Vector3(0.43, 1.25, -0.32)
    add_child(gun_node)

    var dark = StandardMaterial3D.new()
    dark.albedo_color = Color("#20252b")
    dark.metallic = 0.65
    dark.roughness = 0.35

    var body = MeshInstance3D.new()
    var body_mesh = BoxMesh.new()
    body_mesh.size = Vector3(0.16, 0.18, 0.65) if current_weapon_index == 0 else (Vector3(0.14, 0.16, 0.48) if current_weapon_index == 1 else (Vector3(0.20, 0.16, 0.42) if current_weapon_index == 2 else Vector3(0.13, 0.17, 0.92)))
    body.mesh = body_mesh
    body.material_override = dark
    gun_node.add_child(body)

    var stock = MeshInstance3D.new()
    var stock_mesh = BoxMesh.new()
    stock_mesh.size = Vector3(0.13, 0.14, 0.28)
    stock.mesh = stock_mesh
    stock.position = Vector3(0, 0, 0.40)
    stock.material_override = dark
    gun_node.add_child(stock)

    var barrel = MeshInstance3D.new()
    var barrel_mesh = BoxMesh.new()
    barrel_mesh.size = Vector3(0.07, 0.07, 0.48)
    barrel.mesh = barrel_mesh
    barrel.position = Vector3(0, 0.015, -0.48)
    barrel.material_override = dark
    gun_node.add_child(barrel)

    var grip = MeshInstance3D.new()
    var grip_mesh = BoxMesh.new()
    grip_mesh.size = Vector3(0.10, 0.25, 0.12)
    grip.mesh = grip_mesh
    grip.position = Vector3(0, -0.19, 0.12)
    grip.material_override = dark
    gun_node.add_child(grip)

    var magazine = MeshInstance3D.new()
    var magazine_mesh = BoxMesh.new()
    magazine_mesh.size = Vector3(0.11, 0.25 if current_weapon_index != 2 else 0.19, 0.14)
    magazine.mesh = magazine_mesh
    magazine.position = Vector3(0, -0.20, -0.04)
    magazine.material_override = dark
    gun_node.add_child(magazine)

    var sight = MeshInstance3D.new()
    var sight_mesh = BoxMesh.new()
    sight_mesh.size = Vector3(0.09, 0.10, 0.12)
    sight.mesh = sight_mesh
    sight.position = Vector3(0, 0.13, -0.10)
    sight.material_override = dark
    gun_node.add_child(sight)

func _process(_delta: float):
    if gun_node != null and current_weapon_index != last_model_weapon_index:
        last_model_weapon_index = current_weapon_index
        refresh_gun_model()

func set_mobile_move(value: Vector2):
    mobile_input = value.limit_length(1.0)

func set_sprinting(value: bool):
    is_sprinting = value

func jump():
    if multiplayer.is_server():
        if is_on_floor() and not is_dead:
            velocity.y = jump_force
    elif is_multiplayer_authority():
        jump_pending = true

func rotate_camera(horizontal: float, vertical: float):
    camera_pivot.rotation.y -= horizontal * mouse_sensitivity
    camera_pivot.rotation.x -= vertical * mouse_sensitivity
    camera_pivot.rotation.x = clamp(
        camera_pivot.rotation.x,
        deg_to_rad(-55),
        deg_to_rad(45)
    )

func remove_effect(node: Node, lifetime: float):
    await get_tree().create_timer(lifetime).timeout
    if is_instance_valid(node):
        node.queue_free()

func create_tracer(start: Vector3, finish: Vector3):
    var distance = start.distance_to(finish)

    if distance < 0.05:
        return

    var tracer = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = 0.018
    mesh.bottom_radius = 0.018
    mesh.height = distance
    mesh.radial_segments = 6

    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color("#ffbd45")
    mat.emission_enabled = true
    mat.emission = Color("#ff8c20")
    mat.emission_energy_multiplier = 2.0

    tracer.mesh = mesh
    tracer.material_override = mat

    var direction = (finish - start).normalized()
    tracer.global_position = (start + finish) / 2.0
    tracer.global_basis = Basis(
        Quaternion(Vector3.UP, direction)
    )

    get_tree().current_scene.add_child(tracer)
    remove_effect(tracer, 0.45)

func create_muzzle_flash():
    if gun_node == null:
        return

    var flash = MeshInstance3D.new()
    var mesh = SphereMesh.new()
    mesh.radius = 0.10
    mesh.height = 0.20

    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color("#ffb52e")
    mat.emission_enabled = true
    mat.emission = Color("#ff6a00")
    mat.emission_energy_multiplier = 4.0

    flash.mesh = mesh
    flash.material_override = mat

    var muzzle = gun_node.to_global(
        Vector3(0, 0.015, -0.73)
    )

    get_tree().current_scene.add_child(flash)
    flash.global_position = muzzle
    remove_effect(flash, 0.20)

func get_weapon_data() -> Dictionary:
    return WEAPON_DATA[clampi(current_weapon_index, 0, WEAPON_DATA.size() - 1)]

func get_weapon_inventory_text() -> String:
    var names: Array[String] = []
    for weapon_id in weapon_inventory:
        names.append(str(WEAPON_DATA[weapon_id].name))
    return " / ".join(names)

func switch_weapon(direction: int = 1):
    if is_dead or is_downed or weapon_inventory.size() < 2 or weapon_switch_cooldown > 0.0:
        return
    if multiplayer.is_server():
        _server_switch_weapon(direction)
    else:
        request_switch_weapon.rpc_id(1, direction)

@rpc("any_peer", "call_remote", "reliable")
func request_switch_weapon(direction: int):
    if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
        return
    _server_switch_weapon(direction)

func _server_switch_weapon(direction: int):
    if weapon_inventory.size() < 2 or is_dead or is_downed or weapon_switch_cooldown > 0.0:
        return
    var current_slot := weapon_inventory.find(current_weapon_index)
    if current_slot < 0:
        current_slot = 0
    var next_slot := posmod(current_slot + (1 if direction >= 0 else -1), weapon_inventory.size())
    weapon_ammo[current_weapon_index] = ammo
    current_weapon_index = weapon_inventory[next_slot]
    var stats := get_weapon_data()
    ammo = weapon_ammo[current_weapon_index]
    shoot_cooldown = float(stats.cooldown)
    bullet_range = float(stats.range)
    weapon_switch_cooldown = 0.35
    if gun_node != null and is_instance_valid(gun_node):
        refresh_gun_model()
    print("ZORIX WEAPON SWITCHED: ", stats.name)

func add_weapon(weapon_id: int) -> bool:
    if not multiplayer.is_server() or weapon_id < 0 or weapon_id >= WEAPON_DATA.size():
        return false
    if weapon_inventory.has(weapon_id):
        return false
    weapon_inventory.append(weapon_id)
    return true

func try_revive_nearby():
    if is_dead or is_downed:
        return
    if multiplayer.is_server():
        _server_revive_nearby(get_multiplayer_authority())
    else:
        request_revive_nearby.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func request_revive_nearby():
    if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
        return
    _server_revive_nearby(get_multiplayer_authority())

func _server_revive_nearby(reviver_peer_id: int):
    if is_dead or is_downed or revive_target != null:
        return
    var closest = null
    var closest_distance := 3.2
    for candidate in get_tree().get_nodes_in_group("player"):
        if candidate == self or not candidate.is_downed or candidate.is_dead or candidate.team_id != team_id:
            continue
        var distance := global_position.distance_to(candidate.global_position)
        if distance <= closest_distance:
            closest = candidate
            closest_distance = distance
    if closest != null:
        revive_target = closest
        revive_progress = 0.0
        print("ZORIX REVIVE STARTED | target=%s | reviver=%d" % [closest.name, reviver_peer_id])

func _begin_revive(reviver_peer_id: int):
    if not multiplayer.is_server() or not is_downed or is_dead:
        return
    health = 40
    is_downed = false
    downed_timer = 0.0
    downed_by_peer_id = 0
    collision_layer = 1
    collision_mask = 1
    print("ZORIX REVIVED | player=%s | by=%d" % [name, reviver_peer_id])

func shoot():
    if shoot_timer > 0.0 or is_dead or is_downed:
        return
    if camera == null:
        return
    shoot_timer = float(get_weapon_data().cooldown)
    var direction = -camera.global_transform.basis.z
    if multiplayer.is_server():
        _server_fire(direction)
    else:
        request_shot.rpc_id(1, direction)

@rpc("any_peer", "call_remote", "reliable")
func request_shot(direction: Vector3):
    if not multiplayer.is_server():
        return
    var sender_id = multiplayer.get_remote_sender_id()
    if sender_id != get_multiplayer_authority():
        return
    _server_fire(direction)

func _server_fire(direction: Vector3):
    if not multiplayer.is_server() or is_dead or is_downed or ammo <= 0:
        return
    var now_msec = Time.get_ticks_msec()
    if last_server_shot_msec > 0 and now_msec - last_server_shot_msec < int(shoot_cooldown * 1000.0):
        return
    last_server_shot_msec = now_msec
    ammo -= 1
    weapon_ammo[current_weapon_index] = ammo
    var origin = global_position + Vector3(0, 1.5, 0)
    var target = origin + direction.normalized() * bullet_range
    var query = PhysicsRayQueryParameters3D.create(origin, target)
    query.exclude = [get_rid()]
    query.collision_mask = 1
    var hit = get_world_3d().direct_space_state.intersect_ray(query)
    if hit:
        var object = hit.collider
        if object != null and not object.has_method("take_damage") and object.get_parent() != null:
            object = object.get_parent()
        if object != null and object.has_method("take_damage"):
            object.take_damage(int(get_weapon_data().damage), get_multiplayer_authority())

func take_damage(amount: int, attacker_peer_id: int = 0):
    if not multiplayer.is_server() or is_dead:
        return
    if is_downed:
        _final_elimination(attacker_peer_id)
        return
    health = maxi(0, health - maxi(0, amount))
    if health == 0:
        if team_id >= 0 and _has_living_teammate():
            is_downed = true
            downed_timer = 20.0
            downed_by_peer_id = attacker_peer_id
            health = 1
            velocity = Vector3.ZERO
            print("ZORIX PLAYER DOWNED: ", name)
        else:
            _final_elimination(attacker_peer_id)

func _has_living_teammate() -> bool:
    for teammate in get_tree().get_nodes_in_group("player"):
        if teammate != self and teammate.team_id == team_id and not teammate.is_dead:
            return true
    return false

func _final_elimination(attacker_peer_id: int = 0):
    if attacker_peer_id <= 0:
        attacker_peer_id = downed_by_peer_id
    if is_dead:
        return
    is_dead = true
    is_downed = false
    downed_timer = 0.0
    deaths += 1
    velocity = Vector3.ZERO
    collision_layer = 0
    collision_mask = 0
    if attacker_peer_id > 0:
        var attacker = get_parent().get_node_or_null("Player_%d" % attacker_peer_id)
        if attacker != null and attacker != self:
            attacker.kills += 1
    print("ZORIX PLAYER ELIMINATED: ", name)

func heal(amount: int) -> bool:
    if not multiplayer.is_server() or is_dead or health >= 100:
        return false
    health = mini(100, health + maxi(0, amount))
    return true

func add_ammo(amount: int) -> bool:
    if not multiplayer.is_server() or reserve_ammo >= 240:
        return false
    reserve_ammo = mini(240, reserve_ammo + maxi(0, amount))
    return true

func reload_weapon():
    var magazine_size := int(get_weapon_data().mag)
    if not multiplayer.is_server() or is_dead or is_downed or ammo >= magazine_size or reserve_ammo <= 0:
        return
    var needed = magazine_size - ammo
    var loaded = mini(needed, reserve_ammo)
    ammo += loaded
    weapon_ammo[current_weapon_index] = ammo
    reserve_ammo -= loaded

@rpc("any_peer", "call_remote", "reliable")
func request_reload():
    if not multiplayer.is_server():
        return
    if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
        return
    reload_weapon()

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_movement_input(move_input: Vector2, sprinting: bool, jump_pressed: bool, camera_yaw: float):
    if not multiplayer.is_server() or is_dead:
        return
    if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
        return
    var now_msec := Time.get_ticks_msec()
    if last_input_msec > 0 and now_msec - last_input_msec < 20:
        return
    last_input_msec = now_msec
    server_move_input = move_input.limit_length(1.0)
    server_sprint = sprinting
    server_camera_yaw = wrapf(camera_yaw, -PI, PI)
    if jump_pressed and is_on_floor():
        velocity.y = jump_force

func _simulate_authoritative_movement(delta: float, input_dir: Vector2, sprinting: bool, camera_yaw: float):
    if is_dead or is_downed:
        velocity = Vector3.ZERO
        return

    if not is_on_floor():
        velocity.y -= gravity * delta
    elif velocity.y < 0.0:
        velocity.y = 0.0

    var basis := Basis(Vector3.UP, camera_yaw)
    var forward := -basis.z
    var right := basis.x
    var direction := (right * input_dir.x - forward * input_dir.y).normalized()

    if direction.length() > 0.01:
        var target_angle := atan2(-direction.x, -direction.z)
        rotation.y = lerp_angle(rotation.y, target_angle, minf(delta * 10.0, 1.0))

    var current_speed := sprint_speed if sprinting else speed
    velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
    velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
    move_and_slide()

func _physics_process(delta):
    shoot_timer = maxf(0.0, shoot_timer - delta)
    weapon_switch_cooldown = maxf(0.0, weapon_switch_cooldown - delta)
    if multiplayer.is_server() and is_downed:
        downed_timer = maxf(0.0, downed_timer - delta)
        if downed_timer <= 0.0:
            _final_elimination()
    if multiplayer.is_server() and revive_target != null:
        if not is_instance_valid(revive_target) or not revive_target.is_downed or revive_target.is_dead or is_dead or is_downed or team_id != revive_target.team_id or global_position.distance_to(revive_target.global_position) > 3.2:
            revive_target = null
            revive_progress = 0.0
        else:
            revive_progress += delta
            if revive_progress >= 4.0:
                revive_target.call("_begin_revive", get_multiplayer_authority())
                revive_target = null
                revive_progress = 0.0

    if multiplayer.is_server():
        var input_dir := server_move_input
        var sprinting := server_sprint
        var yaw := server_camera_yaw

        # The listen-server host is peer 1; dedicated servers have no local human player.
        if get_multiplayer_authority() == 1 and camera_pivot != null:
            var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
            input_dir = mobile_input if mobile_input.length() > 0.05 else keyboard
            sprinting = is_sprinting
            yaw = camera_pivot.rotation.y
            if Input.is_action_just_pressed("ui_accept") and is_on_floor():
                velocity.y = jump_force

        _simulate_authoritative_movement(delta, input_dir, sprinting, yaw)
        if get_multiplayer_authority() == 1 and camera_pivot != null:
            camera_pivot.global_position = global_position + Vector3(0, 1.65, 0)
        return

    # Clients send input only. The dedicated server owns authoritative movement and transforms.
    if is_multiplayer_authority():
        if camera_pivot != null:
            camera_pivot.global_position = global_position + Vector3(0, 1.65, 0)
        input_send_accumulator += delta
        if input_send_accumulator >= 0.05:
            input_send_accumulator = 0.0
            var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
            var input_dir := mobile_input if mobile_input.length() > 0.05 else keyboard
            submit_movement_input.rpc_id(1, input_dir, is_sprinting, jump_pending, camera_pivot.rotation.y if camera_pivot != null else rotation.y)
            jump_pending = false
