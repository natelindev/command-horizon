extends Node3D

@export var rectangular_selection_3d: NodePath

var _rectangular_selection_3d = null
var _highlighted_units = Utils.Set.new()


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
	for unit in get_tree().get_nodes_in_group("controlled_units"):
		if not unit.visible or unit.movement_domain != navigation_domain:
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


func _on_selection_changed(topdown_polygon_2d):
	var units_to_highlight = _get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
		Constants.Match.Navigation.Domain.TERRAIN, topdown_polygon_2d
	)
	units_to_highlight.merge(
		_get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
			Constants.Match.Navigation.Domain.AIR, topdown_polygon_2d
		)
	)
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
		Constants.Match.Navigation.Domain.TERRAIN, topdown_polygon_2d
	)
	units_to_select.merge(
		_get_controlled_units_from_navigation_domain_within_topdown_polygon_2d(
			Constants.Match.Navigation.Domain.AIR, topdown_polygon_2d
		)
	)
	Utils.Match.select_units(units_to_select)
