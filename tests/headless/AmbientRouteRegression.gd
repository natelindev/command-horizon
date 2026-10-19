extends SceneTree

const Catalog = preload("res://source/match/ambient/AmbientCatalog.gd")
var errors = []


func _initialize():
	for map in ["DesertFrontier", "ExpandedAlpineRelay", "CoastalFoundry", "CommandHorizonMap"]:
		for entry in Catalog.entries("res://source/match/maps/%s.tscn" % map):
			var distances = [-entry.length * 1.7, 0.0, entry.length, entry.length * 3.2]
			var cumulative = 0.0
			for index in entry.path.size():
				distances.append(cumulative)
				cumulative += entry.path[index].distance_to(
					entry.path[(index + 1) % entry.path.size()]
				)
				distances.append(cumulative - .000001)
				distances.append(cumulative + .000001)
			for distance in distances:
				if not Catalog.point(entry, distance).is_equal_approx(_reference(entry, distance)):
					errors.append("Route changed: %s at %f" % [entry.id, distance])
	# Interior routes are created directly, without Catalog.entries().
	var interiors = []
	Catalog._add(interiors, "resident", [[0, 0], [10, 0], [10, 10], [0, 10]], 2)
	for entry in interiors:
		if not Catalog.point(entry, entry.start).is_equal_approx(_reference(entry, entry.start)):
			errors.append("Interior route changed")
	for message in errors:
		push_error(message)
	print("Ambient route cache: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _reference(entry, distance):
	var remaining = fposmod(distance, entry.length)
	for index in entry.path.size():
		var a = entry.path[index]
		var b = entry.path[(index + 1) % entry.path.size()]
		var length = a.distance_to(b)
		if remaining <= length and length > 0:
			return a.lerp(b, remaining / length)
		remaining -= length
	return entry.path[0]
