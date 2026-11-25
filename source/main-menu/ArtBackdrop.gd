extends Control

const Artwork = preload("res://source/main-menu/ArtworkCatalog.gd")

@export var dim = .25
@export var motion = true
@export var left_focus = 0.0

var artwork_path = ""
var _art: TextureRect
var _fade_art: TextureRect
var _veil_material: ShaderMaterial
var _crossfade: Tween
var _time = 0.0


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_art = _make_layer()
	add_child(_art)
	_fade_art = _make_layer()
	_fade_art.visible = false
	add_child(_fade_art)
	var veil = ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil_material = ShaderMaterial.new()
	_veil_material.shader = load("res://source/shaders/menu_atmosphere.gdshader")
	_veil_material.set_shader_parameter("dimming", dim)
	_veil_material.set_shader_parameter("left_focus", left_focus)
	veil.material = _veil_material
	add_child(veil)
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	if is_visible_in_tree():
		reroll()
	_layout()


func _make_layer() -> TextureRect:
	var layer = TextureRect.new()
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return layer


func set_accent(color: Color):
	if _veil_material:
		_veil_material.set_shader_parameter("accent_tint", Vector3(color.r, color.g, color.b))


func _on_visibility_changed():
	if is_node_ready() and is_visible_in_tree():
		reroll()


func reroll():
	show_art(Artwork.next_background())


func show_art(path: String):
	var previous = _art.texture
	artwork_path = path
	var next_tex = load(path)
	if (
		previous != null
		and previous != next_tex
		and is_inside_tree()
		and is_visible_in_tree()
		and Globals.options.menu_motion
	):
		if _crossfade and _crossfade.is_valid():
			_crossfade.kill()
		_fade_art.texture = previous
		_fade_art.modulate.a = 1.0
		_fade_art.visible = true
		_art.texture = next_tex
		_crossfade = create_tween()
		_crossfade.tween_property(_fade_art, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
		_crossfade.finished.connect(func(): _fade_art.visible = false)
	else:
		_art.texture = next_tex
		if _fade_art:
			_fade_art.visible = false
	_time = 0.0
	_layout()


func _layout():
	var pos = -size * .025
	var target_size = size * 1.05
	_art.position = pos
	_art.size = target_size
	if _fade_art:
		_fade_art.position = pos
		_fade_art.size = target_size


func _process(delta):
	if motion and is_visible_in_tree() and Globals.options.menu_motion:
		_time += delta
		var offset = Vector2(sin(_time * .06) * 8, cos(_time * .045) * 5)
		_art.position = -size * .025 + offset
		if _fade_art and _fade_art.visible:
			_fade_art.position = _art.position
