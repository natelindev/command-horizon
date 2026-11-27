extends PanelContainer

const BattleTheme = preload("res://source/match/hud/BattleTheme.gd")

var _portrait: TextureRect
var _speaker: Label
var _text: Label


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A sleek, semi-transparent comms strip that keeps the battlefield legible behind it.
	var plate_style = StyleBoxFlat.new()
	plate_style.bg_color = Color(0.05, 0.07, 0.09, 0.84)
	plate_style.border_color = BattleTheme.accent().lerp(Color("4c5b63"), 0.55)
	plate_style.border_width_left = 2
	plate_style.border_width_top = 1
	plate_style.border_width_right = 1
	plate_style.border_width_bottom = 1
	plate_style.corner_radius_top_left = 3
	plate_style.corner_radius_top_right = 3
	plate_style.corner_radius_bottom_left = 3
	plate_style.corner_radius_bottom_right = 3
	plate_style.content_margin_left = 10
	plate_style.content_margin_right = 10
	plate_style.content_margin_top = 6
	plate_style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", plate_style)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var portrait_frame = PanelContainer.new()
	portrait_frame.theme_type_variation = "HudSocket"
	portrait_frame.add_theme_stylebox_override("panel", BattleTheme.socket(3, 3))
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.hide()
	row.add_child(portrait_frame)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(56, 56)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_portrait)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	var plate = PanelContainer.new()
	plate.add_theme_stylebox_override("panel", BattleTheme.nameplate(8, 1))
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(plate)
	_speaker = Label.new()
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker.theme_type_variation = "HudCaption"
	_speaker.add_theme_font_size_override("font_size", 11)
	_speaker.add_theme_color_override("font_color", BattleTheme.accent())
	plate.add_child(_speaker)
	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_color", Color("f2ece0"))
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.78))
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 1)
	column.add_child(_text)


func set_line(speaker, text, font_size):
	_speaker.text = tr(speaker).to_upper()
	_text.text = text
	_text.add_theme_font_size_override("font_size", font_size)
	reset_size()


func set_portrait(path):
	_portrait.texture = load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	_portrait.get_parent().visible = _portrait.texture != null
	reset_size()


func set_caption_visible(enabled):
	_text.visible = enabled
	reset_size()
