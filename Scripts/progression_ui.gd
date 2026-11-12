extends Node

var account: Node
var parent: VBoxContainer
var request: HTTPRequest
var status_label: Label
var wallet_label: Label
var rank_label: Label
var level_label: Label
var prime_label: Label
var store_box: VBoxContainer
var panel: PanelContainer

func build_ui(target: VBoxContainer, player_account: Node) -> void:
    parent = target
    account = player_account
    request = HTTPRequest.new()
    request.timeout = 20.0
    add_child(request)
    request.request_completed.connect(_on_request_completed)

    var open_button := Button.new()
    open_button.text = "RANK • LEVEL • PRIME • STORE"
    open_button.custom_minimum_size.y = 50
    open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    open_button.pressed.connect(_toggle_panel)
    parent.add_child(open_button)

    panel = PanelContainer.new()
    panel.visible = false
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#142631")
    style.border_color = Color("#c79b4b")
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 14
    style.content_margin_bottom = 14
    panel.add_theme_stylebox_override("panel", style)
    parent.add_child(panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    panel.add_child(column)

    var title := Label.new()
    title.text = "ZORIX PLAYER PROGRESSION"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color("#f0c477"))
    column.add_child(title)

    rank_label = _label(column, "Rank: Loading...")
    level_label = _label(column, "Level: Loading...")
    prime_label = _label(column, "Prime: Loading...")
    wallet_label = _label(column, "Wallet: Loading...")
    status_label = _label(column, "Login to load your online rewards.")
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var refresh := Button.new()
    refresh.text = "REFRESH REWARDS"
    refresh.pressed.connect(_load_progression)
    column.add_child(refresh)

    var claim := Button.new()
    claim.text = "PRIME 10 • CLAIM 900 BLACK DIAMONDS / MONTH"
    claim.pressed.connect(_claim_monthly)
    column.add_child(claim)

    var store_title := Label.new()
    store_title.text = "DIAMOND STORE"
    store_title.add_theme_color_override("font_color", Color("#62d6c6"))
    column.add_child(store_title)

    store_box = VBoxContainer.new()
    column.add_child(store_box)

func _label(target: VBoxContainer, value: String) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_color_override("font_color", Color("#e4edf0"))
    target.add_child(label)
    return label

func _toggle_panel() -> void:
    panel.visible = not panel.visible
    if panel.visible:
        _load_progression()

func _headers() -> PackedStringArray:
    return PackedStringArray(["Authorization: Bearer " + str(account.get("token")), "Content-Type: application/json"])

func _request_api(path: String, method: int = HTTPClient.METHOD_GET) -> void:
    if account == null or str(account.get("token")).is_empty():
        status_label.text = "Please login with Google or Guest first."
        return
    var base := str(account.get("api_base_url")).trim_suffix("/")
    var err := request.request(base + path, _headers(), method)
    if err != OK:
        status_label.text = "API request failed: " + error_string(err)

func _load_progression() -> void:
    _request_api("/api/progression")

func _load_store() -> void:
    _request_api("/api/store/catalog")

func _claim_monthly() -> void:
    _request_api("/api/prime/claim-monthly", HTTPClient.METHOD_POST)

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        status_label.text = "Network error while loading rewards."
        return
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if code < 200 or code >= 300:
        status_label.text = str(parsed.get("detail", "Request failed")) if parsed is Dictionary else "Request failed."
        return
    if not parsed is Dictionary:
        status_label.text = "Invalid progression response."
        return
    if parsed.has("progression"):
        var p: Dictionary = parsed["progression"]
        rank_label.text = "RANK: %s  •  %s RP" % [str(p.get("rank", "Bronze")), str(p.get("rank_points", 0))]
        level_label.text = "LEVEL: %d  •  EXP: %d / %d" % [int(p.get("level", 1)), int(p.get("exp", 0)), int(p.get("next_level_exp", 0))]
        prime_label.text = "PRIME: %d / 10  •  PRIME EXP: %d / %d" % [int(p.get("prime_level", 0)), int(p.get("prime_exp", 0)), int(p.get("next_prime_exp", 0))]
        wallet_label.text = "COINS %d  |  RED %d  |  PINK %d  |  BLACK %d" % [int(p.get("coins", 0)), int(p.get("red_diamonds", 0)), int(p.get("pink_diamonds", 0)), int(p.get("black_diamonds", 0))]
        status_label.text = "Match rewards and level-up gifts are credited by the game server."
        _load_store()
    elif parsed.has("wallet") and parsed.has("items"):
        wallet_label.text = "COINS %d  |  RED %d  |  PINK %d  |  BLACK %d" % [int(parsed["wallet"].get("coins", 0)), int(parsed.wallet.get("red_diamonds", 0)), int(parsed.wallet.get("pink_diamonds", 0)), int(parsed.wallet.get("black_diamonds", 0))]
        for child in store_box.get_children():
            child.queue_free()
        for item in parsed["items"]:
            var row := HBoxContainer.new()
            var label := Label.new()
            label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            label.text = "%s  •  %s %d" % [str(item.get("name", item.get("item_id", "Item"))), str(item.get("currency", "")).to_upper(), int(item.get("price", 0))]
            row.add_child(label)
            var buy := Button.new()
            buy.text = "OWNED" if bool(item.get("owned", false)) else "BUY"
            buy.disabled = bool(item.get("owned", false))
            var item_id := str(item.get("item_id", ""))
            buy.pressed.connect(func(): _buy_item(item_id))
            row.add_child(buy)
            store_box.add_child(row)
        status_label.text = "Store loaded. Purchases use your online wallet."
    elif parsed.get("ok", false):
        status_label.text = "Reward claimed successfully."
        _load_progression()

func _buy_item(item_id: String) -> void:
    if item_id.is_empty():
        return
    _request_api("/api/store/purchase/" + item_id, HTTPClient.METHOD_POST)
