extends VBoxContainer

signal subset_requested(members, remove)

const Catalog = preload("res://source/match/BastionCatalog.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const Bindings = preload("res://source/input/KeyBindings.gd")
const PAGE_SIZE = 8

var selection = []
var _members = []
var _types = []
var _tiles = []
var _page = 0
var _grid: GridContainer
var _previous: Button
var _next: Button
var _range: Label
var _damaged: Button
var _mouse_held = false


func _ready():
	# Box selection emits one signal per unit; only build the final attached panel.
	_build.call_deferred()


func _build():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_members = selection.filter(_eligible)
	var order = Catalog.NAMES.keys() + Catalog.MISSION_NAMES.keys()
	_members.sort_custom(
		func(a, b):
			if a.type != b.type:
				return order.find(a.type) < order.find(b.type)
			return a.get_instance_id() < b.get_instance_id()
	)
	add_theme_constant_override("separation", 6)
	var types = GridContainer.new()
	types.columns = 3
	types.add_theme_constant_override("h_separation", 5)
	types.add_theme_constant_override("v_separation", 5)
	add_child(types)
	var cohorts = {}
	for unit in _members:
		if not cohorts.has(unit.type):
			cohorts[unit.type] = []
		cohorts[unit.type].append(unit)
	for role in cohorts:
		var members = cohorts[role]
		var title = Factions.title(members[0].player.faction, role)
		var button = _button()
		button.name = "Select" + role
		button.custom_minimum_size = Vector2(150, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_request.bind(members))
		types.add_child(button)
		var row = HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 7
		row.offset_right = -7
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		var label = Label.new()
		label.text = title
		label.add_theme_font_size_override("font_size", 13)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		var count = Label.new()
		count.text = str(members.size())
		count.add_theme_font_size_override("font_size", 13)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(count)
		_types.append({"button": button, "title": title, "members": members})
	_grid = GridContainer.new()
	_grid.columns = PAGE_SIZE
	_grid.add_theme_constant_override("h_separation", 5)
	add_child(_grid)
	var controls = HBoxContainer.new()
	add_child(controls)
	_previous = _button()
	_previous.text = "‹"
	_previous.custom_minimum_size = Vector2(32, 28)
	_previous.tooltip_text = "Previous units"
	_previous.accessibility_name = "Previous units"
	_previous.pressed.connect(_turn_page.bind(-1))
	controls.add_child(_previous)
	_range = Label.new()
	_range.add_theme_font_size_override("font_size", 13)
	_range.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(_range)
	_next = _button()
	_next.text = "›"
	_next.custom_minimum_size = Vector2(32, 28)
	_next.tooltip_text = "Next units"
	_next.accessibility_name = "Next units"
	_next.pressed.connect(_turn_page.bind(1))
	controls.add_child(_next)
	_damaged = _button()
	_damaged.add_theme_font_size_override("font_size", 13)
	_damaged.pressed.connect(_select_damaged)
	controls.add_child(_damaged)
	_rebuild_tiles()
	refresh()


func _turn_page(direction):
	_page = clampi(_page + direction, 0, maxi(0, ceili(_members.size() / float(PAGE_SIZE)) - 1))
	_rebuild_tiles()
	refresh()


func _rebuild_tiles():
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_tiles.clear()
	for index in range(_page * PAGE_SIZE, mini((_page + 1) * PAGE_SIZE, _members.size())):
		var unit = _members[index]
		if not _eligible(unit):
			continue
		var button = _button()
		button.custom_minimum_size = Vector2(52, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_request.bind([unit]))
		_grid.add_child(button)
		var box = VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 4
		box.offset_right = -4
		box.offset_top = 4
		box.offset_bottom = -4
		box.add_theme_constant_override("separation", 2)
		button.add_child(box)
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		if unit.type not in Catalog.MISSION_NAMES:
			var icon = TextureRect.new()
			icon.texture = load(Factions.icon(unit.player.faction, unit.type))
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size.y = 20
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(icon)
			box.move_child(icon, 0)
		else:
			var mission = Label.new()
			mission.text = "TRK" if unit.type == "SupplyTruck" else "VTOL"
			mission.add_theme_font_size_override("font_size", 12)
			mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(mission)
			box.move_child(mission, 0)
		var health = ProgressBar.new()
		health.custom_minimum_size.y = 4
		health.show_percentage = false
		health.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for style in ["background", "fill"]:
			var fill = StyleBoxFlat.new()
			fill.bg_color = Color("73c6ae") if style == "fill" else Color("333e49")
			fill.set_corner_radius_all(2)
			health.add_theme_stylebox_override(style, fill)
		box.add_child(health)
		_tiles.append({"unit": unit, "button": button, "label": label, "health": health})
	_previous.disabled = _page == 0
	_next.disabled = (_page + 1) * PAGE_SIZE >= _members.size()
	_range.text = (
		"%d–%d / %d"
		% [_page * PAGE_SIZE + 1, mini((_page + 1) * PAGE_SIZE, _members.size()), _members.size()]
	)


func refresh():
	if _damaged == null or not is_inside_tree() or is_queued_for_deletion():
		return
	var hint = (
		"Select only these units. Hold %s to remove them." % Bindings.label("shift_selecting")
	)
	for entry in _types:
		entry.button.tooltip_text = "%s × %d\n%s" % [entry.title, entry.members.size(), hint]
		entry.button.accessibility_name = "%s, %d selected" % [entry.title, entry.members.size()]
		entry.button.accessibility_description = hint
	var damaged = _members.filter(func(unit): return _eligible(unit) and unit.hp < unit.hp_max)
	_damaged.text = "Select damaged · %d" % damaged.size()
	_damaged.disabled = damaged.is_empty()
	_damaged.tooltip_text = hint
	for entry in _tiles:
		var unit = entry.unit
		entry.button.disabled = not _eligible(unit)
		if entry.button.disabled:
			continue
		var percent = clampf(100.0 * unit.hp / unit.hp_max, 0, 100)
		entry.health.value = percent
		entry.label.text = "%d%%" % ceili(percent)
		var title = (
			"%s · %d / %d HP"
			% [Factions.title(unit.player.faction, unit.type), ceili(unit.hp), unit.hp_max]
		)
		entry.button.tooltip_text = title + "\n" + hint
		entry.button.accessibility_name = title
		entry.button.accessibility_description = hint


func _select_damaged():
	_request(_members.filter(func(unit): return _eligible(unit) and unit.hp < unit.hp_max))


func _button():
	var button = Button.new()
	button.gui_input.connect(_remember_mouse)
	return button


func _remember_mouse(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_held = event.pressed


func has_active_mouse_press():
	if not _mouse_held:
		return false
	for entry in _types + _tiles:
		if entry.button.is_pressed():
			return true
	for button in [_previous, _next, _damaged]:
		if is_instance_valid(button) and button.is_pressed():
			return true
	return false


func _request(members):
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var live = members.filter(_eligible)
	if not live.is_empty():
		# Selection signals can detach this button during its mouse-release event.
		# Consume that release before rebuilding so it cannot select the battlefield.
		get_viewport().set_input_as_handled()
		subset_requested.emit(live, Globals.options.selection_modifier_pressed())


func _eligible(unit):
	return (
		is_instance_valid(unit)
		and not unit.is_queued_for_deletion()
		and unit.is_in_group("controlled_units")
		and unit.is_in_group("selected_units")
		and unit.hp != null
		and unit.hp > 0
	)
