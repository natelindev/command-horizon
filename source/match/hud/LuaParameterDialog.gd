extends CanvasLayer

signal accepted(values)
signal closed

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")

var values = []
var _fields


func _ready():
	layer = 36
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade = ColorRect.new()
	shade.color = Color("080e17dc")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 520
	BattleTheme.apply(panel, 20, 20)
	center.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title = Label.new()
	title.text = "PROGRAM PARAMETERS"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = minf(values.size() * 50, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_fields = load("res://source/match/hud/NumericParameters.gd").new()
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_fields)
	_fields.set_values(values)
	var note = Label.new()
	note.text = "Changes create a draft. Save and Apply remain separate."
	note.add_theme_font_size_override("font_size", 13)
	column.add_child(note)
	var row = HBoxContainer.new()
	column.add_child(row)
	var cancel = Button.new()
	cancel.text = "Cancel [Esc]"
	cancel.pressed.connect(close_dialog)
	row.add_child(cancel)
	var apply = Button.new()
	apply.text = "Update draft"
	apply.pressed.connect(
		func():
			accepted.emit(_fields.values)
			close_dialog()
	)
	row.add_child(apply)
	cancel.grab_focus()


func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_dialog()


func _unhandled_input(_event):
	get_viewport().set_input_as_handled()


func close_dialog():
	closed.emit()
	queue_free()
