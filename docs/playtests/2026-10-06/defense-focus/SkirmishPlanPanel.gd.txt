extends PanelContainer

const Plan = preload("res://source/match/SkirmishPlan.gd")
var hud
var _body
var _title
var _description
var _action
var _idle
var _army
var _damaged
var _support
var _elapsed = 0.0
var _toggle


func _ready():
	custom_minimum_size.x = 340
	size.x = 340
	hud._style(self)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_toggle = hud._button(box, "Battle plan  ▾", _toggle_body)
	_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	box.add_child(_body)
	_title = _label(_body, 14)
	_description = _label(_body, 12)
	_description.add_theme_color_override("font_color", Color("bcc7d3"))
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	_body.add_child(actions)
	_action = hud._button(actions, "", _select_step)
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_support = hud._button(actions, "", _select_support)
	_support.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_support.name = "SelectRepairSupport"
	var shortcuts = HFlowContainer.new()
	shortcuts.add_theme_constant_override("h_separation", 6)
	shortcuts.add_theme_constant_override("v_separation", 6)
	_body.add_child(shortcuts)
	_idle = hud._button(shortcuts, "", _select_engineers)
	_army = hud._button(shortcuts, "", func(): _select(Plan.army(_player())))
	_damaged = hud._button(shortcuts, "", func(): _select(Plan.damaged_units(_player())))
	_damaged.name = "SelectLowHealth"
	_damaged.tooltip_text = (
		"Select combat and support units below 50% health. Selection keeps their orders. "
		+ "Use Recover health for a manual retreat, or review their program safe points."
	)
	refresh()


func _label(parent, font_size):
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 308
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _process(delta):
	var command = hud.get_child(0)
	position = Vector2(14, command.position.y + command.size.y + 10)
	visible = not hud.get_parent().finished and not hud.map_assignment_active()
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		refresh()


func _player():
	return hud.get_parent()._get_human_player()


func refresh():
	var player = _player()
	var step = Plan.next_step(player)
	_title.text = step.title
	_description.text = step.description
	_action.text = step.action
	_action.tooltip_text = step.get("action_tooltip", "")
	_action.accessibility_description = _action.tooltip_text
	_action.disabled = step.units.is_empty() and not step.get("open_technology", false)
	var support = Plan.support_step(player)
	var show_support = not support.is_empty() and support.id != step.id
	if show_support:
		_support.text = support.support_label
		_support.tooltip_text = support.support_tooltip
		_support.accessibility_description = "Repair support. " + support.support_tooltip
		_support.disabled = support.units.is_empty()
	if _support.visible != show_support:
		_support.visible = show_support
		size.y = 0
	var endangered = Plan.endangered_workers(player)
	var idle = Plan.idle_workers(player).size()
	var army = Plan.army(player).size()
	_idle.text = "Idle engineers · %d" % idle
	_idle.disabled = idle == 0
	_idle.tooltip_text = "Select engineers waiting for an assignment."
	if not endangered.is_empty():
		_idle.text = "Engineers at risk · %d" % endangered.size()
		_idle.disabled = false
		_idle.tooltip_text = (
			"Select engineers near visible threats or recently hit by enemy fire. "
			+ "Move them behind your defenses. Selection keeps their current orders."
		)
	_idle.accessibility_description = _idle.text + ". " + _idle.tooltip_text
	_army.text = "Army · %d" % army
	_army.disabled = army == 0
	var damaged = Plan.damaged_units(player).size()
	_damaged.text = "Low health · %d" % damaged
	_damaged.accessibility_description = _damaged.text + ". " + _damaged.tooltip_text
	if _damaged.visible != (damaged > 0):
		_damaged.visible = damaged > 0
		size.y = 0


func _select_engineers():
	var player = _player()
	var endangered = Plan.endangered_workers(player)
	_select(endangered if not endangered.is_empty() else Plan.idle_workers(player))


func _toggle_body():
	_body.visible = not _body.visible
	_toggle.text = "Battle plan  ▾" if _body.visible else "Battle plan  ▸"
	size.y = 0


func _select_step():
	var step = Plan.next_step(_player())
	if step.get("open_technology", false):
		hud.open_technology()
	else:
		_select(step.units, step.get("focus_position"))


func _select(units, focus = null):
	if hud._overlay != null or is_instance_valid(hud.program_editor) or hud.get_parent().finished:
		return
	if units.is_empty():
		refresh()
		return
	hud._assignment_kind = ""
	hud._assignment_units.clear()
	hud._assignment_points.clear()
	hud._assignment_hint.hide()
	hud.direct_orders.cancel()
	hud._refresh_shortcuts()
	_player().get_node("StructurePlacementHandler")._cancel_structure_placement()
	MatchSignals.deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()
	hud.get_parent().get_node("IsometricCamera3D").set_position_safely(
		focus if focus is Vector3 and focus.is_finite() else units[0].global_position_yless
	)


func _select_support():
	var step = Plan.support_step(_player())
	if step.is_empty():
		refresh()
		return
	_select(step.units)
