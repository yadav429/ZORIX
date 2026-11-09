extends Control

const MATCH_SCENE := "res://Scenes/Main.tscn"
const PLAYER_ACCOUNT := preload("res://Scripts/player_account.gd")
const SETTINGS_PATH := "user://zorix_settings.cfg"
const DEFAULT_PORT := 24560
const MAX_PLAYERS := 50

var content: VBoxContainer
var info_label: Label
var graphics_button: Button
var address_input: LineEdit
var mode_picker: OptionButton
var performance_mode := false
var selected_mode := "Squad"
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
        performance_mode = bool(config.get_value("graphics", "performance", false))
        selected_game_mode = str(config.get_value("game", "mode", "battle_royale"))

func _save_settings():
    var config = ConfigFile.new()
    config.set_value("graphics", "performance", performance_mode)
    config.set_value("game", "mode", selected_game_mode)
    config.save(SETTINGS_PATH)

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

    player_account = Node.new()
    player_account.name = "PlayerAccount"
    player_account.set_script(PLAYER_ACCOUNT)
    add_child(player_account)
    player_account.call("build_ui", content)
    player_account.connect("public_server_loaded", _on_public_server_loaded)

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
    mode_picker.select(2)
    mode_picker.item_selected.connect(_on_mode_selected)
    mode_picker.custom_minimum_size.y = 48
    content.add_child(mode_picker)

    var capacity = Label.new()
    capacity.text = "BATTLE ROYALE CAPACITY: 50 PLAYERS MAXIMUM"
    capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    capacity.add_theme_color_override("font_color", Color("#b9cbd0"))
    content.add_child(capacity)

    _add_section("3  CREATE OR JOIN ROOM")
    address_input = LineEdit.new()
    address_input.placeholder_text = "Host IP address (example: 123.45.67.89)"
    address_input.custom_minimum_size.y = 48
    address_input.clear_button_enabled = true
    content.add_child(address_input)

    var host_button = _make_button("CREATE ROOM (HOST)", Color("#167c70"))
    host_button.pressed.connect(_host_room)
    content.add_child(host_button)

    var join_button = _make_button("JOIN ROOM BY IP", Color("#254b61"))
    join_button.pressed.connect(_join_room)
    content.add_child(join_button)

    var local_button = _make_button("PLAY OFFLINE TRAINING", Color("#354454"))
    local_button.pressed.connect(_play_offline)
    content.add_child(local_button)

    graphics_button = _make_button("", Color("#354454"))
    graphics_button.pressed.connect(_toggle_graphics)
    content.add_child(graphics_button)
    _update_graphics_button()
    _update_mode_status()

    var panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _panel_style(Color("#172b36"), Color("#31505b")))
    content.add_child(panel)

    info_label = Label.new()
    info_label.text = "Choose Battle Royale or Tactical 5v5, then play offline or create/join a room."
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_label.add_theme_color_override("font_color", Color("#d8e5e6"))
    panel.add_child(info_label)

    var note = Label.new()
    note.text = "Online room networking is a prototype and needs a reachable game server. Supabase matchmaking setup is separate."
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

func _update_graphics_button():
    graphics_button.text = "GRAPHICS: PERFORMANCE" if performance_mode else "GRAPHICS: BALANCED"

func _toggle_graphics():
    performance_mode = not performance_mode
    _save_settings()
    _update_graphics_button()
    info_label.text = "Graphics preference saved."

func _exit_tree():
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
