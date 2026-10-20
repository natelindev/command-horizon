extends "res://source/match/hud/RosterButton.gd"

var _state: Label


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
