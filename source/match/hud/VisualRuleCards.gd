extends VBoxContainer

signal changed

const Rules = preload("res://source/match/programs/VisualRules.gd")
var document = Rules.starter(0)
var row_controls = []
var _retreat: SpinBox
var _recover: SpinBox
var _initial: OptionButton
var _states: CheckButton
var _rows: VBoxContainer
var _add: Button
var _updating = false


func _ready():
	add_theme_constant_override("separation", 10)
	var parameters = HBoxContainer.new()
	parameters.add_theme_constant_override("separation", 8)
	add_child(parameters)
	_text(parameters, "Retreat below")
	_retreat = _number(parameters, 10, 60, 5)
	_retreat.suffix = "%"
	_text(parameters, "Recover at")
	_recover = _number(parameters, 40, 95, 5)
	_recover.suffix = "%"
	_states = CheckButton.new()
	_states.text = "Show states"
	_states.tooltip_text = (
		"Show state conditions and transitions. "
		+ "Hiding these controls keeps their rules active."
	)
	parameters.add_child(_states)
	_initial = _options(parameters, Rules.STATES.map(func(state): return state.capitalize()))
	_initial.tooltip_text = "Starting state on Apply or Resume."
	_initial.hide()
	_states.toggled.connect(
		func(_value):
			_initial.visible = _states.button_pressed
			_render()
	)
	_retreat.value_changed.connect(func(value): _parameter("retreat", value))
	_recover.value_changed.connect(func(value): _parameter("recover", value))
	_initial.item_selected.connect(
		func(index):
			document.initial_state = Rules.STATES[index]
			changed.emit()
	)
	var help = _text(
		self, "First matching rule with an available target wins. Otherwise: hold & defend."
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)
	_add = _button(self, "Add rule", _add_rule)
	set_document(document)


func set_document(value):
	document = value.duplicate(true)
	if _rows == null:
		return
	_updating = true
	_retreat.value = document.parameters.retreat
	_recover.value = document.parameters.recover
	_initial.select(Rules.STATES.find(document.initial_state))
	_states.button_pressed = (
		document.initial_state != "normal"
		or document.rules.any(func(row): return row.state != "any" or row.next_state != "keep")
	)
	_initial.visible = _states.button_pressed
	_updating = false
	_render()


func _parameter(key, value):
	if not _updating:
		document.parameters[key] = int(value)
		changed.emit()


func _render():
	if _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	row_controls.clear()
	for index in range(document.rules.size()):
		var data = document.rules[index]
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color("24323f")
		style.set_corner_radius_all(5)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", style)
		_rows.add_child(panel)
		var stack = VBoxContainer.new()
		stack.add_theme_constant_override("separation", 6)
		panel.add_child(stack)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		stack.add_child(row)
		_text(row, "%02d" % (index + 1))
		var condition = _options(row, Rules.CONDITIONS.values())
		condition.custom_minimum_size.x = 205
		condition.select(Rules.CONDITIONS.keys().find(data.when))
		var bounds = Rules.range_for(data.when)
		var threshold = _number(row, bounds.x, bounds.y, bounds.z if bounds.z > 0 else 1)
		threshold.custom_minimum_size.x = 72
		threshold.value = data.value
		threshold.visible = bounds.z > 0
		condition.item_selected.connect(func(value): _condition_changed(index, value))
		threshold.value_changed.connect(
			func(value):
				document.rules[index].value = value
				changed.emit()
		)
		var action = _options(row, Rules.ACTIONS.values())
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.select(Rules.ACTIONS.keys().find(data.action))
		action.item_selected.connect(
			func(value):
				document.rules[index].action = Rules.ACTIONS.keys()[value]
				changed.emit()
		)
		var up = _button(row, "↑", func(): _move_rule(index, -1))
		up.tooltip_text = "Move rule earlier"
		up.disabled = index == 0
		var down = _button(row, "↓", func(): _move_rule(index, 1))
		down.tooltip_text = "Move rule later"
		down.disabled = index == document.rules.size() - 1
		var remove = _button(row, "×", func(): _remove_rule(index))
		remove.tooltip_text = "Remove rule"
		remove.disabled = document.rules.size() == 1
		var state_row = HBoxContainer.new()
		stack.add_child(state_row)
		state_row.visible = _states.button_pressed
		_text(state_row, "While")
		var state = _options(
			state_row, ["Any state"] + Rules.STATES.map(func(item): return item.capitalize())
		)
		state.select((["any"] + Rules.STATES).find(data.state))
		state.item_selected.connect(
			func(value):
				document.rules[index].state = (["any"] + Rules.STATES)[value]
				changed.emit()
		)
		_text(state_row, "then switch to")
		var next = _options(
			state_row, ["Keep state"] + Rules.STATES.map(func(item): return item.capitalize())
		)
		next.select((["keep"] + Rules.STATES).find(data.next_state))
		next.item_selected.connect(
			func(value):
				document.rules[index].next_state = (["keep"] + Rules.STATES)[value]
				changed.emit()
		)
		row_controls.append(
			{
				"condition": condition,
				"threshold": threshold,
				"action": action,
				"up": up,
				"down": down,
				"remove": remove,
				"state": state,
				"next": next
			}
		)
	_add.disabled = document.rules.size() >= Rules.MAX_RULES


func _condition_changed(index, selected):
	var condition = Rules.CONDITIONS.keys()[selected]
	document.rules[index].when = condition
	document.rules[index].value = Rules.range_for(condition).x
	_render()
	row_controls[index].condition.grab_focus()
	changed.emit()


func _add_rule():
	if document.rules.size() >= Rules.MAX_RULES:
		return
	document.rules.append(Rules.rule())
	_render()
	changed.emit()


func _remove_rule(index):
	if document.rules.size() <= 1:
		return
	document.rules.remove_at(index)
	_render()
	changed.emit()


func _move_rule(index, offset):
	var target = index + offset
	if target < 0 or target >= document.rules.size():
		return
	var row = document.rules.pop_at(index)
	document.rules.insert(target, row)
	_render()
	changed.emit()


func _text(parent, value):
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)
	return label


func _options(parent, values):
	var control = OptionButton.new()
	control.add_theme_font_size_override("font_size", 12)
	for value in values:
		control.add_item(value)
	parent.add_child(control)
	return control


func _number(parent, minimum, maximum, step_value):
	var control = SpinBox.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step_value
	control.add_theme_font_size_override("font_size", 12)
	parent.add_child(control)
	return control


func _button(parent, text, callback):
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 30
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
