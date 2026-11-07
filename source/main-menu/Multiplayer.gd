extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const Session = preload("res://source/match/network/NetworkSession.gd")

var session
var host_address: LineEdit
var listen_port: SpinBox
var mode_choice: OptionButton
var factions_container: Control
var map_choice: OptionButton
var status_label: Label
var start_button: Button
var direct_menu: VBoxContainer
var room_browser

var _faction_selectors = []
var _ai_toggles = []
var _maps = []


func _ready():
	theme = ArtTheme.create()
	session = Session.current(get_tree())
	if session != null:
		session.shutdown()
		session.queue_free()
	session = null

	var backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	backdrop.dim = .65
	add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.theme_type_variation = "HudHousing"
	panel.custom_minimum_size.x = 720
	center.add_child(panel)

	var box = VBoxContainer.new()
	direct_menu = box
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title = Label.new()
	title.text = tr("MULTIPLAYER")
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)

	var subtitle = Label.new()
	subtitle.text = tr("Two to four commanders · LAN, localhost or dedicated server")
	box.add_child(subtitle)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	host_address = LineEdit.new()
	host_address.name = "HostAddress"
	host_address.text = "127.0.0.1"
	host_address.placeholder_text = tr("Host IP address")
	host_address.accessibility_name = tr("Host IP address")
	host_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(host_address)

	listen_port = SpinBox.new()
	listen_port.name = "Port"
	listen_port.min_value = 1024
	listen_port.max_value = 65535
	listen_port.value = Session.PORT
	listen_port.accessibility_name = tr("Port")
	row.add_child(listen_port)

	mode_choice = OptionButton.new()
	mode_choice.name = "BattleFormat"
	mode_choice.custom_minimum_size.y = 36
	mode_choice.add_item(tr("1v1 Duel"))
	mode_choice.add_item(tr("2v2 Teams"))
	mode_choice.item_selected.connect(func(_idx): _on_format_changed())
	box.add_child(mode_choice)

	factions_container = VBoxContainer.new()
	factions_container.name = "FactionsContainer"
	factions_container.add_theme_constant_override("separation", 8)
	box.add_child(factions_container)

	map_choice = OptionButton.new()
	map_choice.name = "Battlefield"
	map_choice.custom_minimum_size.y = 40
	box.add_child(map_choice)

	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)

	_button(buttons, "Host", _host)
	_button(buttons, "Join", _join.bind(false))
	_button(buttons, "Spectate", _join.bind(true))
	_button(buttons, "Server rooms", _browse_rooms)

	status_label = Label.new()
	status_label.name = "ConnectionStatus"
	status_label.text = tr("Host a battle, or enter a host address to join.")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	start_button = _button(box, "Start battle", _start)
	start_button.name = "StartBattle"
	start_button.disabled = true

	_button(box, "Main menu", _back)
	_on_format_changed()
	host_address.grab_focus()


func _on_format_changed():
	_rebuild_roster_ui(mode_choice.selected == 1)
	_rebuild_maps(mode_choice.selected == 1)


func _rebuild_roster_ui(is_2v2: bool):
	for child in factions_container.get_children():
		child.queue_free()
	_faction_selectors.clear()
	_ai_toggles.clear()

	if not is_2v2:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		factions_container.add_child(row)
		var host_f = _factions(row, "Host faction")
		var guest_f = _factions(row, "Guest faction")
		guest_f.select(1)
		_faction_selectors = [host_f, guest_f]
	else:
		var t1_header = Label.new()
		t1_header.text = tr("Team 1")
		t1_header.add_theme_font_size_override("font_size", 14)
		factions_container.add_child(t1_header)

		var t1_row = HBoxContainer.new()
		t1_row.add_theme_constant_override("separation", 12)
		factions_container.add_child(t1_row)
		var s0 = _factions(t1_row, "Host faction (Team 1)")
		var s1 = _factions(t1_row, "Guest faction (Team 1)")
		s1.select(0)

		var t2_header = Label.new()
		t2_header.text = tr("Team 2")
		t2_header.add_theme_font_size_override("font_size", 14)
		factions_container.add_child(t2_header)

		var t2_row = HBoxContainer.new()
		t2_row.add_theme_constant_override("separation", 12)
		factions_container.add_child(t2_row)

		var s2_box = VBoxContainer.new()
		s2_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t2_row.add_child(s2_box)
		var s2 = _factions(s2_box, "Enemy faction A (Team 2)")
		s2.select(1)
		var ai2 = _toggle_ai(s2_box, false)

		var s3_box = VBoxContainer.new()
		s3_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t2_row.add_child(s3_box)
		var s3 = _factions(s3_box, "Enemy faction B (Team 2)")
		s3.select(2)
		var ai3 = _toggle_ai(s3_box, false)

		_faction_selectors = [s0, s1, s2, s3]
		_ai_toggles = [null, null, ai2, ai3]


func _toggle_ai(parent, default_ai: bool):
	var choice = OptionButton.new()
	choice.custom_minimum_size.y = 32
	choice.add_item(tr("Human (Network)"))
	choice.add_item(tr("AI Commander"))
	choice.select(1 if default_ai else 0)
	parent.add_child(choice)
	return choice


func _rebuild_maps(is_2v2: bool):
	map_choice.clear()
	_maps.clear()
	var target_players = 4 if is_2v2 else 2
	for path in Constants.Match.MAPS:
		var info = Constants.Match.MAPS[path]
		if info.players != target_players or "TerrainTestMap" in path:
			continue
		_maps.append(path)
		map_choice.add_item(tr(info.name))
	if map_choice.item_count > 0:
		map_choice.select(0)


func _factions(parent, caption):
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var label = Label.new()
	label.text = tr(caption)
	column.add_child(label)
	var choice = OptionButton.new()
	choice.custom_minimum_size.y = 40
	for faction in ["Bastion Directorate", "Helix Systems", "Free Frontier Coalition"]:
		choice.add_item(tr(faction))
	column.add_child(choice)
	return choice


func _button(parent, caption, callback):
	var button = Button.new()
	button.text = tr(caption)
	button.custom_minimum_size.y = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _new_session():
	session = Session.create(get_tree())
	session.changed.connect(_status)


func _host():
	_new_session()
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.map_path = _maps[map_choice.selected]
	settings.match_seed = int(Time.get_unix_time_from_system()) % 1000000000

	var is_2v2 = mode_choice.selected == 1
	var total_slots = 4 if is_2v2 else 2

	for index in total_slots:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = 1 if index == 0 else 2
		side.color = Constants.Player.COLORS[index % Constants.Player.COLORS.size()]
		var selector = _faction_selectors[index]
		side.faction = ["bastion", "helix", "frontier"][selector.selected]
		side.spawn_index = index
		if is_2v2:
			side.team = 0 if index < 2 else 1
			if index >= 2 and _ai_toggles[index] != null and _ai_toggles[index].selected == 1:
				side.set_meta("ai_commander", true)
		else:
			side.team = index
		settings.players.append(side)

	session.host(settings, int(listen_port.value))
	_status()


func _join(watch: bool):
	_new_session()
	session.join(host_address.text, int(listen_port.value), watch)
	_status()


func _browse_rooms():
	_clear_session()
	room_browser = load("res://source/main-menu/RoomBrowser.gd").new()
	direct_menu.hide()
	direct_menu.get_parent().add_child(room_browser)
	room_browser.back.connect(_close_browser)
	room_browser.enter_battle.connect(_join_room)
	room_browser.browse(host_address.text.strip_edges(), int(listen_port.value))
	room_browser.title_input.grab_focus()


func _join_room(port: int, ticket: String):
	_new_session()
	session.join(host_address.text, port, false, ticket)
	_status()


func _close_browser():
	_clear_session()
	room_browser.queue_free()
	room_browser = null
	direct_menu.show()
	status_label.text = tr("Host a battle, or enter a host address to join.")
	start_button.disabled = true
	host_address.grab_focus()


func _clear_session():
	if is_instance_valid(session):
		session.shutdown()
		session.queue_free()
		session = null


func _status():
	if not is_instance_valid(session):
		return
	status_label.text = tr(session.status)
	if is_instance_valid(room_browser) and room_browser.handed_off:
		room_browser.status.text = tr(session.status)
	start_button.disabled = not session.is_ready_to_start()


func _start():
	start_button.disabled = true
	await session.start_battle()


func _back():
	_clear_session()
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
