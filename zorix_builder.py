from pathlib import Path

root = Path.cwd()
for folder in ["Scenes", "Scripts", "Assets"]:
    (root / folder).mkdir(exist_ok=True)

files = {}

files["Scripts/player.gd"] = r'''
extends CharacterBody3D

@export var speed = 6.0
@export var jump_force = 5.0
@export var gravity = 15.0

func _physics_process(delta):
    if not is_on_floor():
        velocity.y -= gravity * delta

    var input_dir = Input.get_vector(
        "ui_left", "ui_right", "ui_up", "ui_down"
    )

    var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

    velocity.x = direction.x * speed
    velocity.z = direction.z * speed

    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = jump_force

    move_and_slide()
'''

files["Scripts/mobile_ui.gd"] = r'''
extends CanvasLayer

var buttons = {}

func _ready():
    var ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(ui)

    var names = ["LEFT", "RIGHT", "FORWARD", "BACK", "JUMP"]
    var actions = ["ui_left", "ui_right", "ui_up", "ui_down", "ui_accept"]

    for i in range(names.size()):
        var b = Button.new()
        b.text = names[i]
        b.custom_minimum_size = Vector2(76, 68)
        ui.add_child(b)
        buttons[names[i]] = b

        var action = actions[i]
        b.button_down.connect(func(): Input.action_press(action))
        b.button_up.connect(func(): Input.action_release(action))
        b.mouse_exited.connect(func():
            if not b.button_pressed:
                Input.action_release(action)
        )

    _layout(ui)

func _layout(ui):
    var s = get_viewport().get_visible_rect().size
    buttons["LEFT"].position = Vector2(20, s.y - 165)
    buttons["RIGHT"].position = Vector2(180, s.y - 165)
    buttons["FORWARD"].position = Vector2(100, s.y - 240)
    buttons["BACK"].position = Vector2(100, s.y - 90)
    buttons["JUMP"].position = Vector2(s.x - 115, s.y - 150)
'''

files["Scenes/Player.tscn"] = '''[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://Scripts/player.gd" id="1"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape"]
radius = 0.4
height = 1.8

[sub_resource type="CapsuleMesh" id="CapsuleMesh"]
radius = 0.4
height = 1.8

[node name="Player" type="CharacterBody3D"]
script = ExtResource("1")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
position = Vector3(0, 0.9, 0)
shape = SubResource("CapsuleShape")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.9, 0)
mesh = SubResource("CapsuleMesh")

[node name="SpringArm3D" type="SpringArm3D" parent="."]
position = Vector3(0, 1.5, 0)
rotation = Vector3(-0.18, 0, 0)
spring_length = 5.0

[node name="Camera3D" type="Camera3D" parent="SpringArm3D"]
current = true
'''

files["Scenes/Main.tscn"] = '''[gd_scene load_steps=7 format=3]

[ext_resource type="PackedScene" path="res://Scenes/Player.tscn" id="1"]
[ext_resource type="Script" path="res://Scripts/mobile_ui.gd" id="2"]

[sub_resource type="BoxShape3D" id="GroundShape"]
size = Vector3(60, 1, 60)

[sub_resource type="BoxMesh" id="GroundMesh"]
size = Vector3(60, 1, 60)

[sub_resource type="Environment" id="Environment"]
background_mode = 1
background_color = Color(0.35, 0.55, 0.8, 1)
ambient_light_source = 3
ambient_light_color = Color(0.7, 0.75, 0.85, 1)
ambient_light_energy = 0.7

[node name="Main" type="Node3D"]

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
rotation = Vector3(-0.8, -0.5, 0)
shadow_enabled = true

[node name="Ground" type="StaticBody3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="Ground"]
position = Vector3(0, -0.5, 0)
shape = SubResource("GroundShape")

[node name="MeshInstance3D" type="MeshInstance3D" parent="Ground"]
position = Vector3(0, -0.5, 0)
mesh = SubResource("GroundMesh")

[node name="Player" parent="." instance=ExtResource("1")]
position = Vector3(0, 0, 0)

[node name="MobileUI" type="CanvasLayer" parent="."]
script = ExtResource("2")
'''

for name, content in files.items():
    path = root / name
    if path.exists():
        print("Already exists, keeping:", name)
        continue
    path.write_text(content.strip() + "\n", encoding="utf-8")
    print("Created:", name)

config = root / "project.godot"
text = config.read_text(encoding="utf-8")

if 'run/main_scene=' not in text:
    text += '\n[application]\nrun/main_scene="res://Scenes/Main.tscn"\n'
elif 'run/main_scene=' not in text:
    text += '\nrun/main_scene="res://Scenes/Main.tscn"\n'

config.write_text(text, encoding="utf-8")

print("\nZORIX BUILDER FINISHED")
print("Main scene: res://Scenes/Main.tscn")
