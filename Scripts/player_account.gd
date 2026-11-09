extends Node

signal login_completed(player_name: String)
signal public_server_loaded(host: String, port: int)
var request_kind := "auth"

const SETTINGS_PATH := "user://zorix_account.cfg"
var request: HTTPRequest
var api_url_input: LineEdit
var username_input: LineEdit
var password_input: LineEdit
var status_label: Label
var login_button: Button
var register_button: Button
var token := ""
var player_name := ""
var api_base_url := ""

func _ready():
    request = HTTPRequest.new()
    request.timeout = 15.0
    add_child(request)
    request.request_completed.connect(_on_request_completed)
    _load_session()

func build_ui(parent: VBoxContainer):
    var heading = Label.new()
    heading.text = "PLAYER ACCOUNT • PUBLIC ONLINE"
    heading.add_theme_color_override("font_color", Color("#62d6c6"))
    parent.add_child(heading)

    api_url_input = LineEdit.new()
    api_url_input.placeholder_text = "API URL (example: https://your-domain.com)"
    api_url_input.text = api_base_url
    api_url_input.custom_minimum_size.y = 46
    parent.add_child(api_url_input)

    username_input = LineEdit.new()
    username_input.placeholder_text = "Username (3-20 characters)"
    username_input.custom_minimum_size.y = 46
    parent.add_child(username_input)

    password_input = LineEdit.new()
    password_input.placeholder_text = "Password (minimum 8 characters)"
    password_input.secret = true
    password_input.custom_minimum_size.y = 46
    parent.add_child(password_input)

    var actions = HBoxContainer.new()
    parent.add_child(actions)
    register_button = Button.new()
    register_button.text = "REGISTER"
    register_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    register_button.custom_minimum_size.y = 48
    register_button.pressed.connect(func(): _send_auth("/api/register"))
    actions.add_child(register_button)
    login_button = Button.new()
    login_button.text = "LOGIN"
    login_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    login_button.custom_minimum_size.y = 48
    login_button.pressed.connect(func(): _send_auth("/api/login"))
    actions.add_child(login_button)

    status_label = Label.new()
    status_label.text = "Register or login to load the public lobby."
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_color_override("font_color", Color("#d8e5e6"))
    parent.add_child(status_label)
    _set_busy(false)

func _load_session():
    var cfg = ConfigFile.new()
    if cfg.load(SETTINGS_PATH) == OK:
        token = str(cfg.get_value("account", "token", ""))
        player_name = str(cfg.get_value("account", "username", ""))
        api_base_url = str(cfg.get_value("account", "api_url", ""))

func _save_session():
    var cfg = ConfigFile.new()
    cfg.set_value("account", "token", token)
    cfg.set_value("account", "username", player_name)
    cfg.set_value("account", "api_url", api_base_url)
    cfg.save(SETTINGS_PATH)

func _send_auth(path: String):
    api_base_url = api_url_input.text.strip_edges().trim_suffix("/")
    var username = username_input.text.strip_edges()
    var password = password_input.text
    if not api_base_url.begins_with("https://") and not api_base_url.begins_with("http://"):
        status_label.text = "Valid API URL enter karein (HTTPS recommended)."
        return
    if username.length() < 3 or password.length() < 8:
        status_label.text = "Username 3+ aur password 8+ characters hona chahiye."
        return
    var headers = PackedStringArray(["Content-Type: application/json"])
    var payload = JSON.stringify({"username": username, "password": password})
    _set_busy(true)
    status_label.text = "Connecting to ZORIX account service..."
    request_kind = "auth"
    var err = request.request(api_base_url + path, headers, HTTPClient.METHOD_POST, payload)
    if err != OK:
        _set_busy(false)
        status_label.text = "Request start nahi hui: " + error_string(err)

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
    _set_busy(false)
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if result != HTTPRequest.RESULT_SUCCESS:
        status_label.text = "Network error. API URL aur internet check karein."
        return
    if code < 200 or code >= 300:
        status_label.text = str(parsed.get("detail", "Login/Register failed")) if parsed is Dictionary else "Request failed."
        return
    if request_kind == "lobby":
        var servers = parsed.get("servers", []) if parsed is Dictionary else []
        if servers.size() > 0:
            var server_info = servers[0]
            status_label.text = "Public lobby ready • " + str(server_info.get("name", "ZORIX Server"))
            public_server_loaded.emit(str(server_info.get("host", "")), int(server_info.get("port", 24560)))
        else:
            status_label.text = str(parsed.get("message", "No public game server configured")) if parsed is Dictionary else "Invalid lobby response."
        return
    if not parsed is Dictionary or not parsed.has("token"):
        status_label.text = "Invalid account server response."
        return
    token = str(parsed["token"])
    player_name = str(parsed.get("player", {}).get("username", "Player"))
    _save_session()
    status_label.text = "Logged in: " + player_name + " • Loading public lobby..."
    _load_public_lobby()

func _load_public_lobby():
    var headers = PackedStringArray(["Authorization: Bearer " + token])
    request_kind = "lobby"
    var err = request.request(api_base_url + "/api/lobby", headers, HTTPClient.METHOD_GET)
    if err != OK:
        status_label.text = "Lobby request start nahi hui: " + error_string(err)

func _set_busy(busy: bool):
    if register_button != null:
        register_button.disabled = busy
    if login_button != null:
        login_button.disabled = busy

func is_logged_in() -> bool:
    return not token.is_empty()

func get_player_name() -> String:
    return player_name

func get_public_server() -> Dictionary:
    if status_label != null and status_label.text.find("No public game server configured") >= 0:
        return {}
    return {}

func logout():
    token = ""
    player_name = ""
    _save_session()
    if status_label != null:
        status_label.text = "Logged out. Login to continue."
