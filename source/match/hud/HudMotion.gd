extends Node

## Short, event-driven feedback. Container geometry and pointer targets never move.
var _tween: Tween


static func play(control: Control, entrance = false):
	var motion = control.get_node_or_null("HudMotion")
	if motion == null:
		motion = load("res://source/match/hud/HudMotion.gd").new()
		motion.name = "HudMotion"
		control.add_child(motion)
	motion.animate(entrance)


func _ready():
	get_node("/root/Globals").options.changed.connect(_options_changed)


func _allowed():
	var options = get_node("/root/Globals").options
	return options.hud_motion and not options.reduced_flashes


func _options_changed():
	if not is_inside_tree():
		return
	if not _allowed():
		reset()


func reset():
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var control = get_parent()
	control.offset_transform_scale = Vector2.ONE
	control.offset_transform_position = Vector2.ZERO


func animate(entrance):
	reset()
	if not _allowed() or not get_parent().is_visible_in_tree():
		return
	var control = get_parent()
	control.offset_transform_enabled = true
	control.offset_transform_visual_only = true
	control.offset_transform_pivot_ratio = Vector2(.5, .5)
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if entrance:
		control.offset_transform_position = Vector2(10, 0)
		_tween.tween_property(control, "offset_transform_position", Vector2.ZERO, .28)
	else:
		_tween.tween_property(control, "offset_transform_scale", Vector2(1.035, 1.035), .12)
		_tween.tween_property(control, "offset_transform_scale", Vector2.ONE, .28)
