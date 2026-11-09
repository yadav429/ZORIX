extends Node3D

var player: CharacterBody3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D

var walk_phase := 0.0
var walk_amount := 0.0
var base_y := 0.0

func make_material(color: Color) -> StandardMaterial3D:
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.85
    return mat

func make_box(parent: Node3D, box_size: Vector3, pos: Vector3, color: Color):
    var mesh_instance = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = box_size
    mesh_instance.mesh = mesh
    mesh_instance.position = pos
    mesh_instance.material_override = make_material(color)
    parent.add_child(mesh_instance)
    return mesh_instance

func _ready():
    player = get_parent() as CharacterBody3D
    if player == null and get_parent() != null:
        player = get_parent().get_parent() as CharacterBody3D
    base_y = position.y

    var uniform = Color("#344b3b")
    var dark = Color("#202b27")
    var skin = Color("#b9825e")
    var helmet_color = Color("#263d30")
    var vest_color = Color("#586447")

    make_box(self, Vector3(0.65, 0.78, 0.34), Vector3(0, 1.25, 0), uniform)
    make_box(self, Vector3(0.69, 0.48, 0.38), Vector3(0, 1.28, -0.025), vest_color)
    make_box(self, Vector3(0.42, 0.62, 0.22), Vector3(0, 1.30, 0.27), dark)
    make_box(self, Vector3(0.34, 0.38, 0.32), Vector3(0, 1.86, 0), skin)
    make_box(self, Vector3(0.43, 0.22, 0.40), Vector3(0, 2.08, 0), helmet_color)

    left_arm = Node3D.new()
    left_arm.position = Vector3(-0.43, 1.58, 0)
    add_child(left_arm)
    make_box(left_arm, Vector3(0.25, 0.62, 0.27), Vector3(0, -0.29, 0), uniform)
    make_box(left_arm, Vector3(0.23, 0.18, 0.25), Vector3(0, -0.66, -0.02), skin)

    right_arm = Node3D.new()
    right_arm.position = Vector3(0.43, 1.58, 0)
    add_child(right_arm)
    make_box(right_arm, Vector3(0.25, 0.62, 0.27), Vector3(0, -0.29, 0), uniform)
    make_box(right_arm, Vector3(0.23, 0.18, 0.25), Vector3(0, -0.66, -0.02), skin)

    left_leg = Node3D.new()
    left_leg.position = Vector3(-0.19, 0.86, 0)
    add_child(left_leg)
    make_box(left_leg, Vector3(0.29, 0.68, 0.31), Vector3(0, -0.34, 0), uniform)
    make_box(left_leg, Vector3(0.31, 0.20, 0.43), Vector3(0, -0.72, -0.07), dark)

    right_leg = Node3D.new()
    right_leg.position = Vector3(0.19, 0.86, 0)
    add_child(right_leg)
    make_box(right_leg, Vector3(0.29, 0.68, 0.31), Vector3(0, -0.34, 0), uniform)
    make_box(right_leg, Vector3(0.31, 0.20, 0.43), Vector3(0, -0.72, -0.07), dark)

func _process(delta):
    if player == null or not is_instance_valid(player):
        return

    var horizontal_speed = Vector2(player.velocity.x, player.velocity.z).length()
    var target_amount = clamp(horizontal_speed / 5.0, 0.0, 1.0)
    walk_amount = move_toward(walk_amount, target_amount, delta * 5.0)

    if walk_amount > 0.01:
        walk_phase += delta * 11.0

    var swing = sin(walk_phase) * deg_to_rad(32.0) * walk_amount
    left_leg.rotation.x = swing
    right_leg.rotation.x = -swing
    left_arm.rotation.x = -swing * 0.75
    right_arm.rotation.x = swing * 0.75
    position.y = base_y + abs(sin(walk_phase * 2.0)) * 0.045 * walk_amount
