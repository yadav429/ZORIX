extends Control

const MATCH_SCENE := "res://Scenes/Main.tscn"
const PLAYER_ACCOUNT := preload("res://Scripts/player_account.gd")
const STORE_UI := preload("res://Scripts/store_ui.gd")
const PROGRESSION_UI := preload("res://Scripts/progression_ui.gd")
const SETTINGS_PATH := "user://zorix_settings.cfg"
const DEFAULT_PORT := 24560
const MAX_PLAYERS := 50

var content: VBoxContainer
var info_label: Label
var graphics_picker: OptionButton
var fps_picker: OptionButton
var address_input: LineEdit
var public_server_port := DEFAULT_PORT
var matchmaking_request: HTTPRequest
var matchmaking_timer: Timer
var matchmaking_busy := false
var join_ticket := ""
var matchmaking_state := "idle"
var mode_picker: OptionButton
var graphics_quality := "balanced"
var fps_limit := 60
var selected_mode := "Squad"
var selected_team_size := 4
var selected_game_mode := "battle_royale"
var player_account: Node
var login_overlay: Control

func _ready():
    if not ServerFleetAgent.join_validation_received.is_connected(_on_join_ticket_validated):
        ServerFleetAgent.join_validation_received.connect(_on_join_ticket_validated)
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
    var background = ColorRect.new()
    background.color = Color("#07131d")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var scroll = ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.offset_left = 12
    scroll.offset_top = 12
    scroll.offset_right = -12
    scroll.offset_bottom = -12
    add_child(scroll)

    var center = CenterContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(center)

    var card = PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override("panel", _panel_style(Color("#101e29"), Color("#2a6871")))
    center.add_child(card)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    card.add_child(margin)

    content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 11)
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_child(content)
    content.visible = false

    _add_hero_showcase()

    var store_button := _make_button("✦  OPEN PREMIUM STORE  •  WEAPON / BUNDLE / CAR SKINS", Color("#815d24"))
    store_button.pressed.connect(_open_store)
    content.add_child(store_button)

    var eyebrow = Label.new()
    eyebrow.text = "DUAL COMBAT MODES • MOBILE OPTIMIZED"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 12)
    eyebrow.add_theme_color_override("font_color", Color("#62d6c6"))
    content.add_child(eyebrow)

    var title = Label.new()
    title.text = "Z O R I X"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 40)
    title.add_theme_color_override("font_color", Color("#f3f7f4"))
    content.add_child(title)

    var map_title = Label.new()
    map_title.text = "INDIA BATTLEFIELD • EXPANDED MAP"
    map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_title.add_theme_color_override("font_color", Color("#f0c477"))
    content.add_child(map_title)


    _add_section("1  CHOOSE YOUR GAME")
    var br_button = _make_button("BATTLE ROYALE  •  50 PLAYERS", Color("#167c70"))
    br_button.pressed.connect(_select_battle_royale)
    content.add_child(br_button)

    var tactical_button = _make_button("TACTICAL 5v5  •  BOMB ARENA", Color("#8a4b25"))
    tactical_button.pressed.connect(_select_tactical)
    content.add_child(tactical_button)

    _add_section("2  TEAM SIZE • BATTLE ROYALE")
    mode_picker = OptionButton.new()
    mode_picker.add_item("SOLO  •  1 PLAYER PER TEAM")
    mode_picker.add_item("DUO  •  2 PLAYERS PER TEAM")
    mode_picker.add_item("SQUAD  •  4 PLAYERS PER TEAM")
    mode_picker.select([1, 2, 4].find(selected_team_size))
    selected_mode = ["Solo", "Duo", "Squad"][mode_picker.selected]
    mode_picker.item_selected.connect(_on_mode_selected)
    mode_picker.custom_minimum_size.y = 48
    content.add_child(mode_picker)

    var capacity = Label.new()
    capacity.text = "BATTLE ROYALE CAPACITY: 50 PLAYERS MAXIMUM"
    capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    capacity.add_theme_color_override("font_color", Color("#b9cbd0"))
    content.add_child(capacity)

    _add_section("3  AUTOMATIC ONLINE MATCHMAKING")
    matchmaking_request = HTTPRequest.new()
    matchmaking_request.timeout = 18.0
    add_child(matchmaking_request)
    matchmaking_request.request_completed.connect(_on_matchmaking_request_completed)
    matchmaking_timer = Timer.new()
    matchmaking_timer.wait_time = 2.0
    matchmaking_timer.timeout.connect(_poll_matchmaking)
    add_child(matchmaking_timer)

    var queue_button = _make_button("FIND MATCH  •  SOLO / DUO / SQUAD", Color("#167c70"))
    queue_button.pressed.connect(_queue_for_matchmaking)
    content.add_child(queue_button)

    var cancel_queue_button = _make_button("CANCEL SEARCH", Color("#8a4b25"))
    cancel_queue_button.pressed.connect(_cancel_matchmaking)
    content.add_child(cancel_queue_button)
    info_label = Label.new()
    info_label.text = "Login, choose Solo/Duo/Squad and tap FIND MATCH."
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_label.add_theme_color_override("font_color", Color("#f0c477"))
    content.add_child(info_label)

    _add_section("4  GRAPHICS QUALITY")
    graphics_picker = OptionButton.new()
    graphics_picker.add_item("LOW  •  SMOOTH PERFORMANCE")
    graphics_picker.add_item("BALANCED  •  FREE FIRE STYLE")
    graphics_picker.add_item("HD  •  SHARPER VISUALS")
    graphics_picker.select(["low", "balanced", "hd"].find(graphics_quality))
    graphics_picker.custom_minimum_size.y = 46
    graphics_picker.item_selected.connect(_on_graphics_quality_selected)
    content.add_child(graphics_picker)

    _add_section("5  FRAME RATE")
    fps_picker = OptionButton.new()
    fps_picker.add_item("30 FPS  •  BATTERY SAVER")
    fps_picker.add_item("60 FPS  •  SMOOTH")
    fps_picker.add_item("90 FPS  •  SUPPORTED DEVICES")
    fps_picker.select(0 if fps_limit <= 30 else (2 if fps_limit >= 90 else 1))
    fps_picker.custom_minimum_size.y = 46
    fps_picker.item_selected.connect(_on_fps_selected)
    content.add_child(fps_picker)
    _update_mode_status()

    var panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style(Color("#172b36"), Color("#31505b")))
    content.add_child(panel)
    var online_note = Label.new()
    online_note.text = "Online-only matches use a registered ZORIX dedicated server and a verified one-time join ticket."
    online_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    online_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    online_note.add_theme_color_override("font_color", Color("#d8e5e6"))
    panel.add_child(online_note)

    var note = Label.new()
    note.text = "Online matches require the public dedicated server to be deployed and registered in the account API."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_font_size_override("font_size", 11)
    note.add_theme_color_override("font_color", Color("#8fa8af"))
    content.add_child(note)

    var footer = Label.new()
    footer.text = "ZORIX • TRAIN • SURVIVE • WIN"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_font_size_override("font_size", 11)
    footer.add_theme_color_override("font_color", Color("#78949c"))
    content.add_child(footer)

    player_account = Node.new()
    player_account.name = "PlayerAccount"
    player_account.set_script(PLAYER_ACCOUNT)
    add_child(player_account)
    var login_content := _build_login_content()
    player_account.call("build_ui", login_content)
    player_account.set_meta("login_content", login_content)
    player_account.connect("public_server_loaded", _on_public_server_loaded)
    player_account.connect("login_completed", _on_login_completed)
    _build_login_screen()


func _build_login_content() -> VBoxContainer:
    var login_content := VBoxContainer.new()
    login_content.add_theme_constant_override("separation", 14)
    login_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return login_content


func _build_login_screen() -> void:
    login_overlay = Control.new()
    login_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    login_overlay.z_index = 20
    add_child(login_overlay)

    var backdrop := ColorRect.new()
    backdrop.color = Color("#061018")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    login_overlay.add_child(backdrop)

    var top_glow := ColorRect.new()
    top_glow.color = Color("#102b35")
    top_glow.anchor_left = 0.0
    top_glow.anchor_right = 1.0
    top_glow.anchor_top = 0.0
    top_glow.anchor_bottom = 0.48
    top_glow.offset_bottom = 0.0
    login_overlay.add_child(top_glow)

    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.offset_left = 18
    scroll.offset_right = -18
    scroll.offset_top = 18
    scroll.offset_bottom = -18
    login_overlay.add_child(scroll)

    var center := CenterContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.add_child(center)

    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0, 500)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override("panel", _panel_style(Color("#101e29"), Color("#b58a45")))
    center.add_child(card)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 26)
    margin.add_theme_constant_override("margin_bottom", 22)
    card.add_child(margin)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 12)
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_child(stack)

    var top_line := Label.new()
    top_line.text = "INDIA'S BATTLE ARENA"
    top_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    top_line.add_theme_font_size_override("font_size", 12)
    top_line.add_theme_color_override("font_color", Color("#62d6c6"))
    stack.add_child(top_line)

    var logo := Label.new()
    logo.text = "Z O R I X"
    logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    logo.add_theme_font_size_override("font_size", 48)
    logo.add_theme_color_override("font_color", Color("#f3f7f4"))
    stack.add_child(logo)

    var tagline := Label.new()
    tagline.text = "DROP IN • FIGHT HARD • BE THE LAST ONE"
    tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tagline.add_theme_font_size_override("font_size", 11)
    tagline.add_theme_color_override("font_color", Color("#f0c477"))
    stack.add_child(tagline)

    var separator := HSeparator.new()
    stack.add_child(separator)

    var login_host := VBoxContainer.new()
    login_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack.add_child(login_host)
    for child in _get_login_content_children():
        login_host.add_child(child)

    var footer := Label.new()
    footer.text = "SECURE ACCOUNT • FREE TO PLAY"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_font_size_override("font_size", 10)
    footer.add_theme_color_override("font_color", Color("#78949c"))
    stack.add_child(footer)


func _get_login_content_children() -> Array:
    var result: Array = []
    for child in player_account.get_meta("login_content").get_children():
        result.append(child)
    return result


func _on_login_completed(_player_name: String) -> void:
    if login_overlay != null:
        login_overlay.queue_free()
        login_overlay = null
    if content != null:
        content.visible = true


func _add_hero_showcase() -> void:
    var hero_title := Label.new()
    hero_title.text = "YOUR BATTLEFIELD. YOUR LEGEND."
    hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hero_title.add_theme_font_size_override("font_size", 18)
    hero_title.add_theme_color_override("font_color", Color("#f0c477"))
    content.add_child(hero_title)

    var hero_subtitle := Label.new()
    hero_subtitle.text = "INDIAN ELITE COMMANDO  •  LIVE 3D PREVIEW"
    hero_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hero_subtitle.add_theme_font_size_override("font_size", 11)
    hero_subtitle.add_theme_color_override("font_color", Color("#9fc5bd"))
    content.add_child(hero_subtitle)

    var preview_frame := PanelContainer.new()
    preview_frame.custom_minimum_size = Vector2(0, 285)
    preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview_frame.add_theme_stylebox_override("panel", _panel_style(Color("#09151b"), Color("#b58a45")))
    content.add_child(preview_frame)

    var preview_margin := MarginContainer.new()
    preview_margin.add_theme_constant_override("margin_left", 5)
    preview_margin.add_theme_constant_override("margin_right", 5)
    preview_margin.add_theme_constant_override("margin_top", 5)
    preview_margin.add_theme_constant_override("margin_bottom", 5)
    preview_frame.add_child(preview_margin)

    var viewport_container := SubViewportContainer.new()
    viewport_container.custom_minimum_size = Vector2(0, 270)
    viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    viewport_container.stretch = true
    preview_margin.add_child(viewport_container)

    var viewport := SubViewport.new()
    viewport.size = Vector2i(720, 480)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.handle_input_locally = false
    viewport_container.add_child(viewport)

    var world := World3D.new()
    viewport.world_3d = world
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#101f25")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#8aa99a")
    environment.ambient_light_energy = 0.55
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = environment

    var stage := Node3D.new()
    stage.name = "LobbyStage"
    viewport.add_child(stage)

    var camera := Camera3D.new()
    camera.position = Vector3(3.0, 2.25, 5.8)
    camera.fov = 38.0
    camera.current = true
    stage.add_child(camera)
    camera.look_at(Vector3(0.0, 1.22, 0.0), Vector3.UP)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
    key_light.light_energy = 1.45
    key_light.shadow_enabled = true
    stage.add_child(key_light)

    var fill_light := OmniLight3D.new()
    fill_light.position = Vector3(-2.5, 2.6, 2.0)
    fill_light.light_color = Color("#6bb9b2")
    fill_light.light_energy = 1.1
    fill_light.omni_range = 8.0
    stage.add_child(fill_light)

    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(14.0, 14.0)
    floor.mesh = floor_mesh
    floor.position.y = -0.035
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("#182b2b")
    floor_material.roughness = 0.94
    floor.material_override = floor_material
    stage.add_child(floor)

    var platform := MeshInstance3D.new()
    var platform_mesh := CylinderMesh.new()
    platform_mesh.top_radius = 1.05
    platform_mesh.bottom_radius = 1.12
    platform_mesh.height = 0.12
    platform.mesh = platform_mesh
    platform.position.y = 0.04
    var platform_material := StandardMaterial3D.new()
    platform_material.albedo_color = Color("#344a43")
    platform_material.metallic = 0.35
    platform_material.roughness = 0.48
    platform.material_override = platform_material
    stage.add_child(platform)

    var character_scene: PackedScene = load("res://Scenes/LobbyCharacter.tscn")
    if character_scene != null:
        var character := character_scene.instantiate()
        character.position.y = 0.12
        stage.add_child(character)

    var caption := Label.new()
    caption.text = "COMMANDO 01   |   VEER CLASS"
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.add_theme_font_size_override("font_size", 12)
    caption.add_theme_color_override("font_color", Color("#e8d5a8"))
    content.add_child(caption)

func _open_store() -> void:
    if content == null:
        return
    content.visible = false
    var store := STORE_UI.new()
    add_child(store)
    store.closed.connect(func(): content.visible = true)

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

func _queue_for_matchmaking():
    if selected_game_mode != "battle_royale":
        info_label.text = "Automatic queue is currently available for Battle Royale. Tactical 5v5 server allocation is next."
        return
    if player_account == null or not bool(player_account.call("is_logged_in")):
        info_label.text = "Google ya Guest se pehle login karein."
        return
    if matchmaking_busy:
        return
    _save_settings()
    matchmaking_state = "queue"
    _send_matchmaking_request("/api/matchmaking/queue", HTTPClient.METHOD_POST, {"mode": selected_mode.to_lower()})

func _cancel_matchmaking():
    matchmaking_timer.stop()
    if player_account == null or not bool(player_account.call("is_logged_in")):
        matchmaking_state = "idle"
        info_label.text = "Match search cancelled."
        return
    matchmaking_state = "cancel"
    _send_matchmaking_request("/api/matchmaking/queue", HTTPClient.METHOD_DELETE, {})

func _send_matchmaking_request(path: String, method: int, payload: Dictionary = {}):
    if matchmaking_busy:
        return
    var token := str(player_account.call("get_session_token"))
    var base := str(player_account.call("get_api_base_url")).trim_suffix("/")
    if token.is_empty() or base.is_empty():
        info_label.text = "Login session missing. Please login again."
        return
    matchmaking_busy = true
    var headers := PackedStringArray(["Authorization: Bearer " + token, "Content-Type: application/json"])
    var body := JSON.stringify(payload) if method in [HTTPClient.METHOD_POST, HTTPClient.METHOD_PUT, HTTPClient.METHOD_PATCH] and not payload.is_empty() else ""
    var err := matchmaking_request.request(base + path, headers, method, body)
    if err != OK:
        matchmaking_busy = false
        info_label.text = "Matchmaking request failed: " + error_string(err)

func _poll_matchmaking():
    if matchmaking_state != "searching" or matchmaking_busy:
        return
    _send_matchmaking_request("/api/matchmaking/status", HTTPClient.METHOD_GET)

func _on_matchmaking_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
    matchmaking_busy = false
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if result != HTTPRequest.RESULT_SUCCESS:
        info_label.text = "Network issue. Searching will retry..."
        return
    if code < 200 or code >= 300:
        info_label.text = str(parsed.get("detail", "Matchmaking failed")) if parsed is Dictionary else "Matchmaking failed."
        matchmaking_timer.stop()
        return
    if not parsed is Dictionary:
        info_label.text = "Invalid matchmaking response."
        return
    if matchmaking_state == "queue":
        matchmaking_state = "searching"
        info_label.text = "Searching %s match... Waiting for players and a healthy server." % selected_mode
        matchmaking_timer.start()
        _poll_matchmaking()
        return
    if matchmaking_state == "cancel":
        matchmaking_state = "idle"
        info_label.text = "Match search cancelled."
        return
    if parsed.get("status", "") == "allocated":
        matchmaking_timer.stop()
        join_ticket = str(parsed.get("join_ticket", ""))
        var server: Dictionary = parsed.get("server", {})
        var host := str(server.get("host", ""))
        public_server_port = int(server.get("port", DEFAULT_PORT))
        if host.is_empty() or join_ticket.is_empty():
            info_label.text = "Match assigned, but server address or join ticket is missing."
            return
        var peer := ENetMultiplayerPeer.new()
        var err := peer.create_client(host, public_server_port)
        if err != OK:
            info_label.text = "Server connection failed: " + error_string(err)
            return
        multiplayer.multiplayer_peer = peer
        info_label.text = "Match found! Connecting to verified server..."
    elif parsed.get("status", "") == "queued":
        info_label.text = "Searching %s • Players waiting: %s" % [selected_mode, str(parsed.get("players_waiting", "…"))]
    else:
        info_label.text = "Waiting for the matchmaking queue..."

func _on_public_server_loaded(_host: String, _port: int):
    # Public server selection is intentionally replaced by automatic allocation.
    pass

func _on_peer_connected(_id: int):
    info_label.text = "Player connected. Current players: " + str(multiplayer.get_peers().size() + 1) + " / " + str(MAX_PLAYERS)

func _on_peer_disconnected(_id: int):
    info_label.text = "Player left. Current players: " + str(multiplayer.get_peers().size() + 1) + " / " + str(MAX_PLAYERS)

func _on_connected():
    if join_ticket.is_empty():
        info_label.text = "Connected without a matchmaking ticket. Disconnecting."
        multiplayer.multiplayer_peer.close()
        return
    ServerFleetAgent.submit_join_ticket(join_ticket)
    info_label.text = "Server connected. Verifying your one-time join ticket..."

func _on_join_ticket_validated(accepted: bool, message: String):
    if not accepted:
        info_label.text = "Server rejected the match ticket: " + message
        join_ticket = ""
        return
    info_label.text = "Verified! Loading the online battlefield..."
    _start_online_match()

func _start_online_match():
    var result = get_tree().change_scene_to_file(MATCH_SCENE)
    if result != OK:
        info_label.text = "Could not load online match scene: " + error_string(result)

func _on_connection_failed():
    info_label.text = "Online connection failed. Match search can be started again."
    join_ticket = ""

func _on_server_disconnected():
    info_label.text = "Disconnected from the online server. Reconnect when it is available."

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
