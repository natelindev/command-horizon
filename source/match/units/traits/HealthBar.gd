@tool
extends Node3D

const BAR_AUTO_VISIBILITY_DURATION = 2.0
const HEALTHY = Color("79d39a")
const WOUNDED = Color("e3c35a")
const CRITICAL = Color("e0645a")
const MISSING = Color("1c2329")
const BACKING = Color("0a0f12")
# Dark frame thickness in bar pixels on every side, for contrast against bright ground.
const FRAME = 2

@export var size = Vector2(200, 20):
	set(value):
		size = value
		var bar = find_child("ActualBar")
		if bar.texture is GradientTexture2D:
			bar.texture.width = size.x
			bar.texture.height = size.y
		elif _image != null:
			# Resized after the runtime bar was drawn.
			_image = null
			_texture = null
			_draw_bar()

var _value = -1.0
var _image: Image
var _texture: ImageTexture

@onready var _unit = get_parent()
@onready var _actual_bar = find_child("ActualBar")
@onready var _visibility_timer = find_child("Timer")


func _ready():
	if Engine.is_editor_hint():
		return
	hide()
	_recalulate_bar_value()
	_unit.selected.connect(_on_unit_selected)
	_unit.deselected.connect(_on_unit_deselected)
	_unit.hp_changed.connect(_on_hp_changed)
	_visibility_timer.timeout.connect(_on_visibility_timer_timeout)


func _recalulate_bar_value():
	if _unit.hp == null or _unit.hp_max == null:
		return
	var new_value = clampf(float(_unit.hp) / _unit.hp_max, 0.0, 1.0)
	if is_equal_approx(new_value, _value):
		return
	var initialized = _value >= 0.0
	_value = new_value
	_draw_bar()
	if initialized:
		_show_for_a_while()


func _draw_bar():
	var width = int(size.x)
	var height = int(size.y)
	if _image == null:
		_image = Image.create(width + FRAME * 2, height + FRAME * 2, false, Image.FORMAT_RGBA8)
	_image.fill(BACKING)
	_image.fill_rect(Rect2i(FRAME, FRAME, width, height), MISSING)
	var filled = roundi(width * _value)
	if filled > 0:
		_image.fill_rect(Rect2i(FRAME, FRAME, filled, height), _health_color(_value))
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
		_actual_bar.texture = _texture
	else:
		_texture.update(_image)


func _health_color(fraction):
	if fraction > .6:
		return HEALTHY
	return WOUNDED if fraction > .3 else CRITICAL


func _show_for_a_while():
	if visible:
		return
	show()
	_visibility_timer.start(BAR_AUTO_VISIBILITY_DURATION)


func _on_unit_selected():
	_visibility_timer.stop()
	show()


func _on_unit_deselected():
	hide()


func _on_hp_changed():
	_recalulate_bar_value()


func _on_visibility_timer_timeout():
	hide()
