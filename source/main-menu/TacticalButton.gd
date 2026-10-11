extends Button

const SHADER = preload("res://source/shaders/tactical_chamfer.gdshader")

@export var index_code: String = "01 //"
@export var subtitle_text: String = ""
@export var cut_size: float = 12.0
@export var button_height: int = 52

var _bg: ColorRect
var _material: ShaderMaterial
var _content: MarginContainer
var _index_label: Label
var _icon_rect: TextureRect
var _title_label: Label
var _subtitle_label: Label
var _chevron: Label
var _tween: Tween


func _ready():
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(380, button_height)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = false

	# Clear native button styleboxes and default text rendering
	flat = true
	var empty = StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)
	for state in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_disabled_color"
	]:
		add_theme_color_override(state, Color(0, 0, 0, 0))

	custom_minimum_size = Vector2(0, button_height)

	# Tactical chamfered background
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("cut_size", cut_size)
	_material.set_shader_parameter(
		"rect_size", size if size != Vector2.ZERO else custom_minimum_size
	)
	_material.set_shader_parameter("hover_glow", 0.0)

	_bg = ColorRect.new()
	_bg.material = _material
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Content layout
	_content = MarginContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_theme_constant_override("margin_left", 14)
	_content.add_theme_constant_override("margin_right", 16)
	_content.add_theme_constant_override("margin_top", 4)
	_content.add_theme_constant_override("margin_bottom", 4)
	add_child(_content)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	_content.add_child(hbox)

	# Index code
	_index_label = Label.new()
	_index_label.text = index_code
	_index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_index_label.add_theme_color_override("font_color", Color("d8a846"))
	_index_label.add_theme_font_size_override("font_size", 13)
	_index_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_index_label.visible = not index_code.is_empty()
	hbox.add_child(_index_label)

	# Optional Icon
	if icon != null:
		_icon_rect = TextureRect.new()
		_icon_rect.texture = icon
		_icon_rect.custom_minimum_size = Vector2(20, 20)
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_rect.modulate = Color("acbcc4")
		_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(_icon_rect)

	# Title & Subtitle column
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	hbox.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = tr(text)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_color_override("font_color", Color("f1eee4"))
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = tr(subtitle_text)
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_label.add_theme_color_override("font_color", Color("6b828e"))
	_subtitle_label.add_theme_font_size_override("font_size", 10)
	_subtitle_label.visible = not subtitle_text.is_empty()
	vbox.add_child(_subtitle_label)

	# Right chevron
	_chevron = Label.new()
	_chevron.text = "›"
	_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chevron.add_theme_color_override("font_color", Color("d8a84688"))
	_chevron.add_theme_font_size_override("font_size", 20)
	_chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_chevron)

	resized.connect(_on_resized)
	mouse_entered.connect(_on_highlight.bind(true))
	mouse_exited.connect(_on_highlight.bind(false))
	focus_entered.connect(_on_highlight.bind(true))
	focus_exited.connect(_on_highlight.bind(false))
	_on_resized()


func set_action_text(p_title: String, p_subtitle: String = ""):
	text = p_title
	subtitle_text = p_subtitle
	if _title_label:
		_title_label.text = tr(p_title)
	if _subtitle_label:
		_subtitle_label.text = tr(p_subtitle)
		_subtitle_label.visible = not p_subtitle.is_empty()


func set_index(p_index: String):
	index_code = p_index
	if _index_label:
		_index_label.text = p_index
		_index_label.visible = not p_index.is_empty()


func _on_resized():
	if _material:
		_material.set_shader_parameter("rect_size", size)


func _on_highlight(active: bool):
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var target_glow = 1.0 if active else 0.0
	var target_margin = 8.0 if active else 0.0
	var chevron_col = Color("ffe59e") if active else Color("d8a84688")
	var title_col = Color("ffffff") if active else Color("f1eee4")
	var icon_col = Color("f1eee4") if active else Color("acbcc4")

	_tween.tween_method(
		func(val): _material.set_shader_parameter("hover_glow", val),
		_material.get_shader_parameter("hover_glow"),
		target_glow,
		0.18
	)
	_tween.tween_property(
		_content, "theme_override_constants/margin_left", int(14 + target_margin), 0.18
	)
	_tween.tween_property(
		_chevron, "modulate", Color.WHITE if active else Color(1, 1, 1, 0.6), 0.18
	)
	_tween.tween_property(_title_label, "theme_override_colors/font_color", title_col, 0.18)
	if _icon_rect:
		_tween.tween_property(_icon_rect, "modulate", icon_col, 0.18)


func _draw():
	if has_focus():
		var bracket_col = Color("d8a846")
		var s = size
		var bl = 8.0
		draw_line(Vector2(-3, -3), Vector2(-3 + bl, -3), bracket_col, 1.5)
		draw_line(Vector2(-3, -3), Vector2(-3, -3 + bl), bracket_col, 1.5)
		draw_line(Vector2(s.x + 3, -3), Vector2(s.x + 3 - bl, -3), bracket_col, 1.5)
		draw_line(Vector2(s.x + 3, -3), Vector2(s.x + 3, -3 + bl), bracket_col, 1.5)
		draw_line(Vector2(-3, s.y + 3), Vector2(-3 + bl, s.y + 3), bracket_col, 1.5)
		draw_line(Vector2(-3, s.y + 3), Vector2(-3, s.y + 3 - bl), bracket_col, 1.5)
		draw_line(Vector2(s.x + 3, s.y + 3), Vector2(s.x + 3 - bl, s.y + 3), bracket_col, 1.5)
		draw_line(Vector2(s.x + 3, s.y + 3), Vector2(s.x + 3, s.y + 3 - bl), bracket_col, 1.5)
