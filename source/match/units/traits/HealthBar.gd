@tool
extends Node3D

const BAR_AUTO_VISIBILITY_DURATION = 2.0
const HEALTHY = Color("79d39a")
const WOUNDED = Color("e3c35a")
const CRITICAL = Color("e0645a")
const MISSING = Color("1c2329")
const BACKING = Color("0a0f12")
const DAMAGE_CHUNK = Color("f2d5a0")
const DAMAGE_HOLD = .24
const DAMAGE_DECAY = .6
const SHIELD = Color("68cee8")
const SHIELD_HEIGHT = 6
const SHIELD_GAP = 3
# Dark frame thickness in bar pixels on every side, for contrast against bright ground.
const FRAME = 2

@export var size = Vector2(200, 20):
	set(value):
		size = value
		var bar = find_child("ActualBar")
		if bar == null:
			return
		if bar.texture is GradientTexture2D:
			bar.texture.width = size.x
			bar.texture.height = size.y
		elif _image != null:
			# Resized after the runtime bar was drawn.
			_image = null
			_texture = null
			_draw_bar()

var _value = -1.0
var _damage_value = -1.0
var _damage_delay = 0.0
var _damage_speed = 0.0
var _drawn_damage_pixels = -1
var _drawn_health_pixels = -1
var _drawn_health_color = Color.TRANSPARENT
var _drawn_shield_pixels = -1
var _drawn_shield_enabled = false
var _selected = false
var _image: Image
var _texture: ImageTexture

@onready var _unit = get_parent()
@onready var _actual_bar = find_child("ActualBar")
@onready var _visibility_timer = find_child("Timer")


func _ready():
	if Engine.is_editor_hint():
		return
	set_process(false)
	hide()
	_recalulate_bar_value()
	_unit.selected.connect(_on_unit_selected)
	_unit.deselected.connect(_on_unit_deselected)
	_unit.hp_changed.connect(_on_hp_changed)
	if _unit.has_signal("shields_changed"):
		_unit.shields_changed.connect(_on_shields_changed)
	_visibility_timer.timeout.connect(_on_visibility_timer_timeout)
	var globals = get_node_or_null("/root/Globals")
	if globals != null and "options" in globals and globals.options != null:
		globals.options.changed.connect(_update_mode_visibility)
	_update_mode_visibility()


func _exit_tree():
	var globals = get_node_or_null("/root/Globals")
	if globals != null and "options" in globals and globals.options != null:
		if globals.options.changed.is_connected(_update_mode_visibility):
			globals.options.changed.disconnect(_update_mode_visibility)


func _health_bar_mode() -> int:
	var globals = get_node_or_null("/root/Globals")
	if (
		globals != null
		and "options" in globals
		and globals.options != null
		and "health_bars" in globals.options
	):
		return globals.options.health_bars
	return 0


func _update_mode_visibility():
	if not is_inside_tree() or not is_instance_valid(_unit):
		return
	var mode = _health_bar_mode()
	match mode:
		1:  # Always show
			_visibility_timer.stop()
			_draw_bar()
			show()
		2:  # Damaged only
			var damaged = _is_damaged()
			if _selected or damaged:
				_visibility_timer.stop()
				_draw_bar()
				show()
			else:
				hide()
		_:  # Selected only
			if _selected:
				_visibility_timer.stop()
				_draw_bar()
				show()
			elif _visibility_timer.is_stopped():
				hide()


func _track_width() -> int:
	return int(size.x)


func _is_damaged() -> bool:
	return (
		(_unit.hp != null and _unit.hp_max != null and _unit.hp < _unit.hp_max)
		or (
			"shields_max" in _unit and _unit.shields_max > 0.0 and _unit.shields < _unit.shields_max
		)
	)


func _recalulate_bar_value():
	if _unit.hp == null or _unit.hp_max == null:
		return
	var new_value = clampf(float(_unit.hp) / _unit.hp_max, 0.0, 1.0)
	if is_equal_approx(new_value, _value):
		return
	var initialized = _value >= 0.0
	if initialized and new_value < _value:
		_damage_value = maxf(_damage_value, _value)
		_damage_delay = DAMAGE_HOLD
		_damage_speed = (_damage_value - new_value) / DAMAGE_DECAY
	else:
		# Repairs and initialization never leave a false damage segment behind.
		_damage_value = new_value
	_value = new_value
	var track_w = _track_width()
	var visible_chunk = roundi(track_w * _damage_value) > roundi(track_w * _value)
	if not visible_chunk:
		_damage_value = _value
	set_process(visible_chunk)
	_draw_bar()
	if initialized:
		_show_for_a_while()


func _draw_bar():
	var width = int(size.x)
	var height = int(size.y)
	var track_x = FRAME
	var track_width = width
	var hp_height = height
	var shield_enabled = "shields_max" in _unit and _unit.shields_max > 0.0
	var shield_pixels = (
		roundi(track_width * clampf(_unit.shields / _unit.shields_max, 0.0, 1.0))
		if shield_enabled
		else 0
	)
	var health_y = FRAME + (SHIELD_HEIGHT + SHIELD_GAP if shield_enabled else 0)
	var image_height = health_y + hp_height + FRAME
	var damage_filled = roundi(track_width * _damage_value)
	var filled = roundi(track_width * _value)
	var health_color = _health_color(_value)
	# Damage can be smaller than a bar pixel. Preserve real HP and visibility,
	# without refilling and uploading an identical texture on every bullet hit.
	if (
		_image != null
		and _drawn_damage_pixels == damage_filled
		and _drawn_health_pixels == filled
		and _drawn_health_color == health_color
		and _drawn_shield_pixels == shield_pixels
		and _drawn_shield_enabled == shield_enabled
	):
		return
	if _image == null or _image.get_height() != image_height:
		_image = Image.create(width + FRAME * 2, image_height, false, Image.FORMAT_RGBA8)
		_texture = null
	_image.fill(BACKING)
	_drawn_damage_pixels = damage_filled
	_drawn_health_pixels = filled
	_drawn_health_color = health_color
	_drawn_shield_pixels = shield_pixels
	_drawn_shield_enabled = shield_enabled

	if shield_enabled:
		_image.fill_rect(Rect2i(track_x, FRAME, track_width, SHIELD_HEIGHT), MISSING)
		if shield_pixels > 0:
			_image.fill_rect(Rect2i(track_x, FRAME, shield_pixels, SHIELD_HEIGHT), SHIELD)
	_image.fill_rect(Rect2i(track_x, health_y, track_width, hp_height), MISSING)
	if damage_filled > 0:
		_image.fill_rect(Rect2i(track_x, health_y, damage_filled, hp_height), DAMAGE_CHUNK)
	if filled > 0:
		_image.fill_rect(Rect2i(track_x, health_y, filled, hp_height), health_color)
	_upload_bar()


func _upload_bar():
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
	var mode = _health_bar_mode()
	if mode == 1:
		_draw_bar()
		show()
		return
	if mode == 2:
		var damaged = _is_damaged()
		if _selected or damaged:
			_draw_bar()
			show()
		return
	show()
	if not _selected:
		_visibility_timer.start(BAR_AUTO_VISIBILITY_DURATION)


func _process(delta):
	if _damage_delay > 0.0:
		var held = minf(delta, _damage_delay)
		_damage_delay -= held
		delta -= held
	_damage_value = move_toward(_damage_value, _value, _damage_speed * delta)
	# Upload only when the displayed segment changes, not every frame on every unit.
	var track_w = _track_width()
	var settled = roundi(track_w * _damage_value) <= roundi(track_w * _value)
	if settled:
		_damage_value = _value
	if (
		(is_visible_in_tree() or settled)
		and _drawn_damage_pixels != roundi(track_w * _damage_value)
	):
		_draw_bar()
	if settled:
		set_process(false)


func _on_unit_selected():
	_selected = true
	_visibility_timer.stop()
	_draw_bar()
	show()


func _on_unit_deselected():
	_selected = false
	_update_mode_visibility()


func _on_hp_changed():
	_recalulate_bar_value()
	_update_mode_visibility()


func _on_shields_changed():
	_draw_bar()
	_show_for_a_while()
	_update_mode_visibility()


func _on_visibility_timer_timeout():
	_update_mode_visibility()
