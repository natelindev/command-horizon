extends VBoxContainer

signal back
signal enter_battle(port: int, ticket: String)
const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const MenuChrome = preload("res://source/main-menu/MenuChrome.gd")
const Link = preload("res://source/match/network/RoomLink.gd")
var link = Link.new()
var rooms = ItemList.new()
var title_input = LineEdit.new()
var format = OptionButton.new()
var create_row = HBoxContainer.new()
var create_button: Button
var join_button: Button
var leave_button: Button
var start_button: Button
var status = Label.new()
var listing = []
var mine = 0
var is_room_owner = false
var online = false
var handed_off = false
var _hello_deadline = 0


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 10)

	var housing = PanelContainer.new()
	housing.theme_type_variation = "HudHousing"
	housing.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(housing)

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	housing.add_child(col)

	MenuChrome.nameplate_heading(col, tr("Server rooms"))

	var list_socket = PanelContainer.new()
	list_socket.theme_type_variation = "HudSocket"
	list_socket.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(list_socket)

	rooms.custom_minimum_size = Vector2(400, 160)
	rooms.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms.accessibility_name = tr("Server rooms")
	rooms.item_selected.connect(func(_index): _buttons())
	list_socket.add_child(rooms)

	create_row.add_theme_constant_override("separation", 8)
	col.add_child(create_row)
	title_input.placeholder_text = tr("Room name")
	title_input.accessibility_name = tr("Room name")
	title_input.max_length = 32
	title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_input.text_changed.connect(func(_text): _buttons())
	create_row.add_child(title_input)
	format.add_item(tr("1v1 Duel"), 2)
	format.add_item(tr("2v2 Teams"), 4)
	create_row.add_child(format)
	create_button = _button(create_row, "Create room", _create)
	create_button.theme_type_variation = "BattlePrimaryButton"
	create_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	create_button.custom_minimum_size.x = 150

	var status_socket = PanelContainer.new()
	status_socket.theme_type_variation = "HudSocket"
	col.add_child(status_socket)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", ArtTheme.MUTED)
	status_socket.add_child(status)

	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	add_child(actions)
	var back_btn = _button(actions, "Back", func(): back.emit())
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_btn.custom_minimum_size.x = 120
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	join_button = _button(actions, "Join room", _join)
	join_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	join_button.custom_minimum_size.x = 150
	leave_button = _button(actions, "Leave room", func(): link.send(1, {"type": "leave"}))
	leave_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	leave_button.custom_minimum_size.x = 150
	start_button = _button(actions, "Start battle", func(): link.send(1, {"type": "start"}))
	start_button.theme_type_variation = "BattlePrimaryButton"
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	start_button.custom_minimum_size.x = 200

	_buttons()
	add_child(link)
	link.connected.connect(func(): link.send(1, {"type": "browse"}))
	link.received.connect(_receive)
	link.lost.connect(_offline)


func _button(parent, caption: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = tr(caption)
	button.custom_minimum_size.y = 38
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func browse(address: String, port: int):
	status.text = tr("Connecting…")
	_hello_deadline = Time.get_ticks_msec() + 10000
	if address.is_empty() or address.length() > 253 or not link.dial(address, port):
		_offline()


func _process(_delta):
	if _hello_deadline > 0 and Time.get_ticks_msec() >= _hello_deadline:
		_offline()


func _offline():
	_hello_deadline = 0
	online = false
	link.close()
	if not handed_off:
		status.text = tr("Room server unavailable. Check the address and port.")
	_buttons()


func _receive(_sender: int, packet: Dictionary):
	if handed_off:
		return
	match packet.type:
		"rooms":
			if (
				not packet.get("rooms") is Array
				or not packet.get("mine") is int
				or not packet.get("owner") is bool
			):
				return
			for room in packet.rooms:
				if (
					not room is Dictionary
					or not room.get("id") is int
					or not room.get("name") is String
					or room.get("capacity") not in [2, 4]
					or not room.get("count") is int
					or room.get("state") not in ["Waiting", "Starting", "In battle"]
				):
					return
			_hello_deadline = 0
			online = true
			var selected = _selected()
			listing = packet.rooms
			mine = packet.mine
			is_room_owner = packet.owner
			rooms.clear()
			status.text = (
				tr("Select a room or create one.")
				if listing.size()
				else tr("No rooms yet. Create the first room.")
			)
			for room in listing:
				var index = rooms.add_item(
					"%s   %d/%d   %s" % [room.name, room.count, room.capacity, tr(room.state)]
				)
				if room.id == mine or (mine == 0 and room.id == selected):
					rooms.select(index)
				if room.id == mine:
					if room.state == "Starting":
						status.text = tr("Starting battle…")
					elif room.count < room.capacity:
						status.text = (
							tr("Waiting for players · %d/%d") % [room.count, room.capacity]
						)
					else:
						status.text = (
							tr("Room full. Start when ready.")
							if is_room_owner
							else tr("Waiting for the room owner to start.")
						)
			_buttons()
		"error":
			if packet.get("reason") is String:
				status.text = tr(packet.reason)
		"battle":
			if (
				mine == 0
				or not packet.get("port") is int
				or packet.port < 1024
				or packet.port > 65535
			):
				return
			if not packet.get("ticket") is String or packet.ticket.length() != 64:
				return
			handed_off = true
			_buttons()
			enter_battle.emit(packet.port, packet.ticket)


func _selected() -> int:
	var selected = rooms.get_selected_items()
	return listing[selected[0]].id if not selected.is_empty() else 0


func _buttons():
	var available = online and not handed_off
	create_row.visible = mine == 0
	join_button.visible = mine == 0
	leave_button.visible = mine != 0
	start_button.visible = mine != 0 and is_room_owner
	create_button.disabled = not available or mine != 0 or title_input.text.strip_edges().is_empty()
	leave_button.disabled = not available or mine == 0
	join_button.disabled = true
	start_button.disabled = true
	for room in listing:
		if room.id == _selected() and mine == 0:
			join_button.disabled = (
				not available or room.state != "Waiting" or room.count >= room.capacity
			)
		if room.id == mine:
			start_button.disabled = (
				not available
				or not is_room_owner
				or room.state != "Waiting"
				or room.count != room.capacity
			)


func _create():
	link.send(
		1,
		{
			"type": "create",
			"name": title_input.text.strip_edges(),
			"capacity": format.get_selected_id()
		}
	)


func _join():
	link.send(1, {"type": "join", "id": _selected()})
