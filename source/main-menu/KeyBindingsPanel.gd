extends VBoxContainer

const Bindings = preload("res://source/input/KeyBindings.gd")
var dialog
var buttons = {}
var _capture_action = ""
var _modifier = 0
var _cancel_capture
var _message


func _ready():
	add_theme_constant_override("separation", 8)
	var description = Label.new()
	description.text = "Choose a command, then press a key or shortcut. Esc cancels key capture."
	description.add_theme_font_size_override("font_size", 14)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(description)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var section = ""
	var definitions = Bindings.definitions()
	for action in definitions:
		var definition = definitions[action]
		if section != definition[0]:
			section = definition[0]
			dialog._heading(list, section)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var title = dialog._label(row, definition[1], 14)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button = dialog._button(row, "", func(): begin_capture(action))
		button.custom_minimum_size.x = 150
		button.tooltip_text = "Change " + definition[1]
		buttons[action] = button
		var reset = dialog._button(row, "Reset", func(): _reset(action))
		reset.tooltip_text = "Restore default for " + definition[1]
	_message = dialog._label(
		self, "Esc always closes dialogs. Tab and Enter navigate their controls.", 13
	)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.y = 40
	_cancel_capture = dialog._button(self, "Cancel key capture [Esc]", cancel_capture)
	_cancel_capture.hide()
	refresh()


func begin_capture(action):
	cancel_capture()
	_capture_action = action
	buttons[action].text = "Press a key…"
	_message.text = (
		"Binding %s. Press Esc to keep its current key." % Bindings.definitions()[action][1]
	)
	_cancel_capture.show()


func cancel_capture():
	_capture_action = ""
	_modifier = 0
	if is_instance_valid(_cancel_capture):
		_cancel_capture.hide()
	if is_instance_valid(_message):
		_message.text = "Key capture cancelled. Previous binding kept."
	refresh()


func refresh():
	for action in buttons:
		buttons[action].text = Bindings.label(action)


func _reset(action):
	cancel_capture()
	_assign(action, Bindings.defaults().keys[action])


func _assign(action, code):
	var profile = dialog.options.key_bindings.duplicate(true)
	var error = Bindings.problem(action, code, profile.keys)
	if not error.is_empty():
		_message.text = error
		return false
	profile.keys[action] = code
	dialog._preview("key_bindings", profile)
	cancel_capture()
	_message.text = (
		"%s: %s. Save to keep this binding."
		% [Bindings.definitions()[action][1], Bindings.label(action)]
	)
	buttons[action].grab_focus()
	return true


func handle_key(event):
	if _capture_action.is_empty() or not event is InputEventKey:
		return false
	if event.echo:
		return true
	var code = Bindings.from_event(event)
	if (code & ~Bindings.MODIFIERS) == KEY_ESCAPE and event.pressed:
		cancel_capture()
		_message.text = "Key capture cancelled. Previous binding kept."
		return true
	if code in Bindings.MODIFIER_KEYS:
		if event.pressed:
			_modifier = code
		elif _modifier == code and _capture_action == "shift_selecting":
			_assign(_capture_action, code)
		return true
	if event.pressed:
		_modifier = 0
		_assign(_capture_action, code)
	return true
