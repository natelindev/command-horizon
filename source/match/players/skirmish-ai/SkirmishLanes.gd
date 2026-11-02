extends RefCounted

# Attack lanes on authored battlefields. Each wave stages through one of the
# map's crossings, rotating between those whose detour stays reasonable, so
# offensives do not always arrive by the same shortest route.

const MAX_DETOUR = 1.6
const ARRIVAL = 9.0
const ARRIVED_SHARE = 0.6


static func choose(game, members, goal: Vector3, wave: int):
	var layout = game.map.get("layout")
	if layout == null or layout.is_empty() or members.is_empty():
		return null
	var lanes: Array = layout.get("ai", {}).get("lanes", [])
	if lanes.size() < 2:
		return null
	var origin = _centre(members)
	var nav = game.navigation.terrain.navigation_map_rid
	var query = game.navigation.path_query
	var direct = _length(nav, origin, goal, query)
	if not is_finite(direct):
		return null
	var usable = []
	for lane in lanes:
		var point = game.map.ground_point(lane)
		var through = _length(nav, origin, point, query) + _length(nav, point, goal, query)
		if through <= direct * MAX_DETOUR:
			usable.append(point)
	if usable.is_empty():
		return null
	return usable[wave % usable.size()]


# The wave moves on once most of it is at, or already beyond, the crossing.
static func reached(members, via: Vector3, goal: Vector3) -> bool:
	var through = 0
	var crossing = via * Vector3(1, 0, 1)
	var remaining = crossing.distance_to(goal * Vector3(1, 0, 1))
	for unit in members:
		var flat = unit.global_position_yless
		if (
			flat.distance_to(crossing) <= ARRIVAL
			or flat.distance_to(goal * Vector3(1, 0, 1)) < remaining
		):
			through += 1
	return through >= members.size() * ARRIVED_SHARE


static func _centre(members) -> Vector3:
	var centre = Vector3.ZERO
	for unit in members:
		centre += unit.global_position
	return centre / members.size()


static func _length(nav, from: Vector3, to: Vector3, query) -> float:
	var path = query.path(nav, from, to)
	if path.is_empty():
		return INF
	var length = 0.0
	for index in range(1, path.size()):
		length += path[index - 1].distance_to(path[index])
	return length
