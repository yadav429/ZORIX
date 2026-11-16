extends Control
## ZORIX cosmetic store. Purchases use demo credits stored locally;
## connect these actions to the authenticated store API before enabling real payments.

signal closed

const SAVE_PATH := "user://zorix_store.cfg"
const STARTER_CREDITS := 5000
const ITEMS := [
    {"id":"agni_47","name":"AGNI-X • SOLAR FLARE","kind":"WEAPON SKIN","category":"WEAPON SKINS","price":1200,"rarity":"LEGENDARY","symbol":"🔥","description":"Gold heat-treated finish with ember detailing."},
    {"id":"rudra_99","name":"RUDRA-99 • STORM","kind":"WEAPON SKIN","category":"WEAPON SKINS","price":1800,"rarity":"MYTHIC","symbol":"⚡","description":"Dark steel, electric blue accents."},
    {"id":"trishul","name":"TRISHUL • ROYAL GUARD","kind":"WEAPON SKIN","category":"WEAPON SKINS","price":1500,"rarity":"EPIC","symbol":"🔱","description":"Ceremonial tricolour-inspired premium finish."},
    {"id":"garud_5","name":"GARUD-5 • NIGHT OPS","kind":"WEAPON SKIN","category":"WEAPON SKINS","price":1000,"rarity":"EPIC","symbol":"🦅","description":"Matte stealth finish for the battlefield."},
    {"id":"veer_bundle","name":"VEER COMMANDO BUNDLE","kind":"PREMIUM BUNDLE","category":"PREMIUM BUNDLES","price":2500,"rarity":"MYTHIC","symbol":"🪖","description":"Elite uniform, helmet, backpack and matching details."},
    {"id":"maharana_bundle","name":"MAHARANA ELITE BUNDLE","kind":"PREMIUM BUNDLE","category":"PREMIUM BUNDLES","price":2200,"rarity":"LEGENDARY","symbol":"🛡️","description":"Royal battle armour with a bold gold finish."},
    {"id":"vajra_car","name":"VAJRA • ARMOURED SUV","kind":"VEHICLE SKIN","category":"CAR SKINS","price":2000,"rarity":"LEGENDARY","symbol":"🚙","description":"Graphite bodywork with saffron accent stripes."},
    {"id":"tiger_car","name":"TIGER • DESERT RUNNER","kind":"VEHICLE SKIN","category":"CAR SKINS","price":1600,"rarity":"EPIC","symbol":"🏎️","description":"Desert-camo racing livery with rugged styling."}
]

var credits := STARTER_CREDITS
var owned: Array[String] = []
var equipped := {}
var active_category := "WEAPON SKINS"
var api_base_url := ""
var session_token := ""
var diamond_request: HTTPRequest
var diamond_label: Label
var balance_label: Label
var items_box: VBoxContainer

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _load_store()
    _build()

func configure_session(api_url: String, auth_token: String) -> void:
    api_base_url = api_url.trim_suffix("/")
    session_token = auth_token

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

func _build() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color("#07121b")
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)

    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.offset_left = 12
    scroll.offset_top = 12
    scroll.offset_right = -12
    scroll.offset_bottom = -12
    add_child(scroll)

    var outer := VBoxContainer.new()
    outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    outer.add_theme_constant_override("separation", 12)
    scroll.add_child(outer)

    var header := HBoxContainer.new()
    outer.add_child(header)
    var back := Button.new()
    back.text = "← BACK"
    back.custom_minimum_size = Vector2(92, 44)
    back.pressed.connect(func(): closed.emit(); queue_free())
    header.add_child(back)

    var title := Label.new()
    title.text = "ZORIX  •  STORE"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 23)
    title.add_theme_color_override("font_color", Color("#f0c477"))
    header.add_child(title)

    balance_label = Label.new()
    balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    balance_label.add_theme_font_size_override("font_size", 16)
    balance_label.add_theme_color_override("font_color", Color("#70e0bd"))
    outer.add_child(balance_label)
    _update_balance()

    var diamond_row := HBoxContainer.new()
    outer.add_child(diamond_row)
    diamond_label = Label.new()
    diamond_label.text = "💎 Diamonds: loading..."
    diamond_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    diamond_row.add_child(diamond_label)
    var upi_button := Button.new()
    upi_button.text = "100 💎  •  ₹30 UPI"
    upi_button.custom_minimum_size = Vector2(150, 48)
    upi_button.pressed.connect(_create_razorpay_link)
    diamond_row.add_child(upi_button)
    var play_button := Button.new()
    play_button.text = "GOOGLE PLAY BILLING"
    play_button.custom_minimum_size = Vector2(150, 48)
    play_button.disabled = true
    play_button.tooltip_text = "Native Google Play Billing SDK bridge is not yet included in this APK."
    diamond_row.add_child(play_button)
    diamond_request = HTTPRequest.new()
    diamond_request.timeout = 20.0
    add_child(diamond_request)
    diamond_request.request_completed.connect(_on_diamond_request_completed)
    _refresh_diamond_wallet()

    var subtitle := Label.new()
    subtitle.text = "PREMIUM COSMETICS  •  PERSONALIZE YOUR LOADOUT"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 11)
    subtitle.add_theme_color_override("font_color", Color("#9bb4bd"))
    outer.add_child(subtitle)

    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 6)
    outer.add_child(tabs)
    for category in ["WEAPON SKINS", "PREMIUM BUNDLES", "CAR SKINS"]:
        var tab := Button.new()
        tab.text = category
        tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab.custom_minimum_size.y = 48
        tab.add_theme_font_size_override("font_size", 10)
        tab.pressed.connect(_select_category.bind(category))
        tabs.add_child(tab)

    items_box = VBoxContainer.new()
    items_box.add_theme_constant_override("separation", 10)
    outer.add_child(items_box)
    _render_items()

    var note := Label.new()
    note.text = "Cosmetic purchases currently use demo Z-Coins. Diamond top-ups are server-verified; ₹30 UPI checkout credits 100 Diamonds after Razorpay webhook confirmation. Google Play native checkout is pending its Android Billing SDK bridge and Play Console product setup."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.add_theme_font_size_override("font_size", 11)
    note.add_theme_color_override("font_color", Color("#8ba1a9"))
    outer.add_child(note)

func _auth_headers() -> PackedStringArray:
    return PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + session_token])

func _refresh_diamond_wallet() -> void:
    if session_token.is_empty() or api_base_url.is_empty():
        diamond_label.text = "💎 Login required for online Diamond wallet"
        return
    var err := diamond_request.request(api_base_url + "/api/diamonds/wallet", _auth_headers(), HTTPClient.METHOD_GET)
    if err != OK:
        diamond_label.text = "💎 Wallet unavailable"

func _create_razorpay_link() -> void:
    if session_token.is_empty() or api_base_url.is_empty():
        diamond_label.text = "Please login to purchase Diamonds."
        return
    diamond_label.text = "Creating secure ₹30 UPI payment link..."
    var payload := JSON.stringify({"package_id": "diamonds_100"})
    var err := diamond_request.request(api_base_url + "/api/diamonds/razorpay/link", _auth_headers(), HTTPClient.METHOD_POST, payload)
    if err != OK:
        diamond_label.text = "Could not start UPI checkout."

func _on_diamond_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if result != HTTPRequest.RESULT_SUCCESS:
        diamond_label.text = "Payment service network error."
        return
    if code < 200 or code >= 300:
        diamond_label.text = str(parsed.get("detail", "Payment service unavailable")) if parsed is Dictionary else "Payment service unavailable"
        return
    if parsed is Dictionary and parsed.has("short_url"):
        OS.shell_open(str(parsed["short_url"]))
        diamond_label.text = "Razorpay checkout opened. Diamonds arrive after verified payment."
    elif parsed is Dictionary and parsed.has("diamonds"):
        diamond_label.text = "💎 Diamonds: " + str(parsed.get("diamonds", 0))
    else:
        diamond_label.text = "Payment request processed."

func _select_category(category: String) -> void:
    active_category = category
    _render_items()

func _render_items() -> void:
    for child in items_box.get_children():
        child.queue_free()
    for item in ITEMS:
        if item["category"] != active_category:
            continue
        var card := PanelContainer.new()
        card.add_theme_stylebox_override("panel", _panel_style(Color("#142633"), Color("#44616a")))
        items_box.add_child(card)
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 10)
        card.add_child(row)

        var symbol := Label.new()
        symbol.text = str(item["symbol"])
        symbol.custom_minimum_size = Vector2(54, 64)
        symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        symbol.add_theme_font_size_override("font_size", 30)
        row.add_child(symbol)

        var details := VBoxContainer.new()
        details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(details)
        var name_label := Label.new()
        name_label.text = str(item["name"])
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        name_label.add_theme_font_size_override("font_size", 13)
        name_label.add_theme_color_override("font_color", Color("#f3d69b"))
        details.add_child(name_label)
        var rarity := Label.new()
        rarity.text = "%s  •  %s CREDITS" % [str(item["rarity"]), str(item["price"])]
        rarity.add_theme_font_size_override("font_size", 10)
        rarity.add_theme_color_override("font_color", Color("#70d7c2"))
        details.add_child(rarity)
        var description := Label.new()
        description.text = str(item["description"])
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        description.add_theme_font_size_override("font_size", 10)
        description.add_theme_color_override("font_color", Color("#b2c4c8"))
        details.add_child(description)

        var action := Button.new()
        action.custom_minimum_size = Vector2(104, 48)
        action.add_theme_font_size_override("font_size", 11)
        if owned.has(item["id"]):
            action.text = "EQUIPPED" if equipped.get(item["category"], "") == item["id"] else "EQUIP"
        else:
            action.text = "BUY"
        action.pressed.connect(_on_item_action.bind(item))
        row.add_child(action)

func _on_item_action(item: Dictionary) -> void:
    var item_id := str(item["id"])
    if owned.has(item_id):
        equipped[str(item["category"])] = item_id
    else:
        var price := int(item["price"])
        if credits < price:
            balance_label.text = "NOT ENOUGH CREDITS  •  PLAY MATCHES TO EARN MORE"
            return
        credits -= price
        owned.append(item_id)
        equipped[str(item["category"])] = item_id
    _save_store()
    _update_balance()
    _render_items()

func _update_balance() -> void:
    if balance_label != null:
        balance_label.text = "◆  %d Z-COINS" % credits

func _load_store() -> void:
    var config := ConfigFile.new()
    if config.load(SAVE_PATH) == OK:
        credits = int(config.get_value("wallet", "credits", STARTER_CREDITS))
        owned = config.get_value("inventory", "owned", [])
        equipped = config.get_value("inventory", "equipped", {})
    else:
        credits = STARTER_CREDITS

func _save_store() -> void:
    var config := ConfigFile.new()
    config.set_value("wallet", "credits", credits)
    config.set_value("inventory", "owned", owned)
    config.set_value("inventory", "equipped", equipped)
    var error := config.save(SAVE_PATH)
    if error != OK:
        push_warning("Could not save ZORIX store inventory: " + error_string(error))
