extends Node
## Dedicated-server registration, heartbeats and one-time ticket validation.
## Secrets are read from environment variables; never embed them in the client APK.

signal peer_authenticated(peer_id: int, player_id: int, match_id: int, team_number: int, mode: String)
signal peer_rejected(peer_id: int, reason: String)
signal join_validation_received(accepted: bool, message: String)

const HEARTBEAT_SECONDS := 12.0
var api_base_url := ""
var server_secret := ""
var server_id := ""
var public_host := ""
var region := "india"
var register_request: HTTPRequest
var heartbeat_request: HTTPRequest
var heartbeat_timer: Timer
var active_players: Dictionary = {}
var is_server_agent := false
var match_locked := false

func _ready() -> void:
    is_server_agent = OS.has_feature("dedicated_server") or OS.get_cmdline_user_args().has("--server")
    if is_server_agent:
        call_deferred("start_server_agent")

func start_server_agent() -> void:
    api_base_url = OS.get_environment("ZORIX_API_URL").trim_suffix("/")
    server_secret = OS.get_environment("ZORIX_SERVER_SECRET")
    public_host = _arg_value("--public-host=", OS.get_environment("ZORIX_PUBLIC_HOST"))
    region = OS.get_environment("ZORIX_SERVER_REGION")
    if region.is_empty():
        region = "india"
    if api_base_url.is_empty() or not api_base_url.begins_with("https://"):
        push_error("ZORIX server agent: ZORIX_API_URL must be an HTTPS URL.")
        return
    if server_secret.length() < 32:
        push_error("ZORIX server agent: ZORIX_SERVER_SECRET must be at least 32 characters.")
        return
    if public_host.is_empty():
        push_error("ZORIX server agent: set ZORIX_PUBLIC_HOST or --public-host.")
        return

    register_request = HTTPRequest.new()
    register_request.timeout = 15.0
    add_child(register_request)
    register_request.request_completed.connect(_on_register_completed)

    heartbeat_request = HTTPRequest.new()
    heartbeat_request.timeout = 10.0
    add_child(heartbeat_request)

    heartbeat_timer = Timer.new()
    heartbeat_timer.wait_time = HEARTBEAT_SECONDS
    heartbeat_timer.timeout.connect(_send_heartbeat)
    add_child(heartbeat_timer)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.peer_connected.connect(_on_transport_peer_connected)

    _register_server()

func _arg_value(prefix: String, fallback: String) -> String:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with(prefix):
            return argument.trim_prefix(prefix)
    return fallback

func _server_headers() -> PackedStringArray:
    return PackedStringArray([
        "Content-Type: application/json",
        "X-Zorix-Server-Secret: " + server_secret
    ])

func _register_server() -> void:
    var port := int(_arg_value("--port=", "24560"))
    var max_players := int(_arg_value("--max-players=", "50"))
    var payload := {
        "name": OS.get_environment("ZORIX_SERVER_NAME") if not OS.get_environment("ZORIX_SERVER_NAME").is_empty() else "zorix-br-" + str(OS.get_process_id()),
        "host": public_host,
        "port": port,
        "mode": "battle_royale",
        "region": region,
        "max_players": clampi(max_players, 2, 50)
    }
    var err := register_request.request(api_base_url + "/api/internal/servers/register", _server_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))
    if err != OK:
        push_error("ZORIX server registration request failed: " + error_string(err))

func _on_register_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
        push_error("ZORIX server registration rejected (HTTP %d): %s" % [code, body.get_string_from_utf8()])
        return
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if not parsed is Dictionary or not parsed.has("server_id"):
        push_error("ZORIX server registration response was invalid.")
        return
    server_id = str(parsed["server_id"])
    print("ZORIX SERVER FLEET REGISTERED | id=" + server_id)
    _send_heartbeat()
    heartbeat_timer.start()

func _send_heartbeat() -> void:
    if server_id.is_empty() or heartbeat_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        return
    var peers := multiplayer.get_peers().size() if multiplayer.multiplayer_peer != null else 0
    var payload := {"active_players": peers, "reserved_players": 50 if match_locked else 0}
    var headers := _server_headers()
    headers.append("X-Zorix-Server-Id: " + server_id)
    var err := heartbeat_request.request(api_base_url + "/api/internal/servers/" + server_id + "/heartbeat", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
    if err != OK:
        push_warning("ZORIX heartbeat request failed: " + error_string(err))

## Called by the authenticated game client immediately after ENet connects.
func submit_join_ticket(ticket: String) -> void:
    if ticket.is_empty() or not multiplayer.has_multiplayer_peer():
        return
    request_join_validation.rpc_id(1, ticket)

@rpc("any_peer", "call_remote", "reliable")
func request_join_validation(ticket: String) -> void:
    if not multiplayer.is_server() or not is_server_agent:
        return
    var peer_id := multiplayer.get_remote_sender_id()
    if peer_id <= 0 or ticket.length() < 20 or active_players.has(peer_id):
        return
    var req := HTTPRequest.new()
    req.timeout = 12.0
    add_child(req)
    req.request_completed.connect(_on_ticket_consumed.bind(peer_id, req))
    var headers := _server_headers()
    headers.append("X-Zorix-Server-Id: " + server_id)
    var err := req.request(api_base_url + "/api/internal/join-ticket/consume", headers, HTTPClient.METHOD_POST, JSON.stringify({"ticket": ticket}))
    if err != OK:
        req.queue_free()
        multiplayer.multiplayer_peer.disconnect_peer(peer_id)
        peer_rejected.emit(peer_id, "Ticket validation request could not start.")

func _on_ticket_consumed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, peer_id: int, req: HTTPRequest) -> void:
    req.queue_free()
    if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
        join_validation_result.rpc_id(peer_id, false, "Join ticket invalid, expired or already used.")
        if multiplayer.multiplayer_peer != null:
            multiplayer.multiplayer_peer.disconnect_peer(peer_id)
        peer_rejected.emit(peer_id, "Join ticket invalid, expired or already used.")
        return
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if not parsed is Dictionary or not parsed.get("ok", false):
        join_validation_result.rpc_id(peer_id, false, "Join ticket response was invalid.")
        multiplayer.multiplayer_peer.disconnect_peer(peer_id)
        peer_rejected.emit(peer_id, "Join ticket response was invalid.")
        return
    var player_id := int(parsed.get("player_id", 0))
    var match_id := int(parsed.get("match_id", 0))
    var team_number := int(parsed.get("team_number", 0))
    if player_id <= 0 or match_id <= 0:
        join_validation_result.rpc_id(peer_id, false, "The API returned an invalid player or match identity.")
        multiplayer.multiplayer_peer.disconnect_peer(peer_id)
        return
    match_locked = true
    active_players[peer_id] = {"player_id": player_id, "match_id": match_id, "team_number": team_number, "mode": str(parsed.get("mode", "solo"))}
    peer_authenticated.emit(peer_id, player_id, match_id, team_number, str(parsed.get("mode", "solo")))
    join_validation_result.rpc_id(peer_id, true, "Verified")
    print("ZORIX PLAYER AUTHENTICATED | peer=%d player=%d match=%d team=%d" % [peer_id, player_id, match_id, team_number])

@rpc("authority", "call_remote", "reliable")
func join_validation_result(accepted: bool, message: String) -> void:
    join_validation_received.emit(accepted, message)
    if not accepted:
        push_error("ZORIX server rejected join ticket: " + message)

func report_match_results(match_id: int, winner_team_id: int) -> void:
    if not multiplayer.is_server() or not is_server_agent or server_id.is_empty():
        return
    for peer_id in active_players.keys():
        var player: Dictionary = active_players[peer_id]
        if int(player.match_id) != match_id:
            continue
        var node := get_tree().current_scene.get_node_or_null("Player_%d" % int(peer_id))
        if node == null:
            continue
        var placement := 1 if int(node.team_id) == winner_team_id else 2
        var req := HTTPRequest.new()
        req.timeout = 12.0
        add_child(req)
        req.request_completed.connect(func(_r, _c, _h, _b): req.queue_free())
        var headers := _server_headers()
        var payload := {
            "player_id": int(player.player_id),
            "match_id": str(match_id) + "-" + str(player.player_id),
            "placement": placement,
            "kills": int(node.kills)
        }
        var err := req.request(api_base_url + "/api/internal/match-result", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
        if err != OK:
            req.queue_free()

func report_active_match_results(winner_team_id: int) -> void:
    if active_players.is_empty():
        return
    var first: Dictionary = active_players.values()[0]
    report_match_results(int(first.get("match_id", 0)), winner_team_id)

func _on_peer_disconnected(peer_id: int) -> void:
    active_players.erase(peer_id)

func _on_transport_peer_connected(peer_id: int) -> void:
    _disconnect_if_not_authenticated(peer_id)

func _disconnect_if_not_authenticated(peer_id: int) -> void:
    await get_tree().create_timer(12.0).timeout
    if multiplayer.is_server() and not active_players.has(peer_id) and multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.disconnect_peer(peer_id)
