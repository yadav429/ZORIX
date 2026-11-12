extends Node

signal login_completed(player_name: String)
signal public_server_loaded(host: String, port: int)

const SETTINGS_PATH := "user://zorix_account.cfg"
const GOOGLE_WEB_CLIENT_ID := "12896414115-g4950lhr34mbcpugje8ga9kq8uufpl5b.apps.googleusercontent.com"
var request: HTTPRequest
var api_url_input: LineEdit
var status_label: Label
var google_button: Button
var guest_button: Button
var advanced_box: VBoxContainer
var google_sign_in: Object
var token := ""
var player_name := ""
var api_base_url := "https://zorix-player-api-dnz5.onrender.com"
var request_kind := "auth"

func _ready():
    request = HTTPRequest.new()
    request.timeout = 30.0
    add_child(request)
    request.request_completed.connect(_on_request_completed)
    _load_session()
    _connect_google_plugin()

func _connect_google_plugin():
    if OS.get_name() != "Android":
        return
    if not Engine.has_singleton("GodotGoogleSignIn"):
        return
    google_sign_in = Engine.get_singleton("GodotGoogleSignIn")
    if not google_sign_in.is_connected("sign_in_success", _on_google_sign_in_success):
        google_sign_in.connect("sign_in_success", _on_google_sign_in_success)
    if not google_sign_in.is_connected("sign_in_failed", _on_google_sign_in_failed):
        google_sign_in.connect("sign_in_failed", _on_google_sign_in_failed)

func build_ui(parent: VBoxContainer):
    var heading = Label.new()
    heading.text = "WELCOME TO ZORIX"
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 24)
    heading.add_theme_color_override("font_color", Color("#f3f7f4"))
    parent.add_child(heading)

    var subtitle = Label.new()
    subtitle.text = "CHOOSE HOW YOU WANT TO PLAY"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", Color("#62d6c6"))
    parent.add_child(subtitle)

    google_button = _make_login_button("CONTINUE WITH GOOGLE", Color("#f3f3f3"), Color("#20252a"))
    google_button.pressed.connect(_google_login)
    parent.add_child(google_button)

    guest_button = _make_login_button("PLAY AS GUEST", Color("#d9782d"), Color.WHITE)
    guest_button.pressed.connect(_guest_login)
    parent.add_child(guest_button)

    var advanced = Button.new()
    advanced.text = "ADVANCED • SERVER SETTINGS"
    advanced.flat = true
    advanced.custom_minimum_size.y = 38
    parent.add_child(advanced)

    advanced_box = VBoxContainer.new()
    advanced_box.visible = false
    parent.add_child(advanced_box)
    advanced.pressed.connect(func(): advanced_box.visible = not advanced_box.visible)

    var api_label = Label.new()
    api_label.text = "Account API URL"
    advanced_box.add_child(api_label)
    api_url_input = LineEdit.new()
    api_url_input.placeholder_text = "https://zorix-player-api-dnz5.onrender.com"
    api_url_input.text = api_base_url
    api_url_input.custom_minimum_size.y = 44
    advanced_box.add_child(api_url_input)

    status_label = Label.new()
    status_label.text = "Google Login aur Guest Login available hain."
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_color_override("font_color", Color("#d8e5e6"))
    parent.add_child(status_label)
    _set_busy(false)

func _make_login_button(caption: String, background: Color, foreground: Color) -> Button:
    var button = Button.new()
    button.text = caption
    button.custom_minimum_size.y = 54
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 16)
    button.add_theme_color_override("font_color", foreground)
    var style = StyleBoxFlat.new()
    style.bg_color = background
    style.set_corner_radius_all(12)
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    button.add_theme_stylebox_override("normal", style)
    var hover = style.duplicate()
    hover.bg_color = background.lightened(0.1)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    return button

func _load_session():
    var cfg = ConfigFile.new()
    if cfg.load(SETTINGS_PATH) == OK:
        token = str(cfg.get_value("account", "token", ""))
        player_name = str(cfg.get_value("account", "username", ""))
        api_base_url = str(cfg.get_value("account", "api_url", api_base_url))

func _save_session():
    var cfg = ConfigFile.new()
    cfg.set_value("account", "token", token)
    cfg.set_value("account", "username", player_name)
    cfg.set_value("account", "api_url", api_base_url)
    cfg.save(SETTINGS_PATH)

func _api_base() -> String:
    if api_url_input != null and not api_url_input.text.strip_edges().is_empty():
        api_base_url = api_url_input.text.strip_edges().trim_suffix("/")
    return api_base_url

func _guest_login():
    var base = _api_base()
    if not base.begins_with("https://"):
        status_label.text = "Advanced settings mein valid HTTPS API URL enter karein."
        return
    _set_busy(true)
    status_label.text = "Creating secure guest account..."
    request_kind = "guest"
    var err = request.request(base + "/api/guest", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, "{}")
    if err != OK:
        _set_busy(false)
        status_label.text = "Request start nahi hui: " + error_string(err)

func _google_login():
    if OS.get_name() != "Android":
        status_label.text = "Google Sign-In sirf Android app mein available hai."
        return
    _connect_google_plugin()
    if google_sign_in == null:
        status_label.text = "Google Sign-In plugin APK mein load nahi hua. Guest Login use kar sakte hain."
        return
    if not google_sign_in.isInitialized():
        google_sign_in.initialize(GOOGLE_WEB_CLIENT_ID)
    _set_busy(true)
    status_label.text = "Google account chooser opening..."
    google_sign_in.signInWithAccountChooser()

func _on_google_sign_in_success(id_token: String, email: String, display_name: String):
    if id_token.is_empty():
        _set_busy(false)
        status_label.text = "Google ne ID token return nahi kiya."
        return
    _set_busy(true)
    status_label.text = "Google account verify ho raha hai..."
    request_kind = "google"
    var payload = JSON.stringify({"id_token": id_token})
    var err = request.request(_api_base() + "/api/google", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, payload)
    if err != OK:
        _set_busy(false)
        status_label.text = "Google verification request start nahi hui: " + error_string(err)

func _on_google_sign_in_failed(error_message: String):
    _set_busy(false)
    status_label.text = "Google Sign-In failed: " + error_message

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
    _set_busy(false)
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if result != HTTPRequest.RESULT_SUCCESS:
        status_label.text = "Network error. Internet aur API URL check karein."
        return
    if code < 200 or code >= 300:
        status_label.text = str(parsed.get("detail", "Login failed")) if parsed is Dictionary else "Request failed."
        return
    if request_kind == "lobby":
        var servers: Array = parsed.get("servers", []) if parsed is Dictionary else []
        if servers.is_empty():
            status_label.text = "Login successful: " + player_name + " • No public game server is online yet."
        else:
            var server: Dictionary = servers[0]
            var host := str(server.get("host", ""))
            var port := int(server.get("port", 24560))
            if not host.is_empty():
                status_label.text = "Login successful: " + player_name + " • Public server available."
                public_server_loaded.emit(host, port)
            else:
                status_label.text = "Account ready, but public server address is missing."
        login_completed.emit(player_name)
        return
    if not parsed is Dictionary or not parsed.has("token"):
        status_label.text = "Invalid account server response."
        return
    token = str(parsed["token"])
    var player_data: Dictionary = parsed.get("player", {})
    player_name = str(player_data.get("display_name", player_data.get("username", "Guest")))
    _save_session()
    status_label.text = "Welcome, " + player_name + " • Loading public lobby..."
    _load_public_lobby()

func _load_public_lobby():
    var headers = PackedStringArray(["Authorization: Bearer " + token])
    request_kind = "lobby"
    var err = request.request(_api_base() + "/api/lobby", headers, HTTPClient.METHOD_GET)
    if err != OK:
        status_label.text = "Lobby request start nahi hui: " + error_string(err)

func _set_busy(busy: bool):
    if guest_button != null:
        guest_button.disabled = busy
    if google_button != null:
        google_button.disabled = busy

func is_logged_in() -> bool:
    return not token.is_empty()

func get_player_name() -> String:
    return player_name

func get_public_server() -> Dictionary:
    return {}

func logout():
    token = ""
    player_name = ""
    _save_session()
    if status_label != null:
        status_label.text = "Logged out. Choose a login option."

func get_session_token() -> String:
    return token

func get_api_base_url() -> String:
    return _api_base()
