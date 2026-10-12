extends VBoxContainer

const Factions = preload("res://source/match/FactionCatalog.gd")
const Library = preload("res://source/match/programs/ProgramLibrary.gd")
const Record = preload("res://source/match/programs/ProgramRecord.gd")
var selection = []
var library_path = Library.PATH
var _units = []
var _status
var _version
var _reason
var _preset
var _preset_ids = []
var _priority
var _radius
var _retreat
var _return
var _run
var _install
var _safe_button
var _library = Library.new()
var _saved
var _name
var _notice
var _loaded_title = "Custom preset"
var _loaded_record = {}


func _ready():
	add_theme_constant_override("separation", 7)
	_units = selection.filter(func(unit): return is_instance_valid(unit) and unit.program != null)
	if _units.is_empty():
		return
	var divider = HSeparator.new()
	add_child(divider)
	_status = _label("", 15)
	remove_child(_status)
	var heading = HBoxContainer.new()
	add_child(heading)
	heading.add_child(_status)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading, "Visual rules", _open_visual_editor)
	_button(heading, "Lua editor", _open_lua_editor)
	_version = _label("", 12)
	_version.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_reason = _label("", 12)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.max_lines_visible = 2
	_reason.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_reason.custom_minimum_size.x = 470
	var draft_heading = _label("Preset draft", 12)
	draft_heading.add_theme_color_override("font_color", Color("bcc7d3"))
	var row = HBoxContainer.new()
	add_child(row)
	_preset = OptionButton.new()
	_preset.name = "Preset"
	for preset in Library.PRESETS:
		if _units.any(func(unit): return Library.compatible(preset, unit.type)):
			_preset_ids.append(preset)
			_preset.add_item(Library.TITLES[preset])
	_preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_preset)
	_priority = OptionButton.new()
	_priority.name = "TargetPriority"
	for title in ["Nearest target", "Lowest health", "Heavy armor first", "Best counter"]:
		_priority.add_item(title)
	row.add_child(_priority)
	var parameters = HBoxContainer.new()
	parameters.add_theme_constant_override("separation", 8)
	add_child(parameters)
	_radius = _number(parameters, "Area (m)", 3, 12, 1)
	_retreat = _number(parameters, "Retreat (%)", 10, 60, 5)
	_return = _number(parameters, "Return (%)", 40, 95, 5)
	var assignments = HBoxContainer.new()
	add_child(assignments)
	_button(assignments, "Assign area / route", _assign_area)
	_button(assignments, "Set route", func(): _arm("patrol"))
	_button(assignments, "Choose escort", func(): _arm("escort"))
	_safe_button = _button(assignments, "Set safe point", func(): _arm("safe"))
	var actions = HBoxContainer.new()
	add_child(actions)
	_run = _button(actions, "Apply & run", _apply)
	_run.theme_type_variation = "BattlePrimaryButton"
	_run.name = "RunProgram"
	_run.tooltip_text = "Replace the selected units' programs with this preset draft."
	_button(actions, "Resume", _resume)
	_button(actions, "Manual hold", _manual)
	_install = _button(
		actions,
		"Fit chip · %d E" % Factions.chip_cost(_units[0].player.faction),
		func(): _arm("install")
	)
	_install.name = "InstallChip"
	var saved_row = HBoxContainer.new()
	add_child(saved_row)
	_saved = OptionButton.new()
	_saved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_saved.custom_minimum_size.x = 180
	_saved.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_saved.item_selected.connect(_load_saved)
	saved_row.add_child(_saved)
	_name = LineEdit.new()
	_name.name = "ProgramName"
	_name.placeholder_text = "Preset name"
	_name.max_length = 40
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saved_row.add_child(_name)
	_button(saved_row, "Save version", _save)
	_notice = _label("", 12)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size.x = 470
	if not _library.read_library(library_path):
		_notice.text = _library.error
	_refresh_saved()
	_show_config(_units[0].program.config)
	refresh()
	_preset.item_selected.connect(_draft_changed)
	_priority.item_selected.connect(_draft_changed)
	_radius.value_changed.connect(_draft_changed)
	_retreat.value_changed.connect(_draft_changed)
	_return.value_changed.connect(_draft_changed)


func _draft_changed(_value):
	_loaded_title = "Custom preset"
	_loaded_record = {}
	refresh()


func _label(value, font_size):
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label


func _button(parent, value, callback):
	var button = Button.new()
	button.text = value
	button.custom_minimum_size.y = 30
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _number(parent, title, minimum, maximum, step_value):
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 12)
	box.add_child(label)
	var number = SpinBox.new()
	number.min_value = minimum
	number.max_value = maximum
	number.step = step_value
	box.add_child(number)
	return number


func _draft():
	return {
		"preset": _preset_ids[_preset.selected],
		"priority": Library.PRIORITIES[_priority.selected],
		"radius": _radius.value,
		"retreat": int(_retreat.value),
		"return": int(_return.value)
	}


func _show_config(config):
	if config.preset not in _preset_ids:
		_preset_ids.append(config.preset)
		_preset.add_item(Library.TITLES[config.preset] + " · incompatible")
		_preset.set_item_disabled(_preset.item_count - 1, true)
	_preset.select(_preset_ids.find(config.preset))
	_priority.select(Library.PRIORITIES.find(config.priority))
	_radius.value = config.radius
	_retreat.value = config.retreat
	_return.value = config["return"]


func refresh():
	_units = _units.filter(
		func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion()
	)
	if _units.is_empty() or _status == null:
		return
	var compatible = _eligible(_draft())
	var controller = compatible[0].program if not compatible.is_empty() else _units[0].program
	var eligible = compatible.size()
	_safe_button.text = (
		"Set regroup point" if _draft().preset == "strike_return" else "Set safe point"
	)
	_preset.tooltip_text = Library.DESCRIPTIONS.get(
		_draft().preset, "Bounded unit behavior within your assignment."
	)
	var state = (
		controller.mode
		if _units.all(func(unit): return unit.program.mode == controller.mode)
		else "Mixed states"
	)
	_status.text = "UNIT PROGRAM   ·   %s" % state
	var title = (
		controller.program_title
		if _units.all(func(unit): return unit.program.program_title == controller.program_title)
		else "Mixed programs"
	)
	_version.text = ("%s   ·   %d / %d compatible & ready" % [title, eligible, selection.size()])
	_reason.text = controller.reason
	if not _units[0].player.basic_programs_unlocked():
		_reason.text = "Complete a vehicle producer and faction lab to unlock basic programs."
	elif not controller.installed and controller.install_left <= 0:
		_reason.text = (
			"Conventional armor. Fit a chip at your HQ or service building (%d E, %d s)."
			% [
				Factions.chip_cost(_units[0].player.faction),
				Factions.chip_seconds(_units[0].player.faction)
			]
		)
	_reason.tooltip_text = "\n".join(
		controller.trace.map(func(entry): return "%05.1f  %s" % [entry.time, entry.reason])
	)
	_run.disabled = eligible == 0
	_install.visible = _units.any(func(unit): return not unit.program.installed)
	_install.disabled = not _units[0].player.basic_programs_unlocked()


func _arm(kind):
	var game = _units[0]._match
	if game.hud != null:
		var compatible = _units.filter(
			func(unit): return kind == "install" or Library.compatible(_draft().preset, unit.type)
		)
		if compatible.is_empty():
			_notice.text = "Select a compatible unit for this preset."
			return
		game.hud.arm_program_assignment(kind, compatible)


func _assign_area():
	_arm("patrol" if Library.behavior(_draft().preset) == "patrol" else "anchor")


func _apply():
	var config = _draft()
	if not Library.validate(config):
		_notice.text = "Return threshold must be at least 10 points above retreat."
		return
	var eligible = _eligible(config)
	if eligible.is_empty():
		_notice.text = "No selected unit has an active chip compatible with this preset."
		return
	for unit in eligible:
		unit.program.configure(config, _loaded_title)
		if (
			not _loaded_record.is_empty()
			and Record._canonical(config) == Record._canonical(_loaded_record.config)
		):
			unit.program.saved_record = _loaded_record.duplicate(true)
		unit.program.run()
	_notice.text = (
		"Applied to %d unit(s). %d other unit(s) keep their orders."
		% [eligible.size(), selection.size() - eligible.size()]
	)
	refresh()


func _resume():
	for unit in _units:
		unit.program.run()
	refresh()


func _manual():
	for unit in selection:
		if is_instance_valid(unit):
			unit.issue_manual_order(null)
	refresh()


func reload_library():
	if not _library.read_library(library_path):
		_notice.text = _library.error
	_refresh_saved()


func _refresh_saved():
	_saved.clear()
	_saved.add_item("Saved programs…")
	for entry in _library.versions:
		_saved.add_item(
			(
				"%s · v%d%s"
				% [
					entry.name,
					entry.version,
					" · " + entry.mode.capitalize() if entry.mode != "preset" else ""
				]
			)
		)


func _save():
	# Re-read to preserve versions saved by another selection panel.
	if not _library.read_library(library_path):
		_notice.text = _library.error
		return
	var entry = _library.save_version(_name.text, _draft(), library_path)
	_notice.text = (
		_library.error
		if entry == null
		else "Saved %s · v%d. Assignments are chosen per map." % [entry.name, entry.version]
	)
	_refresh_saved()


func _load_saved(index):
	if index == 0:
		return
	var entry = _library.versions[index - 1]
	if entry.mode == "visual":
		_open_visual_editor(entry)
		return
	if entry.mode == "lua":
		_open_lua_editor(entry)
		return
	_show_config(entry.config)
	_loaded_record = entry.duplicate(true)
	_loaded_title = "%s · v%d" % [entry.name, entry.version]
	_notice.text = "Loaded draft: %s. Apply & run when ready." % _loaded_title
	refresh()


func _eligible(config):
	return _units.filter(
		func(unit):
			return unit.program.ready_to_run() and Library.compatible(config.preset, unit.type)
	)


func _open_lua_editor(entry = {}):
	if _units.is_empty():
		return
	var hud = _units[0]._match.hud
	if hud != null and hud.has_method("open_lua_editor"):
		if entry.is_empty() and hud.lua_draft.is_empty():
			var program = _units[0].program
			if not program.saved_record.is_empty() and program.saved_record.mode == "lua":
				entry = program.saved_record
		hud.open_lua_editor(selection, library_path, entry)


func _open_visual_editor(entry = {}):
	if _units.is_empty():
		return
	var hud = _units[0]._match.hud
	if hud != null and hud.has_method("open_visual_editor"):
		if entry.is_empty() and hud.visual_draft.is_empty():
			var program = _units[0].program
			if not program.saved_record.is_empty() and program.saved_record.mode == "visual":
				entry = program.saved_record
		hud.open_visual_editor(selection, library_path, entry)
