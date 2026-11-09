extends CanvasLayer

class MinimapVisual extends Control:
    var player: Node3D
    var refresh_timer := 0.0
    func _process(delta: float):
        refresh_timer += delta
        if refresh_timer >= 0.2:
            refresh_timer = 0.0
            queue_redraw()
    func _draw():
        var center := size / 2.0
        draw_circle(center, 67.0, Color(0.025, 0.07, 0.09, 0.82))
        draw_arc(center, 67.0, 0.0, TAU, 64, Color(0.55, 0.85, 0.88, 0.9), 2.0)
        draw_line(Vector2(center.x - 60, center.y), Vector2(center.x + 60, center.y), Color(0.45, 0.65, 0.68, 0.25), 1.0)
        draw_line(Vector2(center.x, center.y - 60), Vector2(center.x, center.y + 60), Color(0.45, 0.65, 0.68, 0.25), 1.0)
        if player == null or not is_instance_valid(player):
            return
        var rules = get_tree().get_first_node_in_group("match_rules")
        if rules != null and not rules.tactical_mode:
            var zone_center := center + Vector2(-player.global_position.x, player.global_position.z) * 0.72
            var zone_radius := clampf(float(rules.safe_zone_radius) * 0.72, 5.0, 65.0)
            draw_arc(zone_center, zone_radius, 0.0, TAU, 64, Color(0.25, 0.8, 1.0, 0.9), 2.0)
        for other in get_tree().get_nodes_in_group("player"):
            if not is_instance_valid(other) or other.is_dead:
                continue
            var offset := Vector2(other.global_position.x - player.global_position.x, -(other.global_position.z - player.global_position.z)) * 0.72
            if offset.length() > 61.0:
                continue
            var dot_color := Color("#ffe06a") if other == player else (Color("#42d9a0") if other.team_id == player.team_id else Color("#ff6666"))
            draw_circle(center + offset, 4.5 if other == player else 3.5, dot_color)
        draw_colored_polygon(PackedVector2Array([center + Vector2(0, -9), center + Vector2(-5, 6), center + Vector2(5, 6)]), Color.WHITE)

class JoystickVisual extends Control:
    var value := Vector2.ZERO

    func _draw():
        var center = size / 2.0
        draw_circle(center, 72, Color(0.05, 0.08, 0.10, 0.45))
        draw_arc(center, 72, 0, TAU, 64, Color(0.8, 0.9, 1, 0.65), 3)
        draw_circle(center + value * 42, 29, Color(0.35, 0.75, 1, 0.8))
        draw_arc(center + value * 42, 29, 0, TAU, 48, Color.WHITE, 2)

var player: CharacterBody3D
var joystick: JoystickVisual
var jump_button: Button
var fire_button: Button
var interact_button: Button
var weapon_button: Button
var revive_button: Button
var minimap: MinimapVisual
var hint_label: Label
var status_label: Label
var fps_label: Label
var fps_refresh := 0.0

var firing := false
var joystick_id := -1
var camera_id := -1
var jump_id := -1
var fire_id := -1
var interact_id := -1

var joystick_value := Vector2.ZERO
var screen_size := Vector2.ZERO
var last_weapon_visual_index := -1

const JOYSTICK_RADIUS := 65.0

func _ready():
    print("ZORIX MULTITOUCH SYSTEM READY")

    player = get_tree().get_first_node_in_group("local_player")
    screen_size = get_viewport().get_visible_rect().size

    var root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    joystick = JoystickVisual.new()
    joystick.size = Vector2(160, 160)
    joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(joystick)

    jump_button = Button.new()
    jump_button.text = "JUMP"
    jump_button.custom_minimum_size = Vector2(105, 85)
    jump_button.size = Vector2(105, 85)
    jump_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    jump_button.add_theme_font_size_override("font_size", 22)
    root.add_child(jump_button)

    fire_button = Button.new()
    fire_button.text = "FIRE"
    fire_button.custom_minimum_size = Vector2(115, 95)
    fire_button.size = Vector2(115, 95)
    fire_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fire_button.add_theme_font_size_override("font_size", 23)
    fire_button.add_theme_color_override("font_color", Color.WHITE)
    fire_button.add_theme_color_override("font_pressed_color", Color("#ffccaa"))
    root.add_child(fire_button)

    interact_button = Button.new()
    interact_button.text = "INTERACT"
    interact_button.custom_minimum_size = Vector2(112, 66)
    interact_button.size = Vector2(112, 66)
    interact_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    interact_button.add_theme_font_size_override("font_size", 16)
    root.add_child(interact_button)

    weapon_button = Button.new()
    weapon_button.text = "WEAPON"
    weapon_button.custom_minimum_size = Vector2(112, 58)
    weapon_button.size = Vector2(112, 58)
    weapon_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    weapon_button.add_theme_font_size_override("font_size", 15)
    root.add_child(weapon_button)

    revive_button = Button.new()
    revive_button.text = "REVIVE"
    revive_button.custom_minimum_size = Vector2(112, 58)
    revive_button.size = Vector2(112, 58)
    revive_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    revive_button.add_theme_font_size_override("font_size", 15)
    root.add_child(revive_button)

    minimap = MinimapVisual.new()
    minimap.size = Vector2(140, 140)
    minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(minimap)

    fps_label = Label.new()
    fps_label.text = "FPS --"
    fps_label.position = Vector2(18, 44)
    fps_label.add_theme_font_size_override("font_size", 12)
    fps_label.add_theme_color_override("font_color", Color("#a9d9e8"))
    root.add_child(fps_label)

    status_label = Label.new()
    status_label.text = "HP 100  |  AMMO 30/120"
    status_label.position = Vector2(18, 18)
    status_label.add_theme_font_size_override("font_size", 17)
    status_label.add_theme_color_override("font_color", Color.WHITE)
    root.add_child(status_label)

    hint_label = Label.new()
    hint_label.text = "SWIPE TO LOOK"
    hint_label.add_theme_color_override("font_color", Color.WHITE)
    hint_label.add_theme_font_size_override("font_size", 14)
    root.add_child(hint_label)

    get_viewport().size_changed.connect(update_size)
    update_size()

func update_size():
    screen_size = get_viewport().get_visible_rect().size

    if joystick == null:
        return

    joystick.position = Vector2(35, screen_size.y - 195)
    jump_button.position = Vector2(screen_size.x - 135, screen_size.y - 115)
    fire_button.position = Vector2(screen_size.x - 155, screen_size.y - 235)
    interact_button.position = Vector2(screen_size.x - 285, screen_size.y - 112)
    weapon_button.position = Vector2(screen_size.x - 290, screen_size.y - 235)
    revive_button.position = Vector2(screen_size.x - 410, screen_size.y - 112)
    minimap.position = Vector2(screen_size.x - 155, 70)
    hint_label.position = Vector2(screen_size.x - 180, screen_size.y - 180)

func get_player():
    if player == null or not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("local_player")
    return player

func update_joystick(pos: Vector2):
    var center = joystick.position + joystick.size / 2.0
    var difference = pos - center

    joystick_value = (difference / JOYSTICK_RADIUS).limit_length(1.0)
    joystick.value = joystick_value
    joystick.queue_redraw()

    var p = get_player()
    if p != null:
        p.set_mobile_move(joystick_value)

func reset_joystick():
    joystick_id = -1
    joystick_value = Vector2.ZERO
    joystick.value = Vector2.ZERO
    joystick.queue_redraw()

    var p = get_player()
    if p != null:
        p.set_mobile_move(Vector2.ZERO)

func _input(event):
    if event is InputEventScreenTouch:

        if event.pressed:
            # JUMP TOUCH
            if jump_id == -1 and jump_button.get_global_rect().has_point(event.position):
                jump_id = event.index
                _jump()
                hint_label.text = "JUMP!"
                get_viewport().set_input_as_handled()
                return

            # FIRE TOUCH
            if fire_id == -1 and fire_button.get_global_rect().has_point(event.position):
                fire_id = event.index
                _fire()
                hint_label.text = "FIRING!"
                get_viewport().set_input_as_handled()
                return

            # INTERACT TOUCH
            if interact_id == -1 and interact_button.get_global_rect().has_point(event.position):
                interact_id = event.index
                _interact()
                get_viewport().set_input_as_handled()
                return

            if weapon_button.get_global_rect().has_point(event.position):
                _switch_weapon()
                get_viewport().set_input_as_handled()
                return

            if revive_button.get_global_rect().has_point(event.position):
                _revive()
                get_viewport().set_input_as_handled()
                return

            # JOYSTICK TOUCH
            if joystick_id == -1 and event.position.x < screen_size.x * 0.5:
                joystick_id = event.index
                update_joystick(event.position)
                get_viewport().set_input_as_handled()
                return

            # CAMERA TOUCH
            if camera_id == -1 and event.position.x > screen_size.x * 0.55:
                camera_id = event.index
                get_viewport().set_input_as_handled()
                return

        else:
            # RELEASE JOYSTICK
            if event.index == joystick_id:
                reset_joystick()

            # RELEASE FIRE
            if event.index == fire_id:
                fire_id = -1
                _stop_fire()

            # RELEASE JUMP
            if event.index == jump_id:
                jump_id = -1

            # RELEASE CAMERA
            if event.index == camera_id:
                camera_id = -1

            if event.index == interact_id:
                interact_id = -1

    elif event is InputEventScreenDrag:

        if event.index == joystick_id:
            update_joystick(event.position)
            get_viewport().set_input_as_handled()

        elif event.index == camera_id:
            var p = get_player()
            if p != null:
                p.rotate_camera(event.relative.x, event.relative.y)
            get_viewport().set_input_as_handled()

func _jump():
    var p = get_player()
    if p != null:
        p.jump()
        print("ZORIX JUMP EXECUTED")

func _fire():
    firing = true
    var p = get_player()
    if p != null:
        if p.ammo <= 0:
            if multiplayer.is_server():
                p.reload_weapon()
            else:
                p.request_reload.rpc_id(1)
        else:
            p.shoot()

func _switch_weapon():
    var p = get_player()
    if p != null:
        p.switch_weapon(1)
        hint_label.text = "WEAPON: " + str(p.get_weapon_data().name)

func _revive():
    var p = get_player()
    if p != null:
        p.try_revive_nearby()
        hint_label.text = "REVIVE REQUEST SENT"

func _interact():
    var rules = get_tree().get_first_node_in_group("match_rules")
    if rules != null and rules.has_method("interact"):
        rules.interact()

func _stop_fire():
    firing = false

func _process(delta):
    fps_refresh += delta
    if fps_refresh >= 0.5:
        fps_refresh = 0.0
        if fps_label != null:
            fps_label.text = "FPS %d" % Engine.get_frames_per_second()
    var p = get_player()
    if p != null and p.current_weapon_index != last_weapon_visual_index:
        last_weapon_visual_index = p.current_weapon_index
        p.refresh_gun_model()
    if firing and p != null and not p.is_dead:
        p.shoot()
    if p != null and status_label != null:
        var weapon_data: Dictionary = p.get_weapon_data()
        var status = "HP %d  |  %s %d/%d" % [p.health, str(weapon_data.name), p.ammo, p.reserve_ammo]
        if p.is_downed:
            status += "  |  DOWNED %.0fs" % p.downed_timer
        elif p.is_dead:
            status += "  |  ELIMINATED"
        if weapon_button != null:
            weapon_button.text = str(weapon_data.name)
        var rules = get_tree().get_first_node_in_group("match_rules")
        if rules != null:
            if minimap != null:
                minimap.visible = not rules.tactical_mode
                minimap.player = p
            if rules.tactical_mode:
                if rules.bomb_planted and not rules.bomb_defused and not rules.bomb_exploded:
                    status += "  |  BOMB %.0f s" % rules.bomb_timer
                elif rules.bomb_defused:
                    status += "  |  DEFUSED"
                elif rules.bomb_exploded:
                    status += "  |  EXPLODED"
            else:
                status += "  |  ZONE %.0f m" % rules.safe_zone_radius
        status_label.text = status
