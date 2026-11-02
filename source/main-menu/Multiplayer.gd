extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const Session = preload("res://source/match/network/NetworkSession.gd")
var session
var host_address: LineEdit
var listen_port: SpinBox
var host_faction: OptionButton
var guest_faction: OptionButton
var map_choice: OptionButton
var status_label: Label
var start_button: Button
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
	panel.custom_minimum_size.x = 680
	center.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title = Label.new()
	title.text = tr("MULTIPLAYER")
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var subtitle = Label.new()
	subtitle.text = tr("Two commanders · LAN or localhost · shared battlefield vision")
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
	var factions = HBoxContainer.new()
	factions.add_theme_constant_override("separation", 12)
	box.add_child(factions)
	host_faction = _factions(factions, "Host faction")
	guest_faction = _factions(factions, "Guest faction")
	guest_faction.select(1)
	map_choice = OptionButton.new()
	map_choice.name = "Battlefield"
	map_choice.custom_minimum_size.y = 40
	for path in Constants.Match.MAPS:
		var info = Constants.Match.MAPS[path]
		if info.players != 2 or "TerrainTestMap" in path:
			continue
		_maps.append(path)
		map_choice.add_item(tr(info.name))
	box.add_child(map_choice)
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_button(buttons, "Host", _host)
	_button(buttons, "Join", _join.bind(false))
	_button(buttons, "Spectate", _join.bind(true))
	status_label = Label.new()
	status_label.name = "ConnectionStatus"
	status_label.text = tr("Host a battle, or enter a host address to join.")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)
	start_button = _button(box, "Start battle", _start)
	start_button.name = "StartBattle"
	start_button.disabled = true
	_button(box, "Main menu", _back)
	host_address.grab_focus()


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
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.color = Constants.Player.COLORS[index]
		side.faction = ["bastion", "helix", "frontier"][
			(host_faction if index == 0 else guest_faction).selected
		]
		settings.players.append(side)
	session.host(settings, int(listen_port.value))
	_status()


func _join(watch: bool):
	_new_session()
	session.join(host_address.text, int(listen_port.value), watch)
	_status()


func _status():
	if not is_instance_valid(session):
		return
	status_label.text = tr(session.status)
	start_button.disabled = (
		not session.authority or not session.peers.values().any(func(entry): return entry.slot == 1)
	)


func _start():
	start_button.disabled = true
	await session.start_battle()


func _back():
	if is_instance_valid(session):
		session.shutdown()
		session.queue_free()
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
