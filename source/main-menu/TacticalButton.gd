extends Button

const SHADER = preload("res://source/shaders/tactical_chamfer.gdshader")
const Console = preload("res://source/match/hud/BattleTheme.gd")

@export var index_code: String = ""
@export var subtitle_text: String = ""
@export var cut_size: float = 10.0
@export var button_height: int = 46
@export var is_primary: bool = false

var _bg: ColorRect
var _material: ShaderMaterial
var _content: MarginContainer
var _index_label: Label
var _icon_rect: TextureRect
var _title_label: Label
var _subtitle_label: Label
var _chevron: Label
var _tween: Tween
var _accent: Color = Console.PALETTES["bastion"].accent
var _ink: Color = Console.PALETTES["bastion"].ink


func _ready():
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = false

	# Keep native `text` intact for localization/tests while rendering custom layered typography.
	flat = true
	var empty = StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)
	for state in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_disabled_color",
		"icon_normal_color",
		"icon_hover_color",
		"icon_pressed_color",
		"icon_hover_pressed_color",
		"icon_focus_color",
		"icon_disabled_color"
	]:
		add_theme_color_override(state, Color(0, 0, 0, 0))

	custom_minimum_size = Vector2(0, button_height)

	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("cut_size", cut_size)
	_material.set_shader_parameter(
		"rect_size", size if size != Vector2.ZERO else custom_minimum_size
	)
	_material.set_shader_parameter("hover_glow", 0.0)
	_material.set_shader_parameter("scanline_strength", 0.025)

	_bg = ColorRect.new()
	_bg.material = _material
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	_content = MarginContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_theme_constant_override("margin_left", 14)
	_content.add_theme_constant_override("margin_right", 14)
	_content.add_theme_constant_override("margin_top", 4)
	_content.add_theme_constant_override("margin_bottom", 4)
	add_child(_content)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 10)
	_content.add_child(hbox)

	_index_label = Label.new()
	_index_label.text = index_code
	_index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_index_label.add_theme_font_override("font", Console.numeral_font())
	_index_label.add_theme_font_size_override("font_size", 13)
	_index_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_index_label.visible = not index_code.is_empty()
	hbox.add_child(_index_label)

	if icon != null:
		_icon_rect = TextureRect.new()
		_icon_rect.texture = icon
		_icon_rect.custom_minimum_size = Vector2(18, 18)
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(_icon_rect)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	hbox.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = tr(text)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_override("font", Console.display_font())
	_title_label.add_theme_font_size_override("font_size", 17 if is_primary else 16)
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = tr(subtitle_text) if not subtitle_text.is_empty() else ""
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_label.add_theme_font_size_override("font_size", 11)
	_subtitle_label.visible = not subtitle_text.is_empty()
	vbox.add_child(_subtitle_label)

	_chevron = Label.new()
	_chevron.text = "›"
	_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chevron.add_theme_font_override("font", Console.display_font())
	_chevron.add_theme_font_size_override("font_size", 20)
	_chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_chevron)

	sync_theme(Console.accent(), Console.ink())

	resized.connect(_on_resized)
	mouse_entered.connect(_on_highlight.bind(true))
	mouse_exited.connect(_on_highlight.bind(false))
	focus_entered.connect(_on_highlight.bind(true))
	focus_exited.connect(_on_highlight.bind(false))
	_on_resized()


func sync_theme(accent_col: Color, ink_col: Color):
	_accent = accent_col
	_ink = ink_col
	if not is_node_ready():
		return
	_material.set_shader_parameter("accent_color", _accent)
	if is_primary:
		_material.set_shader_parameter("bg_color", Color(_accent * 0.85, 0.96))
		_material.set_shader_parameter("border_color", Color(_accent.lightened(0.28), 0.95))
		_material.set_shader_parameter("left_accent_width", 0.0)
		_title_label.add_theme_color_override("font_color", _ink)
		_subtitle_label.add_theme_color_override("font_color", Color(_ink, 0.78))
		_index_label.add_theme_color_override("font_color", _ink)
		_chevron.add_theme_color_override("font_color", _ink)
		if _icon_rect:
			_icon_rect.modulate = _ink
	else:
		_material.set_shader_parameter("bg_color", Color(0.05, 0.08, 0.11, 0.84))
		_material.set_shader_parameter("border_color", Color(0.22, 0.30, 0.36, 0.82))
		_material.set_shader_parameter("left_accent_width", 3.5)
		_title_label.add_theme_color_override("font_color", Console.IVORY)
		_subtitle_label.add_theme_color_override("font_color", Console.MUTED)
		_index_label.add_theme_color_override("font_color", _accent)
		_chevron.add_theme_color_override("font_color", Color(_accent, 0.65))
		if _icon_rect:
			_icon_rect.modulate = Color(_accent.lerp(Console.IVORY, 0.55))
	queue_redraw()


func set_action_text(p_title: String, p_subtitle: String = ""):
	text = tr(p_title)
	subtitle_text = p_subtitle
	if _title_label:
		_title_label.text = tr(p_title)
	if _subtitle_label:
		_subtitle_label.text = tr(p_subtitle) if not p_subtitle.is_empty() else ""
		_subtitle_label.visible = not p_subtitle.is_empty()


func _on_resized():
	if _material:
		_material.set_shader_parameter("rect_size", size)


func _on_highlight(active: bool):
	queue_redraw()
	if _tween and _tween.is_valid():
		_tween.kill()
	var dur = 0.16 if Globals.options.menu_motion else 0.01
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var target_glow = 1.0 if active else 0.0
	var target_margin = 6.0 if active else 0.0
	var title_col = _ink if is_primary else (Color("ffffff") if active else Console.IVORY)
	var icon_col = _ink if is_primary else (Console.IVORY if active else _accent.lerp(Console.IVORY, 0.55))

	_tween.tween_method(
		func(val): _material.set_shader_parameter("hover_glow", val),
		_material.get_shader_parameter("hover_glow"),
		target_glow,
		dur
	)
	_tween.tween_property(
		_content, "theme_override_constants/margin_left", int(14 + target_margin), dur
	)
	_tween.tween_property(
		_chevron, "modulate", Color.WHITE if active else Color(1, 1, 1, 0.65), dur
	)
	_tween.tween_property(_title_label, "theme_override_colors/font_color", title_col, dur)
	if _icon_rect:
		_tween.tween_property(_icon_rect, "modulate", icon_col, dur)


func _draw():
	if has_focus():
		var s = size
		var bl = 8.0
		draw_line(Vector2(-3, -3), Vector2(-3 + bl, -3), _accent, 1.5)
		draw_line(Vector2(-3, -3), Vector2(-3, -3 + bl), _accent, 1.5)
		draw_line(Vector2(s.x + 3, -3), Vector2(s.x + 3 - bl, -3), _accent, 1.5)
		draw_line(Vector2(s.x + 3, -3), Vector2(s.x + 3, -3 + bl), _accent, 1.5)
		draw_line(Vector2(-3, s.y + 3), Vector2(-3 + bl, s.y + 3), _accent, 1.5)
		draw_line(Vector2(-3, s.y + 3), Vector2(-3, s.y + 3 - bl), _accent, 1.5)
		draw_line(Vector2(s.x + 3, s.y + 3), Vector2(s.x + 3 - bl, s.y + 3), _accent, 1.5)
		draw_line(Vector2(s.x + 3, s.y + 3), Vector2(s.x + 3, s.y + 3 - bl), _accent, 1.5)
