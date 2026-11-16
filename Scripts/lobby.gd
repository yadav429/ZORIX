extends Control

const MATCH_SCENE := "res://Scenes/Main.tscn"
const PLAYER_ACCOUNT := preload("res://Scripts/player_account.gd")
const SETTINGS_PATH := "user://zorix_settings.cfg"
const DEFAULT_PORT := 24560
const MAX_PLAYERS := 50

var content: VBoxContainer
var info_label: Label
var graphics_picker: OptionButton
var fps_picker: OptionButton
var address_input: LineEdit
var mode_picker: OptionButton
var graphics_quality := "balanced"
var fps_limit := 60
var selected_mode := "Squad"
var selected_team_size := 4
var selected_game_mode := "battle_royale"
var player_account: Node

func _ready():
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

    if _is_dedicated_server():
        _start_dedicated_server()
        return

    _load_settings()
    _apply_frame_limit()
    _build_lobby()

func _is_dedicated_server() -> bool:
    return OS.has_feature("dedicated_server") or OS.get_cmdline_user_args().has("--server")

func _server_argument(prefix: String, fallback: String) -> String:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)
    return fallback

func _start_dedicated_server():
    var port := clampi(_server_argument("--port=", "24560").to_int(), 1, 65535)
    var max_players := clampi(_server_argument("--max-players=", "50").to_int(), 2, 50)
    var mode := _server_argument("--mode=", "battle_royale")
    if mode != "tactical_5v5":
        mode = "battle_royale"
    if mode == "tactical_5v5":
        max_players = mini(max_players, 10)

    var config := ConfigFile.new()
    config.set_value("game", "mode", mode)
    config.set_value("game", "team_size", clampi(_server_argument("--team-size=", "4").to_int(), 1, 5))
    config.save(SETTINGS_PATH)

    var peer := ENetMultiplayerPeer.new()
    var error := peer.create_server(port, max_players)
    if error != OK:
        push_error("ZORIX dedicated server failed to bind UDP %d: %s" % [port, error_string(error)])
        get_tree().quit(1)
        return

    multiplayer.multiplayer_peer = peer
    Engine.physics_ticks_per_second = 30
    print("ZORIX DEDICATED SERVER READY | port=%d | capacity=%d | mode=%s" % [port, max_players, mode])

    var result := get_tree().change_scene_to_file(MATCH_SCENE)
    if result != OK:
        push_error("ZORIX dedicated server could not load match scene: " + error_string(result))
        get_tree().quit(1)

func _load_settings():
    var config = ConfigFile.new()
    if config.load(SETTINGS_PATH) == OK:
        graphics_quality = str(config.get_value("graphics", "quality", "performance" if bool(config.get_value("graphics", "performance", false)) else "balanced"))
        if graphics_quality not in ["low", "balanced", "hd"]:
            graphics_quality = "balanced"
        fps_limit = clampi(int(config.get_value("graphics", "fps_limit", 60)), 30, 90)
        selected_game_mode = str(config.get_value("game", "mode", "battle_royale"))
        selected_team_size = clampi(int(config.get_value("game", "team_size", 4)), 1, 4)

func _save_settings():
    var config = ConfigFile.new()
    config.set_value("graphics", "quality", graphics_quality)
    config.set_value("graphics", "performance", graphics_quality == "low")
    config.set_value("graphics", "fps_limit", fps_limit)
    config.set_value("game", "mode", selected_game_mode)
    config.set_value("game", "team_size", [1, 2, 4][clampi(mode_picker.selected if mode_picker != null else 2, 0, 2)])
    config.save(SETTINGS_PATH)
    _apply_frame_limit()

func _apply_frame_limit():
    Engine.max_fps = fps_limit

func _panel_style(color: Color, border_color: Color) -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border_color
    style.set_border_width_all(2)
    style.set_corner_radius_all(16)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 16
    style.content_margin_bottom = 16
    return style

func _build_lobby():
    # Full-screen layout: fixed controls, no scrolling container.
    var background := ColorRect.new()
    background.color = Color("#07131d")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 12
    root.offset_right = -12
    root.offset_top = 10
    root.offset_bottom = -10
    root.add_theme_constant_override("separation", 8)
    add_child(root)
    var header := HBoxContainer.new()
    header.custom_minimum_size.y = 46
    root.add_child(header)
    var logo := Label.new()
    logo.text = "Z O R I X"
    logo.add_theme_font_size_override("font_size", 27)
    logo.add_theme_color_override("font_color", Color("#f3f7f4"))
    header.add_child(logo)
    var header_spacer := Control.new()
    header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(header_spacer)
    var season := Label.new()
    season.text = "INDIA BATTLEFIELD  •  SEASON 01"
    season.add_theme_color_override("font_color", Color("#f0c477"))
    header.add_child(season)
    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 8)
    root.add_child(body)
    var left := VBoxContainer.new()
    left.custom_minimum_size.x = 118
    left.add_theme_constant_override("separation", 8)
    body.add_child(left)
    for item in ["PROFILE", "FRIENDS", "INVENTORY", "MISSIONS"]:
        var menu_button := _make_button(item, Color("#193847"))
        menu_button.custom_minimum_size.y = 46
        menu_button.add_theme_font_size_override("font_size", 12)
        menu_button.pressed.connect(func(): info_label.text = item + " selected.")
        left.add_child(menu_button)
    var center := VBoxContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.add_theme_constant_override("separation", 5)
    body.add_child(center)
    var hero_title := Label.new()
    hero_title.text = "YOUR BATTLEFIELD. YOUR LEGEND."
    hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hero_title.add_theme_font_size_override("font_size", 17)
    hero_title.add_theme_color_override("font_color", Color("#f0c477"))
    center.add_child(hero_title)
    var preview := SubViewportContainer.new()
    preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
    preview.stretch = true
    center.add_child(preview)
    var viewport := SubViewport.new()
    viewport.size = Vector2i(800, 600)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    preview.add_child(viewport)
    var stage := Node3D.new()
    viewport.add_child(stage)
    var world_env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#12232b")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#91b5a8")
    environment.ambient_light_energy = 0.8
    world_env.environment = environment
    stage.add_child(world_env)
    var camera := Camera3D.new()
    camera.position = Vector3(3.0, 2.1, 5.8)
    camera.current = true
    stage.add_child(camera)
    camera.look_at(Vector3(0.0, 1.15, 0.0), Vector3.UP)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
    light.light_energy = 1.4
    stage.add_child(light)
    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(12.0, 12.0)
    floor.mesh = floor_mesh
    floor.position.y = -0.04
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("#243a35")
    floor.material_override = floor_material
    stage.add_child(floor)
    # Reuse ZORIX's existing Indian commando visual generator in the lobby preview.
    var character_visual := Node3D.new()
    character_visual.set_script(load("res://Scripts/player_visual.gd"))
    stage.add_child(character_visual)
    var right := VBoxContainer.new()
    right.custom_minimum_size.x = 118
    right.add_theme_constant_override("separation", 8)
    body.add_child(right)
    for item in ["STORE", "RANK", "REWARDS", "SETTINGS"]:
        var menu_button := _make_button(item, Color("#193847"))
        menu_button.custom_minimum_size.y = 46
        menu_button.add_theme_font_size_override("font_size", 12)
        menu_button.pressed.connect(func(): info_label.text = item + " selected.")
        right.add_child(menu_button)
    var bottom := VBoxContainer.new()
    bottom.add_theme_constant_override("separation", 5)
    root.add_child(bottom)
    var controls := HBoxContainer.new()
    controls.add_theme_constant_override("separation", 7)
    bottom.add_child(controls)
    mode_picker = OptionButton.new()
    mode_picker.add_item("SOLO")
    mode_picker.add_item("DUO")
    mode_picker.add_item("SQUAD")
    mode_picker.select([1, 2, 4].find(selected_team_size))
    selected_mode = ["Solo", "Duo", "Squad"][mode_picker.selected]
    mode_picker.item_selected.connect(_on_mode_selected)
    controls.add_child(mode_picker)
    var br_button := _make_button("BATTLE ROYALE", Color("#254b61"))
    br_button.pressed.connect(_select_battle_royale)
    controls.add_child(br_button)
    var tactical_button := _make_button("TACTICAL 5v5", Color("#8a4b25"))
    tactical_button.pressed.connect(_select_tactical)
    controls.add_child(tactical_button)
    var start_button := _make_button("START MATCH", Color("#167c70"))
    start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    start_button.pressed.connect(_play_offline)
    controls.add_child(start_button)
    var server_row := HBoxContainer.new()
    bottom.add_child(server_row)
    address_input = LineEdit.new()
    address_input.placeholder_text = "Optional game server IP"
    address_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    server_row.add_child(address_input)
    var join_button := _make_button("JOIN SERVER", Color("#254b61"))
    join_button.pressed.connect(_join_room)
    server_row.add_child(join_button)
    info_label = Label.new()
    info_label.text = "Choose Solo, Duo or Squad, then tap START MATCH."
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_label.add_theme_color_override("font_color", Color("#f0c477"))
    bottom.add_child(info_label)
    player_account = Node.new()
    player_account.name = "PlayerAccount"
    player_account.set_script(PLAYER_ACCOUNT)
    add_child(player_account)
    var login_overlay := PanelContainer.new()
    login_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    login_overlay.z_index = 20
    login_overlay.add_theme_stylebox_override("panel", _panel_style(Color("#08151e"), Color("#b58a45")))
    add_child(login_overlay)
    var login_margin := MarginContainer.new()
    login_margin.add_theme_constant_override("margin_left", 28)
    login_margin.add_theme_constant_override("margin_right", 28)
    login_margin.add_theme_constant_override("margin_top", 20)
    login_margin.add_theme_constant_override("margin_bottom", 20)
    login_overlay.add_child(login_margin)
    var login_stack := VBoxContainer.new()
    login_stack.alignment = BoxContainer.ALIGNMENT_CENTER
    login_stack.add_theme_constant_override("separation", 12)
    login_margin.add_child(login_stack)
    var welcome := Label.new()
    welcome.text = "Z O R I X  •  WELCOME SOLDIER"
    welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    welcome.add_theme_font_size_override("font_size", 28)
    welcome.add_theme_color_override("font_color", Color("#f0c477"))
    login_stack.add_child(welcome)
    var login_content := VBoxContainer.new()
    login_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    login_stack.add_child(login_content)
    player_account.call("build_ui", login_content)
    player_account.connect("public_server_loaded", _on_public_server_loaded)
    player_account.connect("login_completed", func(_player_name: String): login_overlay.queue_free())
    _update_mode_status()
func _add_section(text_value: String):
    var label = Label.new()
    label.text = text_value
    label.add_theme_color_override("font_color", Color("#62d6c6"))
    label.add_theme_font_size_override("font_size", 14)
    content.add_child(label)

func _make_button(caption: String, color: Color) -> Button:
    var button = Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 50)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", Color.WHITE)
    var normal = StyleBoxFlat.new()
    normal.bg_color = color
    normal.set_corner_radius_all(10)
    normal.content_margin_top = 9
    normal.content_margin_bottom = 9
    button.add_theme_stylebox_override("normal", normal)
    var hover = normal.duplicate()
    hover.bg_color = color.lightened(0.12)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    return button

func _select_battle_royale():
    selected_game_mode = "battle_royale"
    _save_settings()
    _update_mode_status()

func _select_tactical():
    selected_game_mode = "tactical_5v5"
    _save_settings()
    _update_mode_status()

func _update_mode_status():
    if info_label == null:
        return
    if selected_game_mode == "tactical_5v5":
        info_label.text = "TACTICAL 5v5 selected: compact arena, two teams, bomb-site practice."
    else:
        info_label.text = "BATTLE ROYALE selected: expanded island, 50-player queue modes and survival practice."

func _on_mode_selected(index: int):
    selected_mode = ["Solo", "Duo", "Squad"][index]
    _save_settings()
    if selected_game_mode == "battle_royale":
        info_label.text = selected_mode + " selected. Match capacity remains 50 players."

func _host_room():
    if player_account == null or not bool(player_account.call("is_logged_in")):
        info_label.text = "Please register/login before entering online rooms."
        return
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_server(DEFAULT_PORT, MAX_PLAYERS - 1)
    if error != OK:
        info_label.text = "Room could not start: " + error_string(error) + ". Try another network or port."
        return
    multiplayer.multiplayer_peer = peer
    info_label.text = "ROOM HOSTED. Loading online battlefield..."
    _start_online_match()

func _join_room():
    if player_account == null or not bool(player_account.call("is_logged_in")):
        info_label.text = "Please register/login before joining the public lobby."
        return
    var host = address_input.text.strip_edges()
    if host.is_empty():
        info_label.text = "Enter the host public IP address first."
        return
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(host, DEFAULT_PORT)
    if error != OK:
        info_label.text = "Could not connect: " + error_string(error)
        return
    multiplayer.multiplayer_peer = peer
    info_label.text = "Connecting to " + host + ":" + str(DEFAULT_PORT) + "..."

func _on_public_server_loaded(host: String, port: int):
    address_input.text = host
    info_label.text = "Public server found at %s:%d. Tap JOIN ROOM BY IP when it is online." % [host, port]

func _play_offline():
    _save_settings()
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    var result = get_tree().change_scene_to_file(MATCH_SCENE)
    if result != OK:
        info_label.text = "Match scene could not load. Check Scenes/Main.tscn."

func _on_peer_connected(_id: int):
    info_label.text = "Player connected. Current players: " + str(multiplayer.get_peers().size() + 1) + " / " + str(MAX_PLAYERS)

func _on_peer_disconnected(_id: int):
    info_label.text = "Player left. Current players: " + str(multiplayer.get_peers().size() + 1) + " / " + str(MAX_PLAYERS)

func _on_connected():
    info_label.text = "Connected! Loading online battlefield..."
    _start_online_match()

func _start_online_match():
    var result = get_tree().change_scene_to_file(MATCH_SCENE)
    if result != OK:
        info_label.text = "Could not load online match scene: " + error_string(result)

func _on_connection_failed():
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    info_label.text = "Connection failed. Check IP, server status and UDP port 24560."

func _on_server_disconnected():
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    info_label.text = "Disconnected from room."

func _on_graphics_quality_selected(index: int):
    graphics_quality = ["low", "balanced", "hd"][clampi(index, 0, 2)]
    _save_settings()
    info_label.text = "Graphics set to %s. It applies when the next match loads." % graphics_quality.to_upper()

func _on_fps_selected(index: int):
    fps_limit = [30, 60, 90][clampi(index, 0, 2)]
    _save_settings()
    info_label.text = "FPS target set to %d. Actual FPS depends on your device." % fps_limit

func _exit_tree():
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
