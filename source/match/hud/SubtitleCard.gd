extends PanelContainer

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")

var _portrait: TextureRect
var _speaker: Label
var _text: Label


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A comms plate: the speaker on an engraved nameplate above the transmission.
	BattleTheme.apply(self, 16, 12)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(80, 80)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.hide()
	row.add_child(_portrait)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	row.add_child(column)
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


func set_portrait(path):
	_portrait.texture = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	_portrait.visible = _portrait.texture != null
	reset_size()


func set_caption_visible(enabled):
	_text.visible = enabled
	reset_size()
