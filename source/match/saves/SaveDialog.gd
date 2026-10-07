extends CanvasLayer

const Bindings = preload("res://source/input/KeyBindings.gd")

var manager
var mode = "load"
var selected = "manual-1"
var recovery_only = false
var _entries = []
var _confirmed = false
var _list: ItemList
var _notice: Label
var _primary: Button
var _close: Button
var _save_tab: Button
var _load_tab: Button
var _summary: Label


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	var shade = ColorRect.new()
	shade.color = Color("080e17ed")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(850, 620)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("19232f")
	style.set_corner_radius_all(10)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 22)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	_label(column, "BATTLE ARCHIVE", 25)
	_label(
		column,
		(
			"Manual saves · %s quicksave · %s quickload · 3 campaign checkpoints"
			% [Bindings.label("quicksave_battle"), Bindings.label("quickload_battle")]
		),
		14
	)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	_save_tab = _button(tabs, "Save battle", func(): _set_mode("save"))
	_load_tab = _button(tabs, "Load battle", func(): _set_mode("load"))
	_list = ItemList.new()
	_list.custom_minimum_size.y = 240
	_list.fixed_column_width = 780
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 14)
	_list.add_theme_constant_override("v_separation", 10)
	_list.item_selected.connect(_selected)
	var selection = StyleBoxFlat.new()
	selection.bg_color = Color("344557")
	selection.set_corner_radius_all(4)
	_list.add_theme_stylebox_override("selected", selection)
	_list.add_theme_stylebox_override("selected_focus", selection)
	column.add_child(_list)
	_summary = _label(column, "", 14)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(780, 60)
	_notice = _label(column, "", 14)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size = Vector2(780, 38)
	_notice.add_theme_color_override("font_color", Color("e7c578"))
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	_primary = _button(actions, "", _activate)
	_close = _button(actions, "Back [Esc]", _back)
	_primary.disabled = true
	_list.grab_focus()


func refresh():
	manager.busy = true
	set_busy("Reading saved battles…")
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	_entries.clear()
	_list.clear()
	for id in manager.slots.IDS:
		show_notice("Reading " + _title(id) + "…")
		await get_tree().process_frame
		var entry = manager.slots.describe(id)
		_entries.append(entry)
		_list.add_item(_title(id) + "  ·  " + entry.summary.get_slice("\n", 0))
		_list.set_item_tooltip(_list.item_count - 1, entry.summary)
	var index = manager.slots.IDS.find(selected)
	_list.select(maxi(0, index))
	_list.ensure_current_is_visible()
	_confirmed = false
	_list.mouse_filter = Control.MOUSE_FILTER_STOP
	_close.disabled = false
	_save_tab.disabled = (
		manager.active_game() == null or manager.active_game().finished or recovery_only
	)
	_load_tab.disabled = false
	if _save_tab.disabled:
		mode = "load"
	_update_action()
	show_notice("")
	manager.busy = false


func _selected(index):
	selected = _entries[index].id
	_confirmed = false
	_notice.text = ""
	_update_action()


func _set_mode(value):
	mode = value
	_confirmed = false
	_notice.text = ""
	_update_action()


func _update_action():
	var entry = _entries[manager.slots.IDS.find(selected)]
	_save_tab.toggle_mode = true
	_load_tab.toggle_mode = true
	_save_tab.set_pressed_no_signal(mode == "save")
	_load_tab.set_pressed_no_signal(mode == "load")
	_primary.text = "Save to slot" if mode == "save" else "Load selected"
	_primary.disabled = (entry.exists and not entry.valid) if mode == "save" else not entry.valid
	if mode == "save" and selected.begins_with("auto-"):
		_primary.disabled = true
		_summary.text = "Campaign checkpoints are automatic. Choose a manual or quicksave slot."
	else:
		_summary.text = (
			"Save the current battle to " + _title(selected) + "."
			if mode == "save"
			else "Load " + _title(selected) + ". Battles resume in tactical pause."
		)
	if entry.exists and not entry.valid:
		_summary.text = "This save cannot be loaded or overwritten. The original file is retained."
	if entry.valid:
		_summary.text = entry.summary + "\n" + _summary.text
	_close.text = "Main menu" if recovery_only else "Back [Esc]"


func _activate():
	if _primary.disabled or manager.busy:
		return
	var entry = _entries[manager.slots.IDS.find(selected)]
	var needs_confirmation = entry.exists if mode == "save" else manager.active_game() != null
	if needs_confirmation and not _confirmed:
		_confirmed = true
		_notice.text = (
			"Replace this saved battle?"
			if mode == "save"
			else "Replace the current battle? Unsaved progress will be lost."
		)
		_primary.text = "Overwrite save" if mode == "save" else "Confirm load"
		_primary.grab_focus()
		return
	if mode == "save":
		await manager.save_slot(selected)
	else:
		await manager.load_slot(selected)


func set_busy(message):
	_primary.disabled = true
	_close.disabled = true
	_save_tab.disabled = true
	_load_tab.disabled = true
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_notice(message)


func show_notice(message):
	_notice.text = message
	_notice.tooltip_text = message


func _back():
	if recovery_only:
		manager.close_dialog(true)
		get_tree().paused = false
		get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
	else:
		manager.close_dialog()


func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if not manager.busy:
			_back()


func _unhandled_input(_event):
	get_viewport().set_input_as_handled()


func _title(id):
	return manager.slots.title(id)


func _label(parent, value, size):
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _button(parent, value, callback):
	var button = Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(180, 38)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
