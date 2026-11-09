extends Node
class_name ZorixMatchmakingClient

signal status_received(data: Dictionary)
signal request_failed(message: String)

var project_url := ""
var anon_key := ""
var access_token := ""
var user_id := ""

func configure(url: String, key: String) -> void:
	project_url = url.strip_edges().trim_suffix("/")
	anon_key = key.strip_edges()

func is_configured() -> bool:
	return project_url.begins_with("https://") and not anon_key.is_empty()

func sign_in_anonymously() -> bool:
	if not is_configured():
		request_failed.emit("Supabase URL and anon key are not configured.")
		return false
	var response := await _request("/auth/v1/signup", {"data": {}}, false)
	if response.is_empty():
		return false
	access_token = str(response.get("access_token", ""))
	user_id = str(response.get("user", {}).get("id", ""))
	if access_token.is_empty():
		request_failed.emit("Anonymous sign-in failed. Enable Anonymous Auth in Supabase.")
		return false
	return true

func join_queue(mode: String) -> void:
	await _ensure_session()
	if access_token.is_empty(): return
	var result := await _rpc("zorix_join_queue", {"p_mode": mode})
	if not result.is_empty(): status_received.emit(result)

func leave_queue() -> void:
	if access_token.is_empty(): return
	var result := await _rpc("zorix_leave_queue", {})
	if not result.is_empty(): status_received.emit(result)

func refresh_status() -> void:
	if access_token.is_empty(): return
	var result := await _rpc("zorix_queue_status", {})
	if not result.is_empty(): status_received.emit(result)

func _ensure_session() -> void:
	if access_token.is_empty():
		await sign_in_anonymously()

func _rpc(function_name: String, payload: Dictionary) -> Dictionary:
	return await _request("/rest/v1/rpc/" + function_name, payload, true)

func _request(path: String, payload: Dictionary, authenticated: bool) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + anon_key
	])
	if authenticated and not access_token.is_empty():
		headers.append("Authorization: Bearer " + access_token)
	var error := http.request(project_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		http.queue_free()
		request_failed.emit("Network request could not start: " + error_string(error))
		return {}
	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	var body := result[3].get_string_from_utf8()
	if code < 200 or code >= 300:
		request_failed.emit("Backend HTTP " + str(code) + ": " + body)
		return {}
	var parsed = JSON.parse_string(body)
	if parsed is Dictionary:
		return parsed
	return {}
