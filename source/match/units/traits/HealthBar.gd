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
# Dark frame thickness in bar pixels on every side, for contrast against bright ground.
const FRAME = 2
const PIP_WIDTH = 14
const PIP_GAP = 2
const UNDERLINE_HEIGHT = 3

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
var _drawn_team_color = null
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
	_visibility_timer.timeout.connect(_on_visibility_timer_timeout)


func _team_color():
	if _unit != null and is_instance_valid(_unit) and "player" in _unit:
		var p = _unit.player
		if p != null and is_instance_valid(p) and "color" in p:
			return p.color
	return null


func _track_width() -> int:
	var width = int(size.x)
	return width - PIP_WIDTH - PIP_GAP if _team_color() != null else width


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
	var team_color = _team_color()
	var track_x = FRAME
	var track_width = width
	var hp_height = height
	if team_color != null:
		track_x = FRAME + PIP_WIDTH + PIP_GAP
		track_width = width - PIP_WIDTH - PIP_GAP
		hp_height = height - UNDERLINE_HEIGHT - 1
	var damage_filled = roundi(track_width * _damage_value)
	var filled = roundi(track_width * _value)
	var health_color = _health_color(_value)
	var team_matches = (
		(team_color == null and _drawn_team_color == null)
		or (team_color != null and _drawn_team_color != null and _drawn_team_color == team_color)
	)
	# Damage can be smaller than a bar pixel. Preserve real HP and visibility,
	# without refilling and uploading an identical texture on every bullet hit.
	if (
		_image != null
		and _drawn_damage_pixels == damage_filled
		and _drawn_health_pixels == filled
		and _drawn_health_color == health_color
		and team_matches
	):
		return
	if _image == null:
		_image = Image.create(width + FRAME * 2, height + FRAME * 2, false, Image.FORMAT_RGBA8)
	_image.fill(BACKING)
	_drawn_damage_pixels = damage_filled
	_drawn_health_pixels = filled
	_drawn_health_color = health_color
	_drawn_team_color = team_color

	if team_color != null:
		# Solid team ownership pip on the left
		_image.fill_rect(Rect2i(FRAME, FRAME, PIP_WIDTH, height), team_color)
		# Continuous team ownership underline beneath the health track
		_image.fill_rect(
			Rect2i(track_x, FRAME + hp_height + 1, track_width, UNDERLINE_HEIGHT), team_color
		)

	_image.fill_rect(Rect2i(track_x, FRAME, track_width, hp_height), MISSING)
	if damage_filled > 0:
		_image.fill_rect(Rect2i(track_x, FRAME, damage_filled, hp_height), DAMAGE_CHUNK)
	if filled > 0:
		_image.fill_rect(Rect2i(track_x, FRAME, filled, hp_height), health_color)
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
	hide()


func _on_hp_changed():
	_recalulate_bar_value()


func _on_visibility_timer_timeout():
	hide()
