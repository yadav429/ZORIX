
extends Node3D

const PLAYER = preload("res://Scenes/Player.tscn")
const MOBILE_UI = preload("res://Scripts/mobile_ui.gd")
const ENEMY = preload("res://Scripts/enemy.gd")

var rng = RandomNumberGenerator.new()

func material(color: Color, metallic := 0.0, rough := 0.8) -> StandardMaterial3D:
    var m = StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = rough
    return m

func add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material):
    var mesh = BoxMesh.new()
    mesh.size = size
    var obj = MeshInstance3D.new()
    obj.mesh = mesh
    obj.material_override = mat
    obj.position = pos
    parent.add_child(obj)
    return obj

func add_tree(x: float, z: float, wood: Material, leaves: Material):
    var trunk_mesh = CylinderMesh.new()
    trunk_mesh.top_radius = 0.15
    trunk_mesh.bottom_radius = 0.25
    trunk_mesh.height = 2.4

    var trunk = MeshInstance3D.new()
    trunk.mesh = trunk_mesh
    trunk.material_override = wood
    trunk.position = Vector3(x, 1.2, z)
    add_child(trunk)

    var crown_mesh = SphereMesh.new()
    var crown = MeshInstance3D.new()
    crown.mesh = crown_mesh
    crown.material_override = leaves
    crown.scale = Vector3(1.2, 1.5, 1.2)
    crown.position = Vector3(x, 2.8, z)
    add_child(crown)

func add_mountain(x: float, z: float, height: float, mat: Material):
    var mesh = CylinderMesh.new()
    mesh.top_radius = 0.0
    mesh.bottom_radius = height * 0.65
    mesh.height = height
    mesh.radial_segments = 7

    var obj = MeshInstance3D.new()
    obj.mesh = mesh
    obj.material_override = mat
    obj.position = Vector3(x, height / 2.0, z)
    add_child(obj)

func add_building(x: float, z: float, h: float, concrete: Material, glass: Material):
    add_box(self, Vector3(x, h / 2.0, z),
        Vector3(7, h, 7), concrete)

    for y in range(2, int(h), 3):
        add_box(self, Vector3(x, float(y), z - 3.56),
            Vector3(5.0, 1.0, 0.12), glass)

func _ready():
    rng.randomize()

    var grass = material(Color(0.16, 0.34, 0.13))
    var dark_grass = material(Color(0.07, 0.22, 0.09))
    var ocean = material(Color(0.005, 0.12, 0.30), 0.5, 0.25)
    var road = material(Color(0.09, 0.10, 0.11), 0.1, 0.9)
    var concrete = material(Color(0.38, 0.43, 0.48), 0.2)
    var glass = material(Color(0.03, 0.32, 0.48), 0.65, 0.2)
    var wood = material(Color(0.22, 0.11, 0.05))
    var leaves = material(Color(0.04, 0.25, 0.08))
    var sand = material(Color(0.68, 0.49, 0.25))
    var snow = material(Color(0.88, 0.92, 0.96))
    var mountain = material(Color(0.25, 0.30, 0.34))
    var military = material(Color(0.12, 0.20, 0.10))

    # OCEAN
    add_box(self, Vector3(0, -2.0, 0),
        Vector3(420, 1, 420), ocean)

    # INDIA SHAPED MAP
    var india = CSGPolygon3D.new()
    india.name = "IndiaBattlefield"

    india.polygon = PackedVector2Array([
        Vector2(-14, 52),
        Vector2(-5, 58),
        Vector2(8, 53),
        Vector2(18, 44),
        Vector2(26, 34),
        Vector2(34, 24),
        Vector2(43, 17),
        Vector2(50, 14),
        Vector2(53, 7),
        Vector2(46, 3),
        Vector2(40, 8),
        Vector2(34, 7),
        Vector2(31, -2),
        Vector2(25, -12),
        Vector2(20, -24),
        Vector2(14, -37),
        Vector2(8, -51),
        Vector2(1, -66),
        Vector2(-6, -53),
        Vector2(-12, -40),
        Vector2(-19, -27),
        Vector2(-25, -14),
        Vector2(-30, 0),
        Vector2(-31, 14),
        Vector2(-25, 26),
        Vector2(-20, 39),
        Vector2(-14, 52)
    ])

    india.depth = 1.0
    india.mode = CSGPolygon3D.MODE_DEPTH
    india.rotation_degrees.x = 90
    india.position = Vector3(0, -0.55, 0)
    india.material = grass
    india.use_collision = true
    add_child(india)

    # ROADS
    add_box(self, Vector3(0, 0.03, 5),
        Vector3(9, 0.08, 90), road)
    add_box(self, Vector3(5, 0.04, -5),
        Vector3(70, 0.08, 8), road)
    add_box(self, Vector3(15, 0.05, -25),
        Vector3(7, 0.08, 55), road)

    # DELHI STYLE CITY
    for x in range(12, 37, 9):
        for z in range(-15, 16, 10):
            var h = rng.randf_range(9.0, 23.0)
            add_building(float(x), float(z), h, concrete, glass)

    # RAJASTHAN DESERT
    add_box(self, Vector3(-19, 0.025, -8),
        Vector3(17, 0.04, 24), sand)

    # SMALL DESERT STRUCTURES
    for i in range(5):
        var x = -27.0 + float(i) * 4.0
        add_box(self, Vector3(x, 1.5, -8),
            Vector3(3, 3, 3), sand)

    # HIMALAYA MOUNTAINS
    for i in range(9):
        var x = -17.0 + float(i) * 4.0
        var h = rng.randf_range(12.0, 24.0)
        add_mountain(x, 43.0, h, mountain)
        add_mountain(x, 43.0, h * 0.45, snow)

    # FOREST AREA
    for i in range(45):
        var x = rng.randf_range(-24.0, 25.0)
        var z = rng.randf_range(-45.0, 35.0)

        if abs(x) > 12.0 and abs(z) > 8.0:
            add_tree(x, z, wood, leaves)

    # MILITARY BASE
    add_box(self, Vector3(-25, 2, 12),
        Vector3(15, 4, 17), military)
    add_box(self, Vector3(-25, 4.1, 12),
        Vector3(9, 0.2, 10), concrete)

    # MILITARY WATCH TOWER
    add_box(self, Vector3(-34, 4, 12),
        Vector3(2, 8, 2), concrete)
    add_box(self, Vector3(-34, 8, 12),
        Vector3(5, 0.5, 5), military)

    # EXTRA ROCKS
    for i in range(18):
        var rock = SphereMesh.new()
        var obj = MeshInstance3D.new()
        obj.mesh = rock
        obj.material_override = mountain
        obj.scale = Vector3(
            rng.randf_range(0.5, 2.0),
            rng.randf_range(0.4, 1.2),
            rng.randf_range(0.5, 2.0)
        )
        obj.position = Vector3(
            rng.randf_range(-25, 25),
            0.4,
            rng.randf_range(-55, 55)
        )
        add_child(obj)

    # SUN AND SHADOWS
    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -35, 0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 100
    add_child(sun)

    # HIGH QUALITY SKY
    var sky = Sky.new()
    var sky_mat = ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color(0.08, 0.30, 0.62)
    sky_mat.sky_horizon_color = Color(0.55, 0.72, 0.90)
    sky_mat.ground_bottom_color = Color(0.08, 0.12, 0.10)
    sky_mat.ground_horizon_color = Color(0.45, 0.55, 0.45)
    sky.sky_material = sky_mat

    var env = Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.glow_enabled = true
    env.glow_intensity = 0.35

    var world_env = WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)

    # PLAYER
    var player = PLAYER.instantiate()
    player.position = Vector3(0, 0, 25)
    add_child(player)
    # ENEMY SOLDIERS
    for enemy_pos in [Vector3(0, 0, 8), Vector3(-5, 0, 5), Vector3(5, 0, 5)]:
        var enemy = ENEMY.new()
        enemy.position = enemy_pos
        add_child(enemy)

    # MOBILE CONTROLS
    var ui = CanvasLayer.new()
    ui.set_script(MOBILE_UI)
    add_child(ui)

