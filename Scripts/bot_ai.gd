extends Node

var think_timer := 0.0
var strafe_sign := 1.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    set_physics_process(true)

func _physics_process(delta: float) -> void:
    if not multiplayer.is_server():
        return
    var bot := get_parent()
    if not is_instance_valid(bot) or bot.is_dead or bot.is_downed:
        return

    think_timer -= delta
    var target: Node3D = null
    var best_distance := 100.0
    for candidate in get_tree().get_nodes_in_group("player"):
        if candidate == bot or not is_instance_valid(candidate):
            continue
        if candidate.is_dead or candidate.is_downed or candidate.team_id == bot.team_id:
            continue
        var distance := bot.global_position.distance_to(candidate.global_position)
        if distance < best_distance:
            best_distance = distance
            target = candidate

    if target == null:
        bot.server_move_input = Vector2.ZERO
        return

    var offset := target.global_position - bot.global_position
    offset.y = 0.0
    var desired_yaw := atan2(-offset.x, -offset.z)
    bot.server_camera_yaw = desired_yaw

    if best_distance > 14.0:
        bot.server_move_input = Vector2(0.0, -1.0)
        bot.server_sprint = best_distance > 30.0
    else:
        bot.server_move_input = Vector2(strafe_sign * 0.55, 0.0)
        bot.server_sprint = false

    if think_timer <= 0.0:
        think_timer = rng.randf_range(0.55, 1.0)
        if best_distance <= float(bot.bullet_range):
            var origin := bot.global_position + Vector3(0, 1.5, 0)
            var aim := (target.global_position + Vector3(0, 1.0, 0) - origin).normalized()
            bot.call("_server_fire", aim)
        if rng.randf() < 0.35:
            strafe_sign *= -1.0
