extends RefCounted

# A compact circular arc faces the base. Opening nodes share the same HQ radius;
# three-metre chords leave room for two workers without the previous wide span.
const FIELD_DISTANCE = 18.0
const NODE_SPACING = 3.0
const SLOT_ORDER = [-2, -1, 0, 1, 2, -3, 3]


static func offsets():
	var result = []
	var step = 2.0 * asin(NODE_SPACING / (2.0 * FIELD_DISTANCE))
	for slot in SLOT_ORDER:
		var angle = slot * step
		result.append(Vector2(sin(angle), cos(angle) - 1.0) * FIELD_DISTANCE)
	return result


static func basis_for(map, fields, index):
	var start: Vector3 = map.get_node("SpawnPoints").get_child(index).position
	var origin = Vector2(start.x, start.z)
	var forward: Vector2 = (fields[index] - origin).normalized()
	var right = Vector2(forward.y, -forward.x)
	# Coastal starts share a shore-facing heading and mirror across the map.
	if index > 0:
		var first: Vector3 = map.get_node("SpawnPoints").get_child(0).position
		var first_heading: Vector2 = (fields[0] - Vector2(first.x, first.z)).normalized()
		if first_heading.dot(forward) > 0.0:
			right = -right
	return {"origin": origin, "forward": forward, "right": right}


static func overview(map, layout):
	var result = layout.duplicate(true)
	for index in 2:
		var frame = basis_for(map, layout.fields, index)
		result.fields[index] = frame.origin + frame.forward * FIELD_DISTANCE
	return result


static func apply(map, original_fields):
	var deposits = map.get_node("Resources").get_children()
	var fields = map.overview().fields
	var points = offsets()
	for index in fields.size():
		var frame = basis_for(map, original_fields, index % 2)
		var center: Vector2 = fields[index]
		# Coastal expansion arcs follow the shore, clear of pine stands and camps.
		if map.scene_file_path.ends_with("ExpandedCoastalFoundry.tscn") and index >= 4:
			frame.right = Vector2(0, 1)
		if map.scene_file_path.ends_with("ExpandedAlpineRelay.tscn") and index >= 2:
			frame.right = Vector2(0, 1)
		if frame.right == Vector2(0, 1):
			frame.forward = Vector2(1 if center.x < map.size.x / 2 else -1, 0)
		for slot in points.size():
			var point: Vector2 = (
				center + frame.right * points[slot].x + frame.forward * points[slot].y
			)
			var deposit = deposits[index * points.size() + slot]
			deposit.position = Vector3(point.x, deposit.position.y, point.y)
			deposit.harvest_origin = Vector3(center.x, 0, center.y)
