extends Control

const MATCH_SCENE := "res://Scenes/Main.tscn"
const SETTINGS_PATH := "user://zorix_settings.cfg"

var content: VBoxContainer
var info_panel: PanelContainer
var info_label: Label
var graphics_button: Button
var performance_mode := false

func _ready():
    _load_settings()
    _build_lobby()

func _load_settings():
    var config = ConfigFile.new()
    if config.load(SETTINGS_PATH) == OK:
        performance_mode = bool(config.get_value("graphics", "performance", false))

func _save_settings():
    var config = ConfigFile.new()
    config.set_value("graphics", "performance", performance_mode)
    config.save(SETTINGS_PATH)

func _panel_style(color: Color, border_color: Color) -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border_color
    style.set_border_width_all(2)
    style.set_corner_radius_all(16)
    style.content_margin_left = 22
    style.content_margin_right = 22
    style.content_margin_top = 18
    style.content_margin_bottom = 18
    return style

func _build_lobby():
    var background = ColorRect.new()
    background.color = Color("#07131d")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var glow = ColorRect.new()
    glow.color = Color("#102b35")
    glow.anchor_left = 0.0
    glow.anchor_top = 0.0
    glow.anchor_right = 1.0
    glow.anchor_bottom = 0.42
    glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.add_child(glow)

    var center = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var card = PanelContainer.new()
    card.custom_minimum_size = Vector2(0, 0)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override(
        "panel", _panel_style(Color("#101e29"), Color("#2a6871"))
    )
    center.add_child(card)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 26)
    margin.add_theme_constant_override("margin_right", 26)
    margin.add_theme_constant_override("margin_top", 24)
    margin.add_theme_constant_override("margin_bottom", 24)
    card.add_child(margin)

    content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 13)
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_child(content)

    var eyebrow = Label.new()
    eyebrow.text = "TACTICAL BATTLEFIELD  •  MOBILE"
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    eyebrow.add_theme_font_size_override("font_size", 12)
    eyebrow.add_theme_color_override("font_color", Color("#62d6c6"))
    content.add_child(eyebrow)

    var title = Label.new()
    title.text = "Z O R I X"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", Color("#f3f7f4"))
    content.add_child(title)

    var subtitle = Label.new()
    subtitle.text = "ENTER THE BATTLEFIELD"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 14)
    subtitle.add_theme_color_override("font_color", Color("#a5bbc2"))
    content.add_child(subtitle)

    var divider = HSeparator.new()
    content.add_child(divider)

    var map_title = Label.new()
    map_title.text = "INDIA BATTLEFIELD  |  SQUAD MATCH"
    map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_title.add_theme_font_size_override("font_size", 15)
    map_title.add_theme_color_override("font_color", Color("#f0c477"))
    content.add_child(map_title)

    var map_info = Label.new()
    map_info.text = "6 ENEMY SOLDIERS     •     2 FRIENDLY SQUAD"
    map_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_info.add_theme_font_size_override("font_size", 12)
    map_info.add_theme_color_override("font_color", Color("#c4d0d2"))
    content.add_child(map_info)

    var start_button = _make_button("START MATCH", Color("#167c70"))
    start_button.pressed.connect(_start_match)
    content.add_child(start_button)

    var squad_button = _make_button("SQUAD / TEAM", Color("#254b61"))
    squad_button.pressed.connect(_show_squad)
    content.add_child(squad_button)

    graphics_button = _make_button("", Color("#354454"))
    graphics_button.pressed.connect(_toggle_graphics)
    content.add_child(graphics_button)
    _update_graphics_button()

    info_panel = PanelContainer.new()
    info_panel.add_theme_stylebox_override(
        "panel", _panel_style(Color("#172b36"), Color("#31505b"))
    )
    content.add_child(info_panel)

    info_label = Label.new()
    info_label.text = "Choose START MATCH when you are ready."
    info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info_label.add_theme_font_size_override("font_size", 13)
    info_label.add_theme_color_override("font_color", Color("#d8e5e6"))
    info_panel.add_child(info_label)

    var footer = Label.new()
    footer.text = "ZORIX  •  TRAIN • SURVIVE • WIN"
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_font_size_override("font_size", 11)
    footer.add_theme_color_override("font_color", Color("#78949c"))
    content.add_child(footer)

func _make_button(caption: String, color: Color) -> Button:
    var button = Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 54)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 17)
    button.add_theme_color_override("font_color", Color.WHITE)

    var normal = StyleBoxFlat.new()
    normal.bg_color = color
    normal.set_corner_radius_all(10)
    normal.content_margin_top = 10
    normal.content_margin_bottom = 10
    button.add_theme_stylebox_override("normal", normal)

    var hover = normal.duplicate()
    hover.bg_color = color.lightened(0.12)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    return button

func _update_graphics_button():
    if performance_mode:
        graphics_button.text = "GRAPHICS: PERFORMANCE"
    else:
        graphics_button.text = "GRAPHICS: BALANCED"

func _start_match():
    var result = get_tree().change_scene_to_file(MATCH_SCENE)
    if result != OK:
        info_label.text = "Could not load the match scene. Please check the game files."

func _show_squad():
    info_label.text = "YOUR SQUAD\n2 friendly soldiers will follow you and attack nearby enemies.\n6 enemy soldiers are placed around the battlefield."

func _toggle_graphics():
    performance_mode = not performance_mode
    _save_settings()
    _update_graphics_button()
    if performance_mode:
        info_label.text = "Performance mode saved. Dynamic shadows are disabled in the match to help reduce GPU load."
    else:
        info_label.text = "Balanced mode saved. Battlefield lighting and directional shadows are enabled."

func _unhandled_key_input(event):
    if event.is_action_pressed("ui_cancel"):
        get_tree().quit()
