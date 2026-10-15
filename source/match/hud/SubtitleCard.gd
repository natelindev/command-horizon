extends PanelContainer

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")

var _speaker: Label
var _text: Label


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A comms plate: the speaker on an engraved nameplate above the transmission.
	BattleTheme.apply(self, 16, 12)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var plate = PanelContainer.new()
	plate.add_theme_stylebox_override("panel", BattleTheme.nameplate(10, 1))
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(plate)
	_speaker = Label.new()
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker.theme_type_variation = "HudCaption"
	_speaker.add_theme_font_size_override("font_size", 12)
	_speaker.add_theme_color_override("font_color", BattleTheme.accent())
	plate.add_child(_speaker)
	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_color", Color("eee8da"))
	column.add_child(_text)


func set_line(speaker, text, font_size):
	_speaker.text = tr(speaker).to_upper()
	_text.text = text
	_text.add_theme_font_size_override("font_size", font_size)
	reset_size()
