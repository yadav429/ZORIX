extends CanvasLayer

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
    if firing and p != null and not p.is_dead:
        p.shoot()
    if p != null and status_label != null:
        var status = "HP %d  |  AMMO %d/%d" % [p.health, p.ammo, p.reserve_ammo]
        if p.is_dead:
            status += "  |  ELIMINATED"
        var rules = get_tree().get_first_node_in_group("match_rules")
        if rules != null:
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
