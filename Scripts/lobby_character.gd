extends Node3D
## Lightweight procedural Indian commando preview for the mobile home lobby.
## Kept separate from the networked Player scene so the lobby never starts gameplay logic.

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.82) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    return material

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, material_override: Material = null) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = at
    mesh_instance.material_override = material_override if material_override != null else _material(color)
    parent.add_child(mesh_instance)
    return mesh_instance

func _capsule(parent: Node3D, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh_instance.mesh = mesh
    mesh_instance.position = at
    mesh_instance.material_override = _material(color)
    parent.add_child(mesh_instance)
    return mesh_instance

func _ready() -> void:
    var olive := _material(Color("#45583b"))
    var dark_olive := _material(Color("#27352c"))
    var armor := _material(Color("#59634a"))
    var black := _material(Color("#171f20"))
    var skin := _material(Color("#a96f50"))
    var metal := _material(Color("#303b3c"), 0.72, 0.32)
    var gold := _material(Color("#c5a45c"), 0.45, 0.42)

    # Boots and legs
    _box(self, Vector3(0.34, 0.20, 0.48), Vector3(-0.19, 0.12, -0.03), black)
    _box(self, Vector3(0.34, 0.20, 0.48), Vector3(0.19, 0.12, -0.03), black)
    _capsule(self, 0.16, 0.78, Vector3(-0.19, 0.53, 0.0), olive)
    _capsule(self, 0.16, 0.78, Vector3(0.19, 0.53, 0.0), olive)
    _box(self, Vector3(0.43, 0.22, 0.34), Vector3(0.0, 0.98, 0.0), dark_olive)

    # Torso, tactical vest, pouches and backpack
    _capsule(self, 0.34, 0.88, Vector3(0.0, 1.48, 0.0), olive)
    _box(self, Vector3(0.66, 0.66, 0.30), Vector3(0.0, 1.48, -0.12), armor)
    _box(self, Vector3(0.58, 0.52, 0.12), Vector3(0.0, 1.48, 0.10), dark_olive)
    for x in [-0.21, 0.0, 0.21]:
        _box(self, Vector3(0.14, 0.19, 0.10), Vector3(x, 1.36, 0.18), olive)
    _box(self, Vector3(0.52, 0.64, 0.25), Vector3(0.0, 1.48, -0.31), dark_olive)
    _box(self, Vector3(0.38, 0.12, 0.08), Vector3(0.0, 1.76, -0.31), gold)

    # Arms posed in a ready-to-fight stance
    var left_arm := Node3D.new()
    left_arm.position = Vector3(-0.42, 1.72, 0.0)
    left_arm.rotation.z = deg_to_rad(-12.0)
    add_child(left_arm)
    _capsule(left_arm, 0.13, 0.62, Vector3(0.0, -0.25, 0.0), olive)
    _capsule(left_arm, 0.105, 0.22, Vector3(0.0, -0.57, 0.04), skin)
    var right_arm := Node3D.new()
    right_arm.position = Vector3(0.42, 1.72, 0.0)
    right_arm.rotation.z = deg_to_rad(18.0)
    add_child(right_arm)
    _capsule(right_arm, 0.13, 0.62, Vector3(0.0, -0.25, 0.0), olive)
    _capsule(right_arm, 0.105, 0.22, Vector3(0.0, -0.57, 0.04), skin)

    # Head, neck, helmet, visor and chin strap
    _capsule(self, 0.12, 0.22, Vector3(0.0, 1.99, 0.0), skin)
    _capsule(self, 0.19, 0.34, Vector3(0.0, 2.20, 0.0), skin)
    _box(self, Vector3(0.43, 0.20, 0.43), Vector3(0.0, 2.39, 0.0), dark_olive)
    _box(self, Vector3(0.48, 0.055, 0.48), Vector3(0.0, 2.31, 0.0), olive)
    _box(self, Vector3(0.28, 0.055, 0.08), Vector3(0.0, 2.21, 0.19), black)
    _box(self, Vector3(0.22, 0.045, 0.025), Vector3(0.0, 2.22, 0.235), _material(Color("#91b8b4"), 0.2, 0.25))

    # Small Indian tricolour shoulder patch (decorative uniform detail)
    _box(self, Vector3(0.13, 0.045, 0.012), Vector3(-0.47, 1.72, 0.105), _material(Color("#f28c28")))
    _box(self, Vector3(0.13, 0.045, 0.012), Vector3(-0.47, 1.675, 0.105), _material(Color("#f3f0df")))
    _box(self, Vector3(0.13, 0.045, 0.012), Vector3(-0.47, 1.63, 0.105), _material(Color("#248b50")))

    # Compact rifle held across the front
    var rifle := Node3D.new()
    rifle.position = Vector3(0.22, 1.52, 0.29)
    rifle.rotation.z = deg_to_rad(-8.0)
    add_child(rifle)
    _box(rifle, Vector3(0.12, 0.12, 0.92), Vector3(0.0, 0.0, 0.0), metal)
    _box(rifle, Vector3(0.09, 0.24, 0.20), Vector3(0.0, -0.16, 0.12), black)
    _box(rifle, Vector3(0.07, 0.07, 0.34), Vector3(0.0, 0.0, -0.58), black)
    _box(rifle, Vector3(0.05, 0.10, 0.16), Vector3(0.0, 0.12, 0.08), gold)

    # Tiny metallic chest insignia
    _box(self, Vector3(0.11, 0.11, 0.025), Vector3(0.19, 1.69, 0.18), gold)

func _process(delta: float) -> void:
    rotation.y += delta * 0.22
