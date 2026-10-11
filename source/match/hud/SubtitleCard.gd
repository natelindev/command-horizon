extends PanelContainer

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")

var _speaker: Label
var _text: Label


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	BattleTheme.apply(self, 16, 10)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	_speaker = Label.new()
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker.add_theme_font_size_override("font_size", 12)
	_speaker.add_theme_color_override("font_color", Color("a9b4b3"))
	column.add_child(_speaker)
	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_color", Color("eee8da"))
	column.add_child(_text)


func set_line(speaker, text, font_size):
	_speaker.text = speaker.to_upper()
	_text.text = text
	_text.add_theme_font_size_override("font_size", font_size)
	reset_size()
