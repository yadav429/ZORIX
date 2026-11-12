extends Area3D

@export_enum("ammo", "medkit", "weapon") var pickup_kind: String = "ammo"
@export var amount: int = 30
@export var weapon_index: int = 1

func _ready():
    add_to_group("loot_pickups")
    collision_layer = 0
    collision_mask = 1
    monitoring = true

    var shape_node = CollisionShape3D.new()
    var shape = SphereShape3D.new()
    shape.radius = 1.35
    shape_node.shape = shape
    add_child(shape_node)

    var visual = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = Vector3(0.65, 0.65, 0.65)
    visual.mesh = mesh
    var mat = StandardMaterial3D.new()
    if pickup_kind == "medkit":
        mat.albedo_color = Color("#35d879")
        mat.emission_enabled = true
        mat.emission = Color("#145c32")
    elif pickup_kind == "weapon":
        mat.albedo_color = Color("#5aa9ff")
        mat.emission_enabled = true
        mat.emission = Color("#174a91")
    else:
        mat.albedo_color = Color("#e5b33b")
        mat.emission_enabled = true
        mat.emission = Color("#6d4b12")
    visual.material_override = mat
    visual.position.y = 0.55
    add_child(visual)

    var label := Label3D.new()
    label.text = "WEAPON" if pickup_kind == "weapon" else ("MEDKIT" if pickup_kind == "medkit" else "AMMO")
    label.position.y = 1.25
    label.font_size = 28
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)

    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
    if not multiplayer.is_server() or not body.is_in_group("player"):
        return
    if body.is_dead:
        return

    var collected := false
    if pickup_kind == "medkit" and body.has_method("heal"):
        collected = body.heal(amount)
    elif pickup_kind == "ammo" and body.has_method("add_ammo"):
        collected = body.add_ammo(amount)
    elif pickup_kind == "weapon" and body.has_method("add_weapon"):
        collected = body.add_weapon(weapon_index)

    if collected:
        queue_free()
