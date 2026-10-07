extends VBoxContainer

var selection = []
var _editing_rows = []
var _roster
var _selected = null
var _entries = []
var _revision = -1
var _name
var _options
var _policy
var _summary
var _create
var _add
var _remove
var _select
var _rename
var _disband


func _ready():
	_roster = selection[0].player.squad_roster
	add_theme_constant_override("separation", 3)
	var row = HBoxContainer.new()
	add_child(row)
	_editing_rows.append(row)
	_name = LineEdit.new()
	_name.placeholder_text = "Squad name"
	_name.max_length = 32
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name)
	_create = _button(row, "Create squad", _create_squad)
	_rename = _button(row, "Rename", _rename_squad)
	var membership = HBoxContainer.new()
	add_child(membership)
	_editing_rows.append(membership)
	_options = OptionButton.new()
	_options.custom_minimum_size.x = 140
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_options.item_selected.connect(_choose)
	membership.add_child(_options)
	_select = _button(membership, "Select", _select_members)
	_add = _button(membership, "Add selected", _add_members)
	_remove = _button(membership, "Leave", _leave)
	_disband = _button(membership, "Disband", _disband_squad)
	var coordination = HBoxContainer.new()
	add_child(coordination)
	_policy = OptionButton.new()
	_policy.add_theme_font_size_override("font_size", 12)
	for title in ["Spread fire", "Focus fire", "Independent"]:
		_policy.add_item(title)
	_policy.item_selected.connect(_set_policy)
	coordination.add_child(_policy)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	coordination.add_child(_summary)
	_selected = selection[0].program_squad
	if is_instance_valid(_selected):
		_name.text = _selected.title
	refresh()


func _button(row, title, callback):
	var button = Button.new()
	button.text = title
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	row.add_child(button)
	return button


func _members():
	return selection.filter(
		func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion()
	)


func _create_squad():
	var squad = _roster.create(_name.text, _members())
	if squad != null:
		_selected = squad
	refresh()
	_feedback(
		(
			_roster.error
			if squad == null
			else "Squad created. Current programs and orders are unchanged."
		)
	)


func _rename_squad():
	if _roster.rename(_selected, _name.text):
		_name.text = _selected.title
	refresh()


func _add_members():
	var success = _roster.assign(_selected, _members())
	refresh()
	_feedback("Selected units joined this squad." if success else _roster.error)


func _leave():
	for unit in _members():
		_roster.remove(unit)
	refresh()


func _disband_squad():
	_roster.disband(_selected)
	_selected = null
	refresh()


func _choose(index):
	_selected = _entries[index]
	_name.text = _selected.title if is_instance_valid(_selected) else ""
	refresh()


func _set_policy(index):
	if is_instance_valid(_selected):
		_selected.set_policy(_selected.POLICIES[index])
	refresh()


func _select_members():
	if not is_instance_valid(_selected):
		return
	var members = _selected.active_members()
	# Selection rebuilds this panel; copy membership before emitting selection changes.
	MatchSignals.deselect_all_units.emit()
	for unit in members:
		unit.get_node("Selection").select()


func _feedback(message):
	if not _members().is_empty():
		_members()[0]._match.hud.show_notice(message)


func refresh():
	var available = _roster.player.coordination_unlocked
	if not is_instance_valid(_selected) or _selected.is_queued_for_deletion():
		_selected = null
	if _revision != _roster.revision:
		_revision = _roster.revision
		_options.clear()
		_options.add_item("Choose squad…")
		_entries = [null]
		for squad in _roster.squads():
			_entries.append(squad)
			_options.add_item(squad.title)
	_options.select(maxi(0, _entries.find(_selected)))
	for row in _editing_rows:
		row.visible = available
	_policy.visible = available
	_create.disabled = not available
	for button in [_rename, _add, _select, _disband, _policy]:
		button.disabled = _selected == null
	_remove.disabled = not _members().any(func(unit): return is_instance_valid(unit.program_squad))
	_policy.tooltip_text = (
		"Only running programs share targets, within their own legal assignments. "
		+ "Spread reduces duplicate shots; Focus favors a squadmate's target. "
		+ "Repair robots spread service targets. Independent disables sharing."
	)
	if _selected == null:
		_summary.text = "24 members max" if available else "Squads: research Coordination"
		return
	_policy.select(_selected.POLICIES.find(_selected.policy))
	var members = _selected.active_members()
	_summary.text = (
		"%d / 24 members · %d program-ready" % [members.size(), _selected.ready_members().size()]
	)
	_summary.tooltip_text = (
		"Unchipped members accept manual group orders. "
		+ "Select the squad to apply a program explicitly."
	)
