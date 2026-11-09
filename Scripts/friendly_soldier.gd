extends CharacterBody3D

const SOLDIER_VISUAL = preload("res://Scripts/player_visual.gd")

@export var move_speed: float = 4.2
@export var follow_offset: Vector3 = Vector3(-2.4, 0.0, 3.0)
@export var fire_range: float = 22.0
@export var fire_interval: float = 1.4

var leader: Node3D
var fire_timer := 0.0

func _ready():
    add_to_group("friendly_squad")
    collision_layer = 2
    collision_mask = 1
    floor_snap_length = 0.25

    var shape = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    shape.shape = capsule
    shape.position.y = 0.9
    add_child(shape)

    var visual = Node3D.new()
    visual.name = "SoldierVisual"
    visual.set_script(SOLDIER_VISUAL)
    add_child(visual)

    leader = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
    fire_timer = maxf(0.0, fire_timer - delta)

    if leader == null or not is_instance_valid(leader):
        leader = get_tree().get_first_node_in_group("player")
        return

    var enemies = get_tree().get_nodes_in_group("enemies")
    var nearest: Node3D = null
    var nearest_distance := fire_range + 1.0

    for candidate in enemies:
        if not is_instance_valid(candidate):
            continue
        var distance = global_position.distance_to(candidate.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = candidate

    if nearest != null and nearest_distance <= fire_range:
        if fire_timer <= 0.0 and nearest.has_method("take_damage"):
            nearest.take_damage(10)
            fire_timer = fire_interval

    var desired_position = leader.global_transform * follow_offset
    var offset = desired_position - global_position
    offset.y = 0.0

    if offset.length() > 2.0:
        var direction = offset.normalized()
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
        rotation.y = lerp_angle(
            rotation.y, atan2(-direction.x, -direction.z),
            minf(delta * 7.0, 1.0)
        )
    else:
        velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 3.0)
        velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 3.0)

    if not is_on_floor():
        velocity.y -= 20.0 * delta
    else:
        velocity.y = 0.0

    move_and_slide()
