extends Node
# Original ZORIX runtime graphics/audio controller. Audio is synthesized locally;
# no third-party game recordings, music, textures, or proprietary assets are used.

const SETTINGS_PATH := "user://zorix_settings.cfg"
const QUALITY_LEVELS := ["low", "balanced", "hd", "ultra"]
const FPS_LEVELS := [30, 60, 90, 120]
var quality := "balanced"
var fps_limit := 60
var master_volume := 1.0
var music_volume := 0.65
var sfx_volume := 0.85
var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer

func _ready() -> void:
    _ensure_bus("Music")
    _ensure_bus("SFX")
    _load_settings()
    get_tree().node_added.connect(_on_node_added)
    apply_graphics_quality(quality)
    apply_fps_limit(fps_limit)
    _apply_audio_levels()

func _ensure_bus(bus_name: String) -> void:
    if AudioServer.get_bus_index(bus_name) >= 0:
        return
    AudioServer.add_bus()
    AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
    AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

func _load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) == OK:
        quality = str(cfg.get_value("graphics", "quality", "balanced"))
        if quality not in QUALITY_LEVELS:
            quality = "balanced"
        fps_limit = int(cfg.get_value("graphics", "fps_limit", 60))
        master_volume = float(cfg.get_value("audio", "master", 1.0))
        music_volume = float(cfg.get_value("audio", "music", 0.65))
        sfx_volume = float(cfg.get_value("audio", "sfx", 0.85))

func save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("graphics", "quality", quality)
    cfg.set_value("graphics", "fps_limit", fps_limit)
    cfg.set_value("audio", "master", master_volume)
    cfg.set_value("audio", "music", music_volume)
    cfg.set_value("audio", "sfx", sfx_volume)
    cfg.save(SETTINGS_PATH)

func apply_graphics_quality(value: String) -> void:
    quality = value if value in QUALITY_LEVELS else "balanced"
    var shadows := quality in ["hd", "ultra"]
    for node in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
        node.shadow_enabled = shadows
    for node in get_tree().root.find_children("*", "OmniLight3D", true, false):
        node.shadow_enabled = shadows and quality == "ultra"
    for node in get_tree().root.find_children("*", "SpotLight3D", true, false):
        node.shadow_enabled = shadows and quality == "ultra"
    save_settings()

func apply_fps_limit(value: int) -> void:
    fps_limit = FPS_LEVELS[clampi(FPS_LEVELS.find(value), 0, FPS_LEVELS.size() - 1)]
    Engine.max_fps = fps_limit
    save_settings()

func set_master_volume(value: float) -> void:
    master_volume = clampf(value, 0.0, 1.0)
    _apply_audio_levels()
    save_settings()

func set_music_volume(value: float) -> void:
    music_volume = clampf(value, 0.0, 1.0)
    _apply_audio_levels()
    save_settings()

func set_sfx_volume(value: float) -> void:
    sfx_volume = clampf(value, 0.0, 1.0)
    _apply_audio_levels()
    save_settings()

func _apply_audio_levels() -> void:
    _set_bus_level("Master", master_volume)
    _set_bus_level("Music", music_volume)
    _set_bus_level("SFX", sfx_volume)

func _set_bus_level(bus_name: String, value: float) -> void:
    var index := AudioServer.get_bus_index(bus_name)
    if index >= 0:
        AudioServer.set_bus_mute(index, value <= 0.001)
        AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))

func play_sfx(event_name: String, world_position: Vector3 = Vector3.ZERO) -> void:
    var stream := _make_original_sound(event_name)
    if stream == null:
        return
    var player := AudioStreamPlayer.new()
    player.bus = "SFX"
    player.stream = stream
    add_child(player)
    _players.append(player)
    player.finished.connect(func():
        _players.erase(player)
        player.queue_free()
    )
    player.play()

func play_lobby_music() -> void:
    if _music_player != null and is_instance_valid(_music_player):
        return
    _music_player = AudioStreamPlayer.new()
    _music_player.bus = "Music"
    _music_player.stream = _make_original_sound("lobby_music")
    add_child(_music_player)
    _music_player.play()

func stop_lobby_music() -> void:
    if _music_player != null and is_instance_valid(_music_player):
        _music_player.stop()
        _music_player.queue_free()
        _music_player = null

func _make_original_sound(event_name: String) -> AudioStreamWAV:
    var sample_rate := 22050
    var duration := 0.18
    var loop_music := event_name == "lobby_music"
    if event_name == "explosion":
        duration = 0.85
    elif event_name == "vehicle":
        duration = 0.42
    elif loop_music:
        duration = 4.0
    elif event_name == "footstep":
        duration = 0.11
    elif event_name == "reload":
        duration = 0.32
    elif event_name != "gun_fire":
        return null
    var count := int(sample_rate * duration)
    var bytes := PackedByteArray()
    bytes.resize(count * 2)
    for i in range(count):
        var t := float(i) / sample_rate
        var envelope := 1.0 - float(i) / count
        var wave := 0.0
        if event_name == "gun_fire":
            wave = (sin(TAU * (95.0 - 55.0 * t) * t) * 0.38 + _noise(i) * 0.62) * envelope
        elif event_name == "reload":
            var click := sin(TAU * (i % 4200) / 4200.0 * 780.0)
            wave = click * (0.20 if (i < count * 0.35 or i > count * 0.68) else 0.0) * envelope
        elif event_name == "footstep":
            wave = (sin(TAU * 72.0 * t) * 0.55 + _noise(i) * 0.45) * envelope
        elif event_name == "explosion":
            wave = (sin(TAU * (48.0 - 32.0 * t) * t) * 0.65 + _noise(i) * 0.55) * envelope * envelope
        elif event_name == "vehicle":
            wave = (sin(TAU * 68.0 * t) * 0.45 + sin(TAU * 136.0 * t) * 0.16 + _noise(i) * 0.08) * (0.72 + 0.28 * sin(TAU * 2.0 * t))
        elif loop_music:
            var notes := [261.63, 329.63, 392.0, 523.25, 392.0, 329.63, 293.66, 349.23]
            var note := notes[int(t * 2.0) % notes.size()]
            wave = (sin(TAU * note * t) * 0.14 + sin(TAU * note * 0.5 * t) * 0.08) * 0.8
        bytes.encode_s16(i * 2, int(clampf(wave, -1.0, 1.0) * 32767.0))
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = bytes
    if loop_music:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = count
    return stream

func _noise(seed: int) -> float:
    return sin(float(seed) * 12.9898) * 0.55 + sin(float(seed) * 78.233) * 0.45

func _on_node_added(node: Node) -> void:
    if node is DirectionalLight3D:
        node.shadow_enabled = quality in ["hd", "ultra"]
    elif node is OmniLight3D or node is SpotLight3D:
        node.shadow_enabled = quality == "ultra"
