
from pathlib import Path

root = Path.cwd()

files = {
"Scripts/player_visual.gd": r'''
extends Node3D

func part(mesh: Mesh, material: Material, pos: Vector3, size: Vector3):
    var obj = MeshInstance3D.new()
    obj.mesh = mesh
    obj.material_override = material
    obj.position = pos
    obj.scale = size
    add_child(obj)

func box(mat, pos, size):
    var m = BoxMesh.new()
    part(m, mat, pos, size)

func capsule(mat, pos, radius, height):
    var m = CapsuleMesh.new()
    m.radius = radius
    m.height = height
    part(m, mat, pos, Vector3.ONE)

func _ready():
    var armor = StandardMaterial3D.new()
    armor.albedo_color = Color(0.055, 0.09, 0.16)
    armor.metallic = 0.8
    armor.roughness = 0.25

    var blue = StandardMaterial3D.new()
    blue.albedo_color = Color(0.02, 0.65, 1.0)
    blue.emission_enabled = true
    blue.emission = Color(0.0, 0.35, 1.0)
    blue.metallic = 0.5

    var visor = StandardMaterial3D.new()
    visor.albedo_color = Color(0.0, 0.8, 1.0)
    visor.emission_enabled = true
    visor.emission = Color(0.0, 0.5, 1.0)

    var dark = StandardMaterial3D.new()
    dark.albedo_color = Color(0.015, 0.025, 0.045)
    dark.metallic = 0.5

    # Body and chest armor
    box(armor, Vector3(0, 1.05, 0), Vector3(0.85, 0.85, 0.42))
    box(blue, Vector3(0, 1.25, -0.22), Vector3(0.48, 0.10, 0.035))
    box(dark, Vector3(0, 0.55, 0), Vector3(0.62, 0.30, 0.34))

    # Helmet
    var head = SphereMesh.new()
    part(head, armor, Vector3(0, 1.85, 0), Vector3(0.48, 0.52, 0.46))
    box(visor, Vector3(0, 1.91, -0.22), Vector3(0.34, 0.12, 0.055))
    box(blue, Vector3(0, 2.12, 0), Vector3(0.30, 0.045, 0.30))

    # Arms
    for side in [-1.0, 1.0]:
        box(armor, Vector3(side * 0.58, 1.12, 0), Vector3(0.27, 0.58, 0.30))
        box(blue, Vector3(side * 0.58, 1.30, -0.17), Vector3(0.18, 0.08, 0.04))
        box(dark, Vector3(side * 0.58, 0.76, 0), Vector3(0.22, 0.30, 0.24))
        box(armor, Vector3(side * 0.23, 0.22, 0), Vector3(0.28, 0.62, 0.32))
        box(dark, Vector3(side * 0.23, -0.13, -0.04), Vector3(0.32, 0.20, 0.46))
        box(blue, Vector3(side * 0.23, 0.38, -0.18), Vector3(0.20, 0.07, 0.035))

    # Back energy pack
    box(dark, Vector3(0, 1.12, 0.28), Vector3(0.48, 0.65, 0.20))
    box(blue, Vector3(0, 1.15, 0.40), Vector3(0.22, 0.38, 0.04))
''',

"Scripts/world.gd": r'''
extends Node3D

const PLAYER = preload("res://Scenes/Player.tscn")
const MOBILE_UI = preload("res://Scripts/mobile_ui.gd")

func material(color: Color, metallic := 0.0, emission := false) -> StandardMaterial3D:
    var m = StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    if emission:
        m.emission_enabled = true
        m.emission = color
    return m

func add_box(parent, pos, size, mat):
    var mesh = BoxMesh.new()
    mesh.size = size
    var obj = MeshInstance3D.new()
    obj.mesh = mesh
    obj.material_override = mat
    obj.position = pos
    parent.add_child(obj)

func add_tree(x, z, wood, leaves):
    var trunk = MeshInstance3D.new()
    var cylinder = CylinderMesh.new()
    cylinder.top_radius = 0.18
    cylinder.bottom_radius = 0.28
    cylinder.height = 2.5
    trunk.mesh = cylinder
    trunk.material_override = wood
    trunk.position = Vector3(x, 1.25, z)
    add_child(trunk)

    var crown = MeshInstance3D.new()
    var cone = SphereMesh.new()
    crown.mesh = cone
    crown.material_override = leaves
    crown.scale = Vector3(1.5, 2.0, 1.5)
    crown.position = Vector3(x, 3.1, z)
    add_child(crown)

func _ready():
    var grass = material(Color(0.20, 0.39, 0.19))
    var ocean = material(Color(0.015, 0.16, 0.32), 0.45)
    var road = material(Color(0.10, 0.12, 0.15))
    var concrete = material(Color(0.35, 0.40, 0.46), 0.35)
    var glass = material(Color(0.02, 0.35, 0.55), 0.7, true)
    var wood = material(Color(0.22, 0.12, 0.07))
    var leaves = material(Color(0.07, 0.30, 0.12))
    var neon = material(Color(0.0, 0.55, 1.0), 0.4, true)

    # Ocean
    add_box(self, Vector3(0, -1.7, 0), Vector3(420, 1, 420), ocean)

    # Island
    add_box(self, Vector3(0, -0.55, 0), Vector3(180, 1, 180), grass)

    # Roads
    add_box(self, Vector3(0, 0.02, 0), Vector3(12, 0.08, 150), road)
    add_box(self, Vector3(0, 0.03, 0), Vector3(150, 0.08, 12), road)

    # City buildings
    for x in range(-55, 56, 18):
        for z in range(-55, 56, 18):
            if abs(x) < 16 or abs(z) < 16:
                continue
            var h = 8.0 + float(abs(x * 3 + z * 7) % 16)
            add_box(self, Vector3(x, h / 2.0, z),
                Vector3(10, h, 10), concrete)
            add_box(self, Vector3(x, h * 0.65, z - 5.06),
                Vector3(7, 2, 0.12), glass)
            add_box(self, Vector3(x, h + 0.12, z),
                Vector3(2, 0.25, 2), neon)

    # Trees around island outskirts
    for i in range(22):
        var x = float(i * 7 - 75)
        add_tree(x, -72, wood, leaves)
        add_tree(x, 72, wood, leaves)
        add_tree(-72, x, wood, leaves)
        add_tree(72, x, wood, leaves)

    # Military base
    add_box(self, Vector3(-48, 2, 0), Vector3(20, 4, 24), concrete)
    add_box(self, Vector3(-48, 4.1, 0), Vector3(8, 0.2, 12), neon)

    # Light
    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.shadow_enabled = true
    add_child(sun)

    var environment = WorldEnvironment.new()
    var env = Environment.new()
    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.35, 0.48, 0.65)
    env.ambient_light_energy = 0.8
    environment.environment = env
    add_child(environment)

    # Player
    var player = PLAYER.instantiate()
    player.position = Vector3(0, 0, 25)
    add_child(player)

    # Touch controls
    var ui = CanvasLayer.new()
    ui.set_script(MOBILE_UI)
    add_child(ui)
''',

"Scenes/Player.tscn": '''[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://Scripts/player.gd" id="1"]
[ext_resource type="Script" path="res://Scripts/player_visual.gd" id="2"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape"]
radius = 0.4
height = 2.1

[node name="Player" type="CharacterBody3D"]
script = ExtResource("1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
position = Vector3(0, 1, 0)
shape = SubResource("CapsuleShape")

[node name="Visual" type="Node3D" parent="."]
script = ExtResource("2")

[node name="SpringArm3D" type="SpringArm3D" parent="."]
position = Vector3(0, 1.7, 0)
spring_length = 6.0

[node name="Camera3D" type="Camera3D" parent="SpringArm3D"]
current = true
''',

"Scenes/Main.tscn": '''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://Scripts/world.gd" id="1"]

[node name="Main" type="Node3D"]
script = ExtResource("1")
'''
}

for name, content in files.items():
    path = root / name
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        backup = path.with_suffix(path.suffix + ".before_graphics")
        if not backup.exists():
            backup.write_text(path.read_text(encoding="utf-8"), encoding="utf-8")
    path.write_text(content.strip() + "\n", encoding="utf-8")
    print("Created:", name)

p = root / "project.godot"
s = p.read_text(encoding="utf-8")
if 'run/main_scene=' in s:
    import re
    s = re.sub(r'run/main_scene=.*', 'run/main_scene="res://Scenes/Main.tscn"', s)
else:
    s += '\nrun/main_scene="res://Scenes/Main.tscn"\n'
p.write_text(s, encoding="utf-8")

print("\nZORIX FUTURE WAR GRAPHICS CREATED")

