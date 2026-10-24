extends StaticBody3D

const DRAG_THRESHOLD = 18.0
const Feedback = preload("res://source/match/effects/TerrainFeedback.gd")
const Movement = preload("res://source/match/utils/UnitMovementUtils.gd")

var _rmb_drag_start = null
var _rmb_start_world = null
var _formation_preview
var _preview_elapsed = 0.0
var _preview_heading = Vector3.INF
var _preview_count = -1

@onready var _collision_shape = find_child("CollisionShape3D")


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	input_event.connect(_on_input_event)
	set_process(false)


func update_shape(reference_mesh):
	_collision_shape.shape = reference_mesh.create_trimesh_shape()


func use_shape(shape: Shape3D, shape_transform: Transform3D):
	_collision_shape.shape = shape
	_collision_shape.transform = shape_transform


func _on_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	if _commands_blocked():
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and event.ctrl_pressed
	):
		var camera = get_viewport().get_camera_3d()
		var target_point = camera.get_ray_intersection(event.position) if camera != null else null
		if target_point != null:
			MatchSignals.tactical_ping.emit(target_point)
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_rmb_drag_start = event.position
			set_process(true)
			var camera = get_viewport().get_camera_3d()
			_rmb_start_world = (
				camera.get_ray_intersection(event.position) if camera != null else null
			)
			# Orders go out on press; a drag past the threshold revises them with
			# formation and facing on release.
			if _rmb_start_world != null:
				MatchSignals.terrain_targeted.emit(_rmb_start_world)
		else:
			_resolve_rmb(event.position)


func _unhandled_input(event):
	if (
		_rmb_drag_start != null
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and not event.pressed
	):
		_resolve_rmb(event.position)


func _resolve_rmb(mouse_pos):
	if _commands_blocked() or get_viewport().gui_get_hovered_control() != null:
		_cancel_drag()
		return
	_clear_preview()
	var start = _rmb_drag_start
	var start_world = _rmb_start_world
	_rmb_drag_start = null
	_rmb_start_world = null
	var camera = get_viewport().get_camera_3d()
	if (
		start == null
		or start_world == null
		or camera == null
		or mouse_pos.distance_to(start) <= DRAG_THRESHOLD
	):
		return
	var end_world = camera.get_ray_intersection(mouse_pos)
	if end_world == null:
		return
	var heading = (end_world - start_world) * Vector3(1, 0, 1)
	if heading.length() > 0.1:
		MatchSignals.terrain_target_heading_set.emit(start_world, heading.normalized())


func _input(event):
	if _rmb_drag_start == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_drag()
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and not event.pressed
	):
		# Resolve after GUI input so a release over HUD controls only cancels.
		_finish_drag.call_deferred(event.position)


func _finish_drag(pointer):
	if _rmb_drag_start == null:
		return
	if get_viewport().gui_get_hovered_control() != null or _commands_blocked():
		_cancel_drag()
	else:
		_resolve_rmb(pointer)


func _commands_blocked():
	var game = find_parent("Match")
	return (
		game != null
		and "hud" in game
		and is_instance_valid(game.hud)
		and game.hud.direct_orders._blocked()
	)


func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED]:
		_cancel_drag()


func _cancel_drag():
	_rmb_drag_start = null
	_rmb_start_world = null
	_clear_preview()


func _clear_preview():
	set_process(false)
	_preview_heading = Vector3.INF
	_preview_count = -1
	if is_instance_valid(_formation_preview):
		_formation_preview.queue_free()
	_formation_preview = null


func _process(delta):
	if _commands_blocked() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_cancel_drag()
		return
	_preview_elapsed += delta
	if _preview_elapsed < .033:
		return
	_preview_elapsed = 0.0
	_update_formation_preview(get_viewport().get_mouse_position())


func _update_formation_preview(pointer):
	var camera = get_viewport().get_camera_3d()
	if _rmb_drag_start == null or _rmb_start_world == null or camera == null:
		return
	if pointer.distance_to(_rmb_drag_start) <= DRAG_THRESHOLD:
		if is_instance_valid(_formation_preview):
			_formation_preview.hide()
		return
	var end = camera.get_ray_intersection(pointer)
	var heading = (
		((end - _rmb_start_world) * Vector3(1, 0, 1)).normalized() if end != null else Vector3.ZERO
	)
	if heading.is_zero_approx():
		return
	var game = find_parent("Match")
	var human = game._get_human_player() if game != null else null
	if human == null:
		return
	var controller = human.get_node("UnitActionsController")
	# Match the accepted press cohort; deselected or superseded orders cannot
	# acquire new units just by dragging the old gesture.
	var units = controller._ground_dispatch.get("tokens", {}).keys().filter(
		func(unit): return is_instance_valid(unit) and not unit.is_queued_for_deletion()
	)
	if units.is_empty():
		_clear_preview()
		return
	if not is_instance_valid(_formation_preview):
		_formation_preview = Feedback.new()
		_formation_preview.name = "FormationRibbon"
		_formation_preview.map = game.map
		add_child(_formation_preview)
	_formation_preview.show()
	if heading.is_equal_approx(_preview_heading) and units.size() == _preview_count:
		return
	_preview_heading = heading
	_preview_count = units.size()
	_formation_preview.begin()
	var color = Color("c8e5ed")
	for domain in [
		Constants.Match.Navigation.Domain.TERRAIN, Constants.Match.Navigation.Domain.AIR
	]:
		var cohort = units.filter(func(unit): return unit.movement_domain == domain)
		var slots = Movement.formation_positions(cohort, _rmb_start_world, heading)
		for index in slots.size():
			_formation_preview.slot(slots[index], heading, color)
			if index % 8 != 0:
				_formation_preview.line(slots[index - 1], slots[index], .14, Color(color, .35))
	_formation_preview.arrow(_rmb_start_world, heading, 3.0, color)
	_formation_preview.finish()
