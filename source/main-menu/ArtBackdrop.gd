extends Control

@export var dim = .25

var _art: TextureRect
var _time = 0.0


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_art = TextureRect.new()
	_art.texture = preload("res://assets/ui/art/hangar-battlefield-menu.png")
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
	_layout()


func _layout():
	_art.position = -size * .025
	_art.size = size * 1.05


func _process(delta):
	if Globals.options.menu_motion:
		_time += delta
		_art.position = -size * .025 + Vector2(sin(_time * .06) * 8, cos(_time * .045) * 5)
