class Unit:
	const Movement = preload("res://source/match/utils/UnitMovementUtils.gd")
	const Placement = preload("res://source/match/utils/UnitPlacementUtils.gd")


const Resources = preload("res://source/match/utils/ResourceUtils.gd")


static func traverse_node_tree_and_replace_materials_matching_albedo(
	starting_node, albedo_to_match, epsilon, material_to_set, include_team_materials = false
):
	if starting_node == null:
		return
	for child in starting_node.find_children("*", "", true, false):
		if not "mesh" in child:
			continue
		for surface_id in range(child.mesh.get_surface_count()):
			var surface_material = child.mesh.get("surface_{0}/material".format([surface_id]))
			if (
				surface_material != null
				and (
					(
						include_team_materials
						and surface_material.resource_name.begins_with("TeamColor")
					)
					or Utils.Colour.is_equal_approx_with_epsilon(
						surface_material.albedo_color, albedo_to_match, epsilon
					)
				)
			):
				child.set("surface_material_override/{0}".format([surface_id]), material_to_set)


static func select_units(units_to_select):
	if not units_to_select.empty() and not Globals.options.selection_modifier_pressed():
		MatchSignals.deselect_all_units.emit()
	for unit in units_to_select.iterate():
		var selection = unit.find_child("Selection")
		if selection != null:
			selection.select()


static func find_unit_at_screen_point(
	tree: SceneTree, camera: Camera3D, screen_point: Vector2, prefer_mobile := false
):
	if tree == null or camera == null:
		return null
	var units = tree.get_nodes_in_group("units").filter(
		func(u): return is_instance_valid(u) and u.visible and not u.is_queued_for_deletion()
	)
	if units.is_empty():
		return null

	var best_unit = null
	var best_score = INF

	for unit in units:
		if camera.is_position_behind(unit.global_position):
			continue

		var col = unit.get_node_or_null("CollisionShape3D")
		var height = 1.2
		var radius = unit.radius if "radius" in unit and unit.radius != null else 0.8
		if col != null and col.shape != null:
			if "height" in col.shape:
				height = col.shape.height
			elif "size" in col.shape:
				height = col.shape.size.y
			if "radius" in col.shape:
				radius = maxf(radius, col.shape.radius)

		var base = unit.global_position
		var top = base + Vector3(0, height, 0)
		var p_base = camera.unproject_position(base)
		var p_top = camera.unproject_position(top)

		var camera_right = camera.global_transform.basis.x
		var p_edge = camera.unproject_position(base + camera_right * radius)
		var screen_radius = p_base.distance_to(p_edge)
		var threshold = maxf(screen_radius * 1.35, 18.0)

		var closest_pt = Geometry2D.get_closest_point_to_segment(screen_point, p_base, p_top)
		var dist = screen_point.distance_to(closest_pt)

		if dist <= threshold:
			var is_mobile = unit.has_method("_is_movable") and unit._is_movable()
			var is_controlled = unit.is_in_group("controlled_units")

			if prefer_mobile and not is_mobile:
				continue

			var tier = 0
			if is_mobile:
				tier = 0 if is_controlled else 1
			else:
				tier = 2 if is_controlled else 3

			var depth = camera.global_position.distance_to(base)
			var score = tier * 10000.0 + dist * 10.0 + depth * 0.01

			if score < best_score:
				best_score = score
				best_unit = unit

	return best_unit
