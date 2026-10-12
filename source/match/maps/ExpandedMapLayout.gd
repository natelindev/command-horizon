extends RefCounted


# Widen travel corridors without changing the size of units, deposits or landmarks.
static func expand(map, original_fields, factor):
	for deposit in map.get_node("Resources").get_children():
		var point = Vector2(deposit.position.x, deposit.position.z)
		var anchor = original_fields[0]
		for field in original_fields:
			if point.distance_squared_to(field) < point.distance_squared_to(anchor):
				anchor = field
		var expanded = anchor * factor + point - anchor
		deposit.position = Vector3(expanded.x, deposit.position.y, expanded.y)
	for path in ["Decorations", "DesertGroundCover", "AlpineGroundCover"]:
		var group = map.get_node_or_null(path)
		if group == null:
			continue
		for child in group.get_children():
			child.position *= Vector3(factor, 1, factor)
	if "relays" in map:
		for relay in map.relays:
			relay.position *= Vector3(factor, 1, factor)
	if map.exterior != null:
		# The surrounding terrain remains outside the enlarged playable rectangle.
		map.exterior.ground.scale = Vector3(factor, 1, factor)
		for model in map.exterior.models:
			model.position *= Vector3(factor, 1, factor)


static func overview(original, factor, extra_fields, sites):
	var result = original.duplicate(true)
	for key in ["ridges", "fields", "relays", "land"]:
		if not result.has(key):
			continue
		for index in result[key].size():
			result[key][index] *= factor
	for index in result.roads.size():
		result.roads[index] *= factor
	for index in result.get("buildings", []).size():
		var original_rect = result.buildings[index]
		# Solid structures retain their footprint; only their centers move.
		result.buildings[index] = Rect2(
			original_rect.get_center() * factor - original_rect.size / 2, original_rect.size
		)
	result.fields.append_array(extra_fields)
	result.points_of_interest = sites.duplicate(true)
	return result


static func add_fields(map, fields, rotational_pairs = true):
	for index in fields.size():
		var point = fields[index]
		var mirror = 1 if index % 2 == 0 else -1
		for offset in [-2.5, 0.0, 2.5]:
			var deposit = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
			deposit.resource_a = 300
			deposit.position = Vector3(point.x + offset, 0, point.y)
			map.get_node("Resources").add_child(deposit)
		var electronics = load("res://source/match/units/non-player/ResourceB.tscn").instantiate()
		electronics.resource_b = 600
		electronics.position = Vector3(
			point.x + mirror * 5.5, 0, point.y + (mirror * 2 if rotational_pairs else 2)
		)
		map.get_node("Resources").add_child(electronics)


static func roads(map, segments):
	var material = map.get_node("Geometry/Terrain").mesh.material
	var points = PackedVector4Array(segments)
	points.resize(16)
	material.set_shader_parameter("roads", points)
