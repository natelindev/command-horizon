extends Control

const ArtTheme = preload("res://source/main-menu/ArtTheme.gd")
const MenuChrome = preload("res://source/main-menu/MenuChrome.gd")

var list: ItemList
var status: Label
var _paths = []
var _dialog: FileDialog
var _file_meta: Label
var _count_badge: Label
var _play_button: Button


func _ready():
	theme = ArtTheme.create()
	var backdrop = load("res://source/main-menu/ArtBackdrop.gd").new()
	backdrop.dim = .56
	backdrop.left_focus = 0.35
	backdrop.set_accent(ArtTheme.accent())
	add_child(backdrop)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)

	var page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var browse_btn = Button.new()
	browse_btn.text = tr("Open .rtsreplay…")
	browse_btn.custom_minimum_size = Vector2(180, 36)
	browse_btn.pressed.connect(_browse)

	MenuChrome.screen_header(
		page,
		tr("REPLAYS"),
		tr("Recorded network battles · free camera · pause, speed and seek"),
		browse_btn
	)

	var spread = HBoxContainer.new()
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spread.add_theme_constant_override("separation", 16)
	page.add_child(spread)

	# Left column: recorded battles list.
	var list_panel = PanelContainer.new()
	list_panel.theme_type_variation = "HudHousing"
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_stretch_ratio = 1.25
	spread.add_child(list_panel)

	var left_col = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	list_panel.add_child(left_col)

	MenuChrome.nameplate_heading(left_col, tr("Replays"))

	var list_socket = PanelContainer.new()
	list_socket.theme_type_variation = "HudSocket"
	list_socket.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(list_socket)

	list = ItemList.new()
	list.name = "Recordings"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size.y = 220
	list.item_selected.connect(_on_item_selected)
	list.item_activated.connect(func(index): _open(_paths[index]))
	list_socket.add_child(list)

	# Right column: visual archive inspector.
	var detail_panel = PanelContainer.new()
	detail_panel.theme_type_variation = "HudHousing"
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 0.9
	spread.add_child(detail_panel)

	var right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 10)
	detail_panel.add_child(right_col)

	var art_socket = PanelContainer.new()
	art_socket.theme_type_variation = "HudSocket"
	art_socket.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(art_socket)

	var preview_art = TextureRect.new()
	preview_art.texture = load("res://assets/ui/art/hangar-battlefield-menu.png")
	preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview_art.custom_minimum_size = Vector2(220, 140)
	art_socket.add_child(preview_art)

	var info_card = PanelContainer.new()
	info_card.theme_type_variation = "HudCard"
	right_col.add_child(info_card)

	var info_col = VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 4)
	info_card.add_child(info_col)

	_count_badge = Label.new()
	_count_badge.add_theme_font_override("font", ArtTheme.numeral_font())
	_count_badge.add_theme_font_size_override("font_size", 18)
	_count_badge.add_theme_color_override("font_color", ArtTheme.accent())
	info_col.add_child(_count_badge)

	_file_meta = Label.new()
	_file_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_file_meta.add_theme_font_size_override("font_size", 13)
	_file_meta.add_theme_color_override("font_color", ArtTheme.IVORY)
	info_col.add_child(_file_meta)

	var status_socket = PanelContainer.new()
	status_socket.theme_type_variation = "HudSocket"
	right_col.add_child(status_socket)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", ArtTheme.MUTED)
	status_socket.add_child(status)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	page.add_child(row)
	var back_btn = _button(
		row,
		"Main menu",
		func(): get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
	)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_btn.custom_minimum_size = Vector2(140, 40)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_play_button = _button(row, "Play selected", _selected)
	_play_button.theme_type_variation = "BattlePrimaryButton"
	_play_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_play_button.custom_minimum_size = Vector2(210, 40)

	_refresh()
	MenuChrome.animate_entrance(spread, 8.0, 0.2)


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
	_count_badge.text = str(_paths.size())
	status.text = (
		tr("No recorded battles yet. Host a multiplayer battle to create a replay.")
		if _paths.is_empty()
		else tr("Choose a recorded battle.")
	)
	_play_button.disabled = _paths.is_empty()
	if not _paths.is_empty():
		list.select(0)
		_on_item_selected(0)
	else:
		_file_meta.text = tr("No recorded battles yet. Host a multiplayer battle to create a replay.")
	list.grab_focus()


func _on_item_selected(index: int):
	if index < 0 or index >= _paths.size():
		return
	var path = _paths[index]
	var mod_time = FileAccess.get_modified_time(path)
	var stamp = Time.get_datetime_string_from_unix_time(mod_time, true) if mod_time > 0 else ""
	_file_meta.text = path.get_file().get_basename() + (("\n" + stamp) if not stamp.is_empty() else "")


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
