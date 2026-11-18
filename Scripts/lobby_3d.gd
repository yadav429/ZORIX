extends "res://Scripts/lobby.gd"

var hud: Control
var preview_camera: Camera3D
var preview_angle := 0.0
var mode_status: Label
var hud_visible := false

func _build_lobby() -> void:
    # Full-screen 3D hangar lobby. No school/menu splash or long scrolling card.
    var backdrop := ColorRect.new()
    backdrop.color = Color("#07131b")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)

    var viewport_container := SubViewportContainer.new()
    viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    viewport_container.stretch = true
    viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(viewport_container)

    var viewport := SubViewport.new()
    viewport.size = Vector2i(960, 540)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.handle_input_locally = false
    viewport_container.add_child(viewport)

    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#152832")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#a2b7a8")
    environment.ambient_light_energy = 0.7
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    viewport.world_3d = World3D.new()
    viewport.world_3d.environment = environment

    var stage := Node3D.new()
    stage.name = "ZORIX_Hangar"
    viewport.add_child(stage)

    preview_camera = Camera3D.new()
    preview_camera.position = Vector3(3.2, 2.25, 6.2)
    preview_camera.fov = 38.0
    preview_camera.current = true
    stage.add_child(preview_camera)
    preview_camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-42.0, -25.0, 0.0)
    key_light.light_energy = 1.55
    key_light.shadow_enabled = true
    stage.add_child(key_light)

    var fill := OmniLight3D.new()
    fill.position = Vector3(-3.0, 3.0, 2.0)
    fill.light_color = Color("#65bdb0")
    fill.light_energy = 1.4
    fill.omni_range = 10.0
    stage.add_child(fill)

    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(22.0, 22.0)
    floor.mesh = floor_mesh
    floor.position.y = -0.06
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color("#1b3030")
    floor_mat.roughness = 0.92
    floor.material_override = floor_mat
    stage.add_child(floor)

    # Hangar architecture and illuminated ZORIX-style accent strips.
    for x in [-5.5, 5.5]:
        var pillar := MeshInstance3D.new()
        var pillar_mesh := BoxMesh.new()
        pillar_mesh.size = Vector3(0.42, 5.0, 0.5)
        pillar.mesh = pillar_mesh
        pillar.position = Vector3(x, 2.45, -2.6)
        var pillar_mat := StandardMaterial3D.new()
        pillar_mat.albedo_color = Color("#263c43")
        pillar_mat.metallic = 0.55
        pillar.material_override = pillar_mat
        stage.add_child(pillar)

        var strip := MeshInstance3D.new()
        var strip_mesh := BoxMesh.new()
        strip_mesh.size = Vector3(0.055, 3.8, 0.07)
        strip.mesh = strip_mesh
        strip.position = Vector3(x - 0.24 if x < 0.0 else x + 0.24, 2.5, -2.3)
        var strip_mat := StandardMaterial3D.new()
        strip_mat.albedo_color = Color("#e0a94f")
        strip_mat.emission_enabled = true
        strip_mat.emission = Color("#a66b24")
        strip.material_override = strip_mat
        stage.add_child(strip)

    var platform := MeshInstance3D.new()
    var platform_mesh := CylinderMesh.new()
    platform_mesh.top_radius = 1.12
    platform_mesh.bottom_radius = 1.22
    platform_mesh.height = 0.14
    platform.mesh = platform_mesh
    platform.position.y = 0.04
    var platform_mat := StandardMaterial3D.new()
    platform_mat.albedo_color = Color("#354b43")
    platform_mat.metallic = 0.38
    platform_mat.roughness = 0.42
    platform.material_override = platform_mat
    stage.add_child(platform)

    var character_scene: PackedScene = load("res://Scenes/LobbyCharacter.tscn")
    if character_scene != null:
        var character := character_scene.instantiate()
        character.position.y = 0.12
        stage.add_child(character)

    # Dark gradient-like HUD surfaces keep text readable over the 3D scene.
    hud = Control.new()
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(hud)

    var top_bar := _hud_panel(Vector2(0.02, 0.025), Vector2(0.98, 0.12), Color("#101d25dd"))
    hud.add_child(top_bar)
    var top_row := HBoxContainer.new()
    top_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    top_row.add_theme_constant_override("separation", 12)
    top_bar.add_child(top_row)
    var brand := _hud_label("Z O R I X", 24, Color("#f0c477"))
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(brand)
    top_row.add_child(_hud_label("PLAYER  •  ID: LOCAL", 13, Color("#d7e5e5")))
    top_row.add_child(_hud_label("◆ 0     ◈ 0", 15, Color("#f0c477")))
    var profile_button := _make_button("PROFILE", Color("#31505b"))
    profile_button.custom_minimum_size = Vector2(92, 42)
    profile_button.pressed.connect(_open_profile)
    top_row.add_child(profile_button)

    var left_panel := _hud_panel(Vector2(0.02, 0.19), Vector2(0.20, 0.67), Color("#101d25d9"))
    hud.add_child(left_panel)
    var left_stack := VBoxContainer.new()
    left_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    left_stack.add_theme_constant_override("separation", 9)
    left_panel.add_child(left_stack)
    left_stack.add_child(_hud_label("COMMAND", 13, Color("#f0c477")))
    var store_button := _make_button("STORE", Color("#765324"))
    store_button.pressed.connect(_open_store)
    left_stack.add_child(store_button)
    var inventory_button := _make_button("INVENTORY", Color("#31505b"))
    inventory_button.pressed.connect(_open_inventory)
    left_stack.add_child(inventory_button)
    var events_button := _make_button("EVENTS", Color("#31505b"))
    events_button.pressed.connect(_open_events)
    left_stack.add_child(events_button)
    var rank_button := _make_button("RANK", Color("#31505b"))
    rank_button.pressed.connect(_open_rank)
    left_stack.add_child(rank_button)

    var right_panel := _hud_panel(Vector2(0.79, 0.19), Vector2(0.98, 0.67), Color("#101d25d9"))
    hud.add_child(right_panel)
    var right_stack := VBoxContainer.new()
    right_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    right_stack.add_theme_constant_override("separation", 9)
    right_panel.add_child(right_stack)
    right_stack.add_child(_hud_label("SOCIAL", 13, Color("#f0c477")))
    var friends_button := _make_button("FRIENDS", Color("#31505b"))
    friends_button.pressed.connect(_open_friends)
    right_stack.add_child(friends_button)
    var mail_button := _make_button("MAIL", Color("#31505b"))
    mail_button.pressed.connect(_open_mail)
    right_stack.add_child(mail_button)
    var settings_button := _make_button("SETTINGS", Color("#31505b"))
    settings_button.pressed.connect(_open_lobby_settings)
    right_stack.add_child(settings_button)

    # Keep inherited matchmaking/settings logic, while presenting compact HUD controls.
    content = VBoxContainer.new()
    content.visible = false
    add_child(content)
    info_label = Label.new()
    info_label.text = "Choose a mode and start your mission."
    mode_picker = OptionButton.new()
    mode_picker.add_item("SOLO")
    mode_picker.add_item("DUO")
    mode_picker.add_item("SQUAD")
    mode_picker.select([1, 2, 4].find(selected_team_size))
    mode_picker.item_selected.connect(_on_mode_selected)
    selected_mode = ["Solo", "Duo", "Squad"][mode_picker.selected]
    matchmaking_request = HTTPRequest.new()
    matchmaking_request.timeout = 18.0
    add_child(matchmaking_request)
    matchmaking_request.request_completed.connect(_on_matchmaking_request_completed)
    matchmaking_timer = Timer.new()
    matchmaking_timer.wait_time = 2.0
    matchmaking_timer.timeout.connect(_poll_matchmaking)
    add_child(matchmaking_timer)

    var bottom_panel := _hud_panel(Vector2(0.22, 0.77), Vector2(0.78, 0.98), Color("#101d25ed"))
    hud.add_child(bottom_panel)
    var bottom_stack := VBoxContainer.new()
    bottom_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bottom_stack.add_theme_constant_override("separation", 5)
    bottom_panel.add_child(bottom_stack)
    bottom_stack.add_child(_hud_label("SELECT MODE", 12, Color("#f0c477")))
    bottom_stack.add_child(mode_picker)
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 8)
    bottom_stack.add_child(actions)
    var start_button := _make_button("START", Color("#168575"))
    start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    start_button.pressed.connect(_queue_for_matchmaking)
    actions.add_child(start_button)
    var cancel_button := _make_button("CANCEL", Color("#80412d"))
    cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel_button.pressed.connect(_cancel_matchmaking)
    actions.add_child(cancel_button)

    mode_status = _hud_label("BATTLE ROYALE  •  UP TO 50 PLAYERS", 11, Color("#d7e5e5"))
    bottom_stack.add_child(mode_status)

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
    _set_hud_enabled(false)

func _hud_panel(from: Vector2, to: Vector2, color: Color) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.anchor_left = from.x
    panel.anchor_top = from.y
    panel.anchor_right = to.x
    panel.anchor_bottom = to.y
    panel.add_theme_stylebox_override("panel", _panel_style(color, Color("#8b7448")))
    return panel

func _hud_label(value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _set_status(value: String) -> void:
    if info_label != null:
        info_label.text = value
    if mode_status != null:
        mode_status.text = value

func _set_hud_enabled(enabled: bool) -> void:
    hud_visible = enabled
    if hud != null:
        hud.visible = enabled

func _build_login_screen() -> void:
    login_overlay = Control.new()
    login_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    login_overlay.z_index = 30
    add_child(login_overlay)

    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.035, 0.045, 0.68)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    login_overlay.add_child(shade)

    var card := PanelContainer.new()
    card.anchor_left = 0.13
    card.anchor_right = 0.87
    card.anchor_top = 0.17
    card.anchor_bottom = 0.83
    card.add_theme_stylebox_override("panel", _panel_style(Color("#101e29ee"), Color("#c29a52")))
    login_overlay.add_child(card)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    card.add_child(margin)

    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 9)
    stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_child(stack)
    stack.add_child(_hud_label("INDIA'S 3D BATTLE ARENA", 12, Color("#62d6c6")))
    stack.add_child(_hud_label("Z O R I X", 38, Color("#f0c477")))
    stack.add_child(_hud_label("ENTER THE BATTLEFIELD", 11, Color("#d7e5e5")))
    var login_host := VBoxContainer.new()
    login_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack.add_child(login_host)
    login_host.add_child(player_account.get_meta("login_content"))
    stack.add_child(_hud_label("SECURE ACCOUNT  •  FREE TO PLAY", 10, Color("#91a8b0")))

func _on_login_completed(player_name: String) -> void:
    if login_overlay != null:
        login_overlay.queue_free()
        login_overlay = null
    _set_hud_enabled(true)
    _set_status("Welcome %s • Choose Solo, Duo or Squad." % player_name)

func _open_lobby_settings() -> void:
    var popup := AcceptDialog.new()
    popup.title = "ZORIX SETTINGS"
    popup.dialog_text = "Graphics: %s | FPS cap: %d. Change graphics and FPS in the in-match settings panel." % [graphics_quality.to_upper(), fps_limit]
    add_child(popup)
    popup.popup_centered()

func _show_feature_panel(title_text: String, body_text: String) -> void:
    var popup := AcceptDialog.new()
    popup.title = title_text
    popup.dialog_text = body_text
    add_child(popup)
    popup.confirmed.connect(popup.queue_free)
    popup.canceled.connect(popup.queue_free)
    popup.popup_centered()

func _open_profile() -> void:
    _open_api_panel("PLAYER PROFILE", "/api/profile")

func _open_inventory() -> void:
    _open_api_panel("WEAPON INVENTORY", "/api/inventory")

func _open_events() -> void:
    _show_feature_panel("EVENTS", "Events hub is ready for event data. No live event schedule is configured yet.")

func _open_rank() -> void:
    _open_api_panel("RANK & LEADERBOARD", "/api/leaderboard?limit=50")

func _open_friends() -> void:
    _open_api_panel("FRIENDS", "/api/friends")

func _open_api_panel(title_text: String, path: String) -> void:
    if player_account == null or str(player_account.call("get_session_token")).is_empty():
        _show_feature_panel(title_text, "Please sign in with Google or Guest first.")
        return
    var popup := AcceptDialog.new()
    popup.title = title_text
    popup.dialog_text = "Loading..."
    popup.min_size = Vector2i(420, 300)
    add_child(popup)
    var req := HTTPRequest.new()
    req.timeout = 45.0
    add_child(req)
    req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
        var message := "Network error. Please check your internet connection."
        if result == HTTPRequest.RESULT_SUCCESS:
            var parsed = JSON.parse_string(body.get_string_from_utf8())
            if code >= 200 and code < 300:
                message = JSON.stringify(parsed, "  ")
            elif parsed is Dictionary:
                message = str(parsed.get("detail", "Request failed (HTTP %d)." % code))
            else:
                message = "Request failed (HTTP %d)." % code
        popup.dialog_text = message
        req.queue_free()
    )
    var headers := PackedStringArray(["Authorization: Bearer " + str(player_account.call("get_session_token"))])
    var err := req.request(str(player_account.call("get_api_base_url")).trim_suffix("/") + path, headers, HTTPClient.METHOD_GET)
    if err != OK:
        popup.dialog_text = "Could not start request: " + error_string(err)
        req.queue_free()
    popup.popup_centered()

func _open_mail() -> void:
    _show_feature_panel("MAIL", "You have no new system messages.")

func _open_store() -> void:
    if player_account == null:
        _show_feature_panel("STORE", "Please sign in first.")
        return
    var store := STORE_UI.new()
    store.configure_session(player_account.call("get_api_base_url"), player_account.call("get_session_token"))
    add_child(store)
    store.closed.connect(func(): _set_hud_enabled(true))
    _set_hud_enabled(false)

func _process(delta: float) -> void:
    if preview_camera != null:
        preview_angle += delta * 0.08
        var radius := 6.2
        preview_camera.position = Vector3(sin(preview_angle) * radius, 2.25, cos(preview_angle) * radius)
        preview_camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)

func _exit_tree() -> void:
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
