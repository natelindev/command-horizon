extends StaticBody3D

const DRAG_THRESHOLD = 18.0

var _rmb_drag_start = null
var _rmb_start_world = null

@onready var _collision_shape = find_child("CollisionShape3D")


func _ready():
	input_event.connect(_on_input_event)


func update_shape(reference_mesh):
	_collision_shape.shape = reference_mesh.create_trimesh_shape()


func _on_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
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
