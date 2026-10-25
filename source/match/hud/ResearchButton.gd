extends "res://source/match/hud/RosterButton.gd"

var _state: Label
var _marker: Label


func _init():
	super()
	_state = Label.new()
	_state.add_theme_font_override("font", BattleTheme.numeral_font())
	_state.add_theme_font_size_override("font_size", 13)
	_state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.get_parent().add_child(_state)


func show_state(value: String):
	_state.text = value
	_state.visible = not value.is_empty()
	_title.get_parent().get_node("Price").visible = value.is_empty()


func show_marker(value: String):
	if _marker == null:
		_marker = Label.new()
		_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_marker.add_theme_font_size_override("font_size", 12)
		_marker.add_theme_constant_override("outline_size", 3)
		_marker.add_theme_color_override("font_outline_color", Color("070a0c"))
		_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_marker.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_marker.offset_left = 4
		_marker.offset_right = -4
		_marker.offset_top = -20
		_marker.offset_bottom = -2
		add_child(_marker)
	_marker.text = value
	_marker.visible = not value.is_empty()
