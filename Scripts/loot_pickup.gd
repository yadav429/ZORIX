extends Area3D

@export_enum("ammo", "medkit", "weapon") var pickup_kind: String = "ammo"
@export var amount: int = 30
@export var weapon_index: int = 1

func _ready():
    collision_layer = 0
    collision_mask = 1
    monitoring = true

    var shape_node = CollisionShape3D.new()
    var shape = SphereShape3D.new()
    shape.radius = 1.35
    shape_node.shape = shape
    add_child(shape_node)

    var mat := StandardMaterial3D.new()
    mat.roughness = 0.38
    if pickup_kind == "medkit":
        mat.albedo_color = Color("#35d879")
        mat.emission_enabled = true
        mat.emission = Color("#145c32")
    elif pickup_kind == "weapon":
        mat.albedo_color = Color("#a9c4d6")
        mat.metallic = 0.72
        mat.emission_enabled = true
        mat.emission = Color("#174a91")
    else:
        mat.albedo_color = Color("#e5b33b")
        mat.emission_enabled = true
        mat.emission = Color("#6d4b12")

    if pickup_kind == "weapon":
        _build_weapon_pickup(mat)
    else:
        var visual := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(0.58, 0.58, 0.58)
        visual.mesh = mesh
        visual.material_override = mat
        visual.position.y = 0.55
        add_child(visual)

    var label := Label3D.new()
    label.text = str(["VEER-47", "KALKA-7", "TRISHUL", "SHER-X", "BRAHMOS", "AGNI-X", "RUDRA-99", "GARUD-5"][clampi(weapon_index, 0, 7)]) if pickup_kind == "weapon" else pickup_kind.to_upper()
    label.position = Vector3(0, 1.25, 0)
    label.font_size = 28
    label.modulate = Color("#f2d89b")
    add_child(label)

func _build_weapon_pickup(mat: StandardMaterial3D) -> void:
    # Low-poly rifle silhouette with receiver, barrel, stock, magazine and sight.
    var root := Node3D.new()
    root.position = Vector3(0, 0.48, 0)
    root.rotation_degrees.y = 28.0
    add_child(root)

    var long_weapon := weapon_index in [3, 4, 7]
    var length := 1.25 if long_weapon else 0.92
    _add_weapon_part(root, Vector3(0, 0, 0), Vector3(0.17, 0.16, length * 0.58), mat)
    _add_weapon_part(root, Vector3(0, 0.015, -length * 0.48), Vector3(0.065, 0.065, length * 0.48), mat)
    _add_weapon_part(root, Vector3(0, 0, length * 0.43), Vector3(0.13, 0.13, length * 0.30), mat)
    _add_weapon_part(root, Vector3(0, -0.17, 0.02), Vector3(0.105, 0.25, 0.13), mat)
    _add_weapon_part(root, Vector3(0, 0.13, -0.08), Vector3(0.09, 0.09, 0.16), mat)

func _add_weapon_part(parent: Node3D, position: Vector3, size: Vector3, mat: Material) -> void:
    var part := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    part.mesh = mesh
    part.material_override = mat
    part.position = position
    parent.add_child(part)

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
