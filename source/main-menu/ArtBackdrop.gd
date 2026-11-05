extends Control

const Artwork = preload("res://source/main-menu/ArtworkCatalog.gd")

@export var dim = .25
@export var motion = true

var artwork_path = ""
var _art: TextureRect
var _time = 0.0


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	var veil = ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material = ShaderMaterial.new()
	material.shader = load("res://source/shaders/menu_atmosphere.gdshader")
	material.set_shader_parameter("dimming", dim)
	veil.material = material
	add_child(veil)
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	if is_visible_in_tree():
		reroll()
	_layout()


func _on_visibility_changed():
	if is_node_ready() and is_visible_in_tree():
		reroll()


func reroll():
	show_art(Artwork.next_background())


func show_art(path: String):
	artwork_path = path
	_art.texture = load(path)
	_time = 0.0
	_layout()


func _layout():
	_art.position = -size * .025
	_art.size = size * 1.05


func _process(delta):
	if motion and is_visible_in_tree() and Globals.options.menu_motion:
		_time += delta
		_art.position = -size * .025 + Vector2(sin(_time * .06) * 8, cos(_time * .045) * 5)
