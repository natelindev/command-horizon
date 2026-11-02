extends Panel

signal finished(rect)

@export var interrupt_on_hitting_screen_margin = false
@export var screen_margin = 1

var _rect = null
var _mouse_position = Vector2.ZERO


func _ready():
	hide()


func _physics_process(_delta):
	_update()
	if interrupt_on_hitting_screen_margin and _screen_margin_hit():
		_interrupt()


func _input(event):
	if event is InputEventMouse:
		_mouse_position = _clamp_to_viewport(event.position)


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start(event.position)
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_finish(event.position)


func _clamp_to_viewport(pos: Vector2) -> Vector2:
	var viewport = get_viewport()
	if viewport == null:
		return pos
	var size = viewport.get_visible_rect().size
	return Vector2(clampf(pos.x, 0.0, size.x), clampf(pos.y, 0.0, size.y))


func _selecting():
	return _rect != null


func _screen_margin_hit():
	var viewport = get_viewport()
	if viewport == null:
		return false
	var viewport_size = viewport.get_visible_rect().size
	var mouse_pos = _mouse_position
	return (
		mouse_pos.x <= screen_margin
		or mouse_pos.x >= viewport_size.x - screen_margin
		or mouse_pos.y <= screen_margin
		or mouse_pos.y >= viewport_size.y - screen_margin
	)


func _start(mouse_pos):
	_mouse_position = _clamp_to_viewport(mouse_pos)
	_rect = Rect2(0, 0, 0, 0)
	_rect.position = _mouse_position


func _interrupt():
	_rect = null
	hide()


func _finish(mouse_pos):
	if not _selecting():
		return
	_rect.end = _clamp_to_viewport(mouse_pos)
	finished.emit(_rect.abs())
	_rect = null
	hide()


func _update():
	if not _selecting():
		return
	_rect.end = _mouse_position
	var absolute_rect = _rect.abs()
	if absolute_rect.has_area():
		show()
	position = absolute_rect.position
	size = absolute_rect.size
