extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
var list: ItemList
var status: Label
var _paths = []
var _dialog: FileDialog


func _ready():
	theme = ArtTheme.create()
	var backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	backdrop.dim = .6
	add_child(backdrop)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = PanelContainer.new()
	panel.theme_type_variation = "HudHousing"
	panel.custom_minimum_size = Vector2(720, 480)
	center.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title = Label.new()
	title.text = tr("REPLAYS")
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var caption = Label.new()
	caption.text = tr("Recorded network battles · free camera · pause, speed and seek")
	column.add_child(caption)
	list = ItemList.new()
	list.name = "Recordings"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size.y = 280
	list.item_activated.connect(func(index): _open(_paths[index]))
	column.add_child(list)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	_button(row, "Play selected", _selected)
	_button(row, "Open .rtsreplay…", _browse)
	_button(
		row,
		"Main menu",
		func(): get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
	)
	_refresh()


func _refresh():
	DirAccess.make_dir_recursive_absolute("user://replays")
	_paths.clear()
	list.clear()
	var directory = DirAccess.open("user://replays")
	var files = Array(directory.get_files())
	files.sort()
	files.reverse()
	for filename in files:
		if filename.ends_with(".rtsreplay"):
			_paths.append("user://replays/" + filename)
			list.add_item(filename.get_basename())
	status.text = (
		tr("No recorded battles yet. Host a multiplayer battle to create a replay.")
		if _paths.is_empty()
		else tr("Choose a recorded battle.")
	)
	if not _paths.is_empty():
		list.select(0)
	list.grab_focus()


func _button(parent, caption, callback):
	var button = Button.new()
	button.text = tr(caption)
	button.custom_minimum_size.y = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _selected():
	var selected = list.get_selected_items()
	if not selected.is_empty():
		_open(_paths[selected[0]])


func _browse():
	_dialog = FileDialog.new()
	_dialog.title = tr("Open replay")
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.filters = PackedStringArray(["*.rtsreplay ; RTS replay"])
	_dialog.file_selected.connect(_open)
	add_child(_dialog)
	_dialog.popup_centered_ratio(.7)


func _open(path: String):
	status.text = tr("Loading replay…")
	var playback = load("res://source/match/network/ReplayPlayback.gd").new()
	playback.name = "ReplayPlayback"
	get_tree().root.add_child(playback)
	if not await playback.open(path):
		status.text = playback.error
		playback.queue_free()
