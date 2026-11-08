extends CharacterBody3D

@export var move_speed: float = 2.0
var health: int = 100
var target: Node3D

func _ready():
    add_to_group("enemies")
    collision_layer = 1
    collision_mask = 1

    var shape = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = 0.42
    capsule.height = 1.8
    shape.shape = capsule
    shape.position.y = 0.9
    add_child(shape)

    var body = MeshInstance3D.new()
    var mesh = CapsuleMesh.new()
    mesh.radius = 0.42
    mesh.height = 1.8
    body.mesh = mesh

    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color("#8b2525")
    body.material_override = mat
    body.position.y = 0.9
    add_child(body)

    target = get_tree().get_first_node_in_group("player")
    print("ZORIX ENEMY SPAWNED: 100 HP")

func take_damage(amount: int):
    health = max(0, health - amount)
    print("ENEMY HP: ", health)

    if health <= 0:
        print("ZORIX ENEMY ELIMINATED")
        queue_free()

func _physics_process(delta):
    if target == null or not is_instance_valid(target):
        target = get_tree().get_first_node_in_group("player")
        return

    var direction = target.global_position - global_position
    direction.y = 0

    if direction.length() > 1.8:
        direction = direction.normalized()
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
    else:
        velocity.x = 0
        velocity.z = 0

    if not is_on_floor():
        velocity.y -= 20.0 * delta
    else:
        velocity.y = 0

    move_and_slide()
