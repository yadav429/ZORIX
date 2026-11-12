extends Node

var account: Node
var request: HTTPRequest
var status_label: Label
var mode_picker: OptionButton
var team_name_input: LineEdit
var invite_input: LineEdit
var friend_id_input: LineEdit
var api_base := ""

func build_ui(parent: VBoxContainer, account_node: Node) -> void:
    account = account_node
    api_base = str(account.call("get_api_base_url")).trim_suffix("/")
    request = HTTPRequest.new()
    request.timeout = 20.0
    add_child(request)
    request.request_completed.connect(_on_request_completed)

    var title := Label.new()
    title.text = "FRIENDS • TEAM • MATCHMAKING"
    title.add_theme_color_override("font_color", Color("#62d6c6"))
    title.add_theme_font_size_override("font_size", 16)
    parent.add_child(title)

    mode_picker = OptionButton.new()
    mode_picker.add_item("SOLO • 1 PLAYER")
    mode_picker.add_item("DUO • 2 PLAYERS")
    mode_picker.add_item("SQUAD • 4 PLAYERS")
    mode_picker.select(2)
    mode_picker.custom_minimum_size.y = 46
    parent.add_child(mode_picker)

    var queue_button := _button("FIND MATCH", Color("#167c70"))
    queue_button.pressed.connect(_queue_match)
    parent.add_child(queue_button)
    var refresh_button := _button("REFRESH MATCH STATUS", Color("#254b61"))
    refresh_button.pressed.connect(_refresh_status)
    parent.add_child(refresh_button)

    team_name_input = LineEdit.new()
    team_name_input.placeholder_text = "New team name (3-24 characters)"
    team_name_input.custom_minimum_size.y = 44
    parent.add_child(team_name_input)
    var create_button := _button("CREATE DUO / SQUAD TEAM", Color("#8a4b25"))
    create_button.pressed.connect(_create_team)
    parent.add_child(create_button)

    invite_input = LineEdit.new()
    invite_input.placeholder_text = "Team invite code"
    invite_input.custom_minimum_size.y = 44
    parent.add_child(invite_input)
    var join_button := _button("JOIN TEAM WITH CODE", Color("#354454"))
    join_button.pressed.connect(_join_team)
    parent.add_child(join_button)
    var leave_button := _button("LEAVE CURRENT TEAM", Color("#713e3e"))
    leave_button.pressed.connect(_leave_team)
    parent.add_child(leave_button)
    var team_button := _button("MY TEAM", Color("#254b61"))
    team_button.pressed.connect(_my_team)
    parent.add_child(team_button)

    friend_id_input = LineEdit.new()
    friend_id_input.placeholder_text = "Friend Player ID (ZX-XXXXXXXX)"
    friend_id_input.custom_minimum_size.y = 44
    parent.add_child(friend_id_input)
    var add_friend_button := _button("SEND FRIEND REQUEST", Color("#167c70"))
    add_friend_button.pressed.connect(_send_friend_request)
    parent.add_child(add_friend_button)
    var friends_button := _button("MY FRIENDS / REQUESTS", Color("#254b61"))
    friends_button.pressed.connect(_list_friends)
    parent.add_child(friends_button)

    status_label = Label.new()
    status_label.text = "Login first. Duo/Squad requires a team; invite friends using their Player ID."
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_color_override("font_color", Color("#d8e5e6"))
    parent.add_child(status_label)

func _button(caption: String, color: Color) -> Button:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size.y = 46
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(10)
    b.add_theme_stylebox_override("normal", style)
    b.add_theme_stylebox_override("pressed", style.duplicate())
    return b

func _call_api(method: int, path: String, payload: Dictionary = {}) -> void:
    if account == null or not bool(account.call("is_logged_in")):
        status_label.text = "Please login with Google or Guest first."
        return
    var headers := PackedStringArray(["Authorization: Bearer " + str(account.call("get_auth_token")), "Content-Type: application/json"])
    var body := "" if method == HTTPClient.METHOD_GET or method == HTTPClient.METHOD_DELETE else JSON.stringify(payload)
    var err := request.request(api_base + path, headers, method, body)
    if err != OK:
        status_label.text = "Request could not start: " + error_string(err)

func _mode() -> String:
    return ["solo", "duo", "squad"][mode_picker.selected]

func _queue_match() -> void:
    _call_api(HTTPClient.METHOD_POST, "/api/matchmaking/queue", {"mode": _mode()})

func _refresh_status() -> void:
    _call_api(HTTPClient.METHOD_GET, "/api/matchmaking/status")

func _create_team() -> void:
    var mode := _mode()
    if mode == "solo":
        status_label.text = "Choose Duo or Squad before creating a team."
        return
    _call_api(HTTPClient.METHOD_POST, "/api/teams", {"name": team_name_input.text.strip_edges(), "mode": mode})

func _join_team() -> void:
    _call_api(HTTPClient.METHOD_POST, "/api/teams/join", {"invite_code": invite_input.text.strip_edges().to_upper()})

func _leave_team() -> void:
    _call_api(HTTPClient.METHOD_DELETE, "/api/teams/me")

func _my_team() -> void:
    _call_api(HTTPClient.METHOD_GET, "/api/teams/me")

func _send_friend_request() -> void:
    _call_api(HTTPClient.METHOD_POST, "/api/friends/request", {"public_id": friend_id_input.text.strip_edges().to_upper()})

func _list_friends() -> void:
    _call_api(HTTPClient.METHOD_GET, "/api/friends")

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        status_label.text = "Network error. Check internet/API connection."
        return
    var data = JSON.parse_string(body.get_string_from_utf8())
    if code < 200 or code >= 300:
        status_label.text = str(data.get("detail", "Request failed")) if data is Dictionary else "Request failed."
        return
    if not data is Dictionary:
        status_label.text = "Server response received."
        return
    if data.has("invite_code"):
        status_label.text = "Team created! Invite code: " + str(data["invite_code"]) + " • Share this with friends."
    elif data.has("team"):
        status_label.text = "Your team: " + (str(data["team"]) if data["team"] != null else "No active team")
    elif data.has("friends"):
        status_label.text = "Friends / requests: " + JSON.stringify(data["friends"])
    elif data.get("status", "") == "queued":
        status_label.text = "Matchmaking: " + str(data.get("mode", "")).to_upper() + " • Waiting players: " + str(data.get("players_waiting", ""))
    elif data.get("status", "") == "allocated":
        status_label.text = "MATCH FOUND! Server: " + JSON.stringify(data.get("server", {})) + " • Join ticket ready."
    elif data.get("status", "") == "waiting":
        status_label.text = "Queue active, waiting for enough players / available server."
    else:
        status_label.text = JSON.stringify(data)
