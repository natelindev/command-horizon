extends Node3D

@export var rectangular_selection_3d: NodePath

var _rectangular_selection_3d = null
var _highlighted_units = Utils.Set.new()
var _selection_shape := ConvexPolygonShape3D.new()
var _selection_query := PhysicsShapeQueryParameters3D.new()
var _physics_candidates_enabled := not "--screen-selection" in OS.get_cmdline_user_args()


func _selection_candidates(camera: Camera3D, polygon: PackedVector2Array) -> Array:
	var controlled: Array = get_tree().get_nodes_in_group("controlled_units")
	# Preserve immediate highlights and release selection. A threaded physics
	# world may be locked during input; use the exact scan in that case.
	if (
		not _physics_candidates_enabled
		or polygon.size() != 4
		or (
			not Engine.is_in_physics_frame()
			and ProjectSettings.get_setting("physics/3d/run_on_separate_thread", false)
		)
	):
		return controlled
	var points := PackedVector3Array()
	var center := camera.global_position
	for depth in [camera.near, camera.far]:
		for point in polygon:
			points.append(camera.project_position(point, depth) - center)
	_selection_shape.points = points
	_selection_query.shape = _selection_shape
	_selection_query.transform = Transform3D(Basis.IDENTITY, center)
	_selection_query.collision_mask = 2 | 4
	_selection_query.collide_with_areas = true
	_selection_query.collide_with_bodies = false
	_selection_query.margin = 4.0
	# A saturated result cannot prove completeness; retain the exact scan then.
	var capacity := maxi(64, controlled.size() * 2 + 1)
	var hits := get_world_3d().direct_space_state.intersect_shape(_selection_query, capacity)
	if hits.size() >= capacity:
		return controlled
	var found := {}
	for hit in hits:
		found[hit.collider] = true
	var result: Array = []
	for unit in controlled:
		var collider = unit.get_node_or_null("CollisionShape3D")
		var depth: float = (camera.global_position - unit.global_position).dot(
			camera.global_basis.z
		)
		# Unregistered/disabled colliders must remain selectable. Exact projected
		# base/center/top tests below remain the authority at marquee edges.
		if (
			found.has(unit)
			or not unit.can_process()
			or not unit.is_node_ready()
			or not unit.global_basis.y.is_equal_approx(Vector3.UP)
			or depth < camera.near
			or depth > camera.far
			or unit.collision_layer & _selection_query.collision_mask == 0
			or collider == null
			or collider.disabled
			or collider.shape == null
			or not _samples_inside_collider(collider)
		):
			result.append(unit)
	return result


static func _samples_inside_collider(collider: CollisionShape3D) -> bool:
	if collider.transform.basis != Basis.IDENTITY:
		return false
	if not Vector2(collider.position.x, collider.position.z).is_zero_approx():
		return false
	var shape: Shape3D = collider.shape
	var height: float
	if shape is BoxShape3D:
		height = shape.size.y
	elif shape is CapsuleShape3D:
		height = (shape as CapsuleShape3D).height
	elif shape is CylinderShape3D:
		height = (shape as CylinderShape3D).height
	else:
		return false
	return is_equal_approx(collider.position.y, height * .5)


func _ready():
	_rectangular_selection_3d = get_node_or_null(rectangular_selection_3d)
	if _rectangular_selection_3d == null:
		return
	_rectangular_selection_3d.started.connect(_on_selection_started)
	_rectangular_selection_3d.interrupted.connect(_on_selection_interrupted)
	_rectangular_selection_3d.finished.connect(_on_selection_finished)


func _force_highlight(units_to_highlight):
	for unit in units_to_highlight.iterate():
		var highlight = unit.find_child("Highlight")
		if highlight != null:
			highlight.force()


func _unforce_highlight(units_not_to_highlight_anymore):
	for unit in units_not_to_highlight_anymore.iterate():
		if unit == null:
			continue
		var highlight = unit.find_child("Highlight")
		if highlight != null:
			highlight.unforce()


func _get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
	navigation_domain, topdown_polygon_2d
):
	var units_within_polygon = Utils.Set.new()
	if topdown_polygon_2d == null or topdown_polygon_2d.size() < 3:
		return units_within_polygon
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return units_within_polygon
	# Compare displayed positions at every altitude. Rebasing onto a unit's
	# plane fails when that plane lies behind a selection corner's ray origin.
	var screen_polygon = PackedVector2Array()
	for point in topdown_polygon_2d:
		screen_polygon.append(
			camera.unproject_position(Vector3(point.x, Constants.Match.Terrain.PLANE.d, point.y))
		)
	for unit in _selection_candidates(camera, screen_polygon):
		if (
			not unit.visible
			or (navigation_domain >= 0 and unit.movement_domain != navigation_domain)
		):
			continue
		if camera.is_position_behind(unit.global_position):
			continue
		var base_screen = camera.unproject_position(unit.global_position)
		if Geometry2D.is_point_in_polygon(base_screen, screen_polygon):
			units_within_polygon.add(unit)
			continue
		var col = unit.get_node_or_null("CollisionShape3D")
		var height = 1.2
		if col != null and col.shape != null:
			if "height" in col.shape:
				height = col.shape.height
			elif "size" in col.shape:
				height = col.shape.size.y
		var center_screen = camera.unproject_position(
			unit.global_position + Vector3(0, height * 0.5, 0)
		)
		if Geometry2D.is_point_in_polygon(center_screen, screen_polygon):
			units_within_polygon.add(unit)
			continue
		var top_screen = camera.unproject_position(unit.global_position + Vector3(0, height, 0))
		if Geometry2D.is_point_in_polygon(top_screen, screen_polygon):
			units_within_polygon.add(unit)
			continue
	return units_within_polygon


func _on_selection_started():
	_rectangular_selection_3d.changed.connect(_on_selection_changed)


func _is_harvesting_worker(unit: Node) -> bool:
	if not "type" in unit or unit.type != "Worker":
		return false
	if (
		("resource_a" in unit and unit.resource_a > 0)
		or ("resource_b" in unit and unit.resource_b > 0)
	):
		return true
	if "action" in unit and unit.action != null:
		var script_obj = unit.action.get_script()
		if script_obj != null and "CollectingResources" in script_obj.resource_path:
			return true
	return false


func _filter_combat_over_workers(units_set):
	if Input.is_key_pressed(KEY_ALT):
		return units_set
	var has_combat = false
	var has_harvesting_workers = false
	for unit in units_set.iterate():
		if _is_harvesting_worker(unit):
			has_harvesting_workers = true
		elif (
			("attack_range" in unit and unit.attack_range != null)
			or ("type" in unit and unit.type != "Worker")
		):
			has_combat = true
	if has_combat and has_harvesting_workers:
		var filtered = Utils.Set.new()
		for unit in units_set.iterate():
			if not _is_harvesting_worker(unit):
				filtered.add(unit)
		return filtered
	return units_set


func _on_selection_changed(topdown_polygon_2d):
	var units_to_highlight = _get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
		-1, topdown_polygon_2d
	)
	units_to_highlight = _filter_combat_over_workers(units_to_highlight)
	var units_not_to_highlight_anymore = Utils.Set.subtracted(
		_highlighted_units, units_to_highlight
	)
	_force_highlight(units_to_highlight)
	_unforce_highlight(units_not_to_highlight_anymore)
	_highlighted_units = units_to_highlight


func _on_selection_interrupted():
	_rectangular_selection_3d.changed.disconnect(_on_selection_changed)
	_unforce_highlight(_highlighted_units)
	_highlighted_units = Utils.Set.new()


func _on_selection_finished(topdown_polygon_2d):
	_rectangular_selection_3d.changed.disconnect(_on_selection_changed)

	_unforce_highlight(_highlighted_units)
	_highlighted_units = Utils.Set.new()
	var units_to_select = _get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
		-1, topdown_polygon_2d
	)
	units_to_select = _filter_combat_over_workers(units_to_select)
	Utils.Match.select_units(units_to_select)
