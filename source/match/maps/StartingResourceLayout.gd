extends RefCounted

# Every map in the new-game picker uses this opening field, oriented toward its
# existing resource approach. Expansion fields keep their authored positions.
const FIELD_DISTANCE = 18.0
const MATERIAL_OFFSETS = [
	Vector2(-3.5, 0), Vector2.ZERO, Vector2(3.5, 0), Vector2(-1.75, -3.5), Vector2(1.75, -3.5)
]
const ELECTRONICS_OFFSETS = [Vector2(6.5, -2), Vector2(6.5, 1.5)]


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
	for index in 2:
		var frame = basis_for(map, original_fields, index)
		var center: Vector2 = frame.origin + frame.forward * FIELD_DISTANCE
		var offsets = MATERIAL_OFFSETS + ELECTRONICS_OFFSETS
		for slot in offsets.size():
			var point: Vector2 = (
				center + frame.right * offsets[slot].x + frame.forward * offsets[slot].y
			)
			var deposit = deposits[index * offsets.size() + slot]
			deposit.position = Vector3(point.x, deposit.position.y, point.y)
