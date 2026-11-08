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

var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var gun_node: Node3D

func _ready():
    add_to_group("player")
    floor_snap_length = 0.3

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

    create_gun()

func create_gun():
    gun_node = Node3D.new()
    gun_node.name = "SoldierGun"
    gun_node.position = Vector3(0.43, 1.25, -0.32)
    add_child(gun_node)

    var dark = StandardMaterial3D.new()
    dark.albedo_color = Color("#20252b")
    dark.metallic = 0.65
    dark.roughness = 0.35

    var body = MeshInstance3D.new()
    var body_mesh = BoxMesh.new()
    body_mesh.size = Vector3(0.16, 0.18, 0.65)
    body.mesh = body_mesh
    body.material_override = dark
    gun_node.add_child(body)

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

func set_mobile_move(value: Vector2):
    print("ZORIX PLAYER RECEIVED MOVE: ", value)
    mobile_input = value.limit_length(1.0)

func set_sprinting(value: bool):
    is_sprinting = value

func jump():
    if is_on_floor():
        velocity.y = jump_force

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

func shoot():
    print("ZORIX SHOOT EXECUTED")
    if shoot_timer > 0.0:
        return

    if camera == null:
        print("ZORIX ERROR: CAMERA IS NULL")
        return

    shoot_timer = shoot_cooldown

    var origin = camera.global_position
    var direction = -camera.global_transform.basis.z
    var target = origin + direction * bullet_range

    var query = PhysicsRayQueryParameters3D.create(
        origin, target
    )
    query.exclude = [get_rid()]
    query.collision_mask = 1

    var hit = get_world_3d().direct_space_state.intersect_ray(query)

    var end_point = target

    if hit:
        end_point = hit.position
        var object = hit.collider

        print("ZORIX HIT: ", object.name)

        if object.has_method("take_damage"):
            object.take_damage(25)
    else:
        print("ZORIX BULLET FIRED")

    var muzzle = gun_node.to_global(
        Vector3(0, 0.015, -0.73)
    )

    create_tracer(muzzle, end_point)
    create_muzzle_flash()

func _physics_process(delta):

    shoot_timer = maxf(0.0, shoot_timer - delta)
    camera_pivot.global_position = global_position + Vector3(0, 1.65, 0)

    if not is_on_floor():
        velocity.y -= gravity * delta
    elif velocity.y < 0:
        velocity.y = 0

    var keyboard = Input.get_vector(
        "ui_left", "ui_right", "ui_up", "ui_down"
    )

    var input_dir = mobile_input if mobile_input.length() > 0.05 else keyboard

    var basis = camera_pivot.global_transform.basis
    var forward = -basis.z
    var right = basis.x

    forward.y = 0
    right.y = 0

    forward = forward.normalized()
    right = right.normalized()

    var direction = (
        right * input_dir.x - forward * input_dir.y
    ).normalized()

    if direction.length() > 0.01:
        var target_angle = atan2(-direction.x, -direction.z)
        rotation.y = lerp_angle(
            rotation.y,
            target_angle,
            min(delta * 10.0, 1.0)
        )

    var current_speed = sprint_speed if is_sprinting else speed

    velocity.x = move_toward(
        velocity.x,
        direction.x * current_speed,
        acceleration * delta
    )

    velocity.z = move_toward(
        velocity.z,
        direction.z * current_speed,
        acceleration * delta
    )

    if Input.is_action_just_pressed("ui_accept"):
        jump()

    move_and_slide()
