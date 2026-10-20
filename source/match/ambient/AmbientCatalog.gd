extends RefCounted

const STATS = {
	"car": {"health": 95.0, "radius": .7, "height": .65, "speed": 2.8},
	"resident": {"health": 22.0, "radius": .3, "height": 1.15, "speed": .85},
	"fox": {"health": 18.0, "radius": .28, "height": .38, "speed": 1.2},
	"gull": {"health": 12.0, "radius": .3, "height": .25, "speed": 3.5},
	"tug": {"health": 220.0, "radius": 1.8, "height": 2.4, "speed": 1.3}
}

# Match 1.15 m player infantry; a fox is knee-high and a car smaller than armor.
const MODEL_SCALES = {"resident": .75, "fox": .36, "car": .52, "gull": .36, "tug": 1.0}

const EXPANDED_MAPS = ["ExpandedDesertFrontier", "ExpandedAlpineRelay", "ExpandedCoastalFoundry"]
const BUILDING_HEALTH = 420.0
const HABITABLE = [
	"SawtoothWorkshop",
	"CoolingHall",
	"ServiceOffice",
	"DamagedWarehouse",
	"ServiceRuin",
	"PumpStation",
	"RelaySubstation"
]
# Stable authored order is also the save identity of repeated landmark models.
const STRUCTURES = {
	"IndustrialCrossroads":
	[
		"SawtoothWorkshop",
		"CoolingHall",
		"ServiceOffice",
		"DamagedWarehouse",
		"SawtoothWorkshop",
		"ServiceOffice"
	],
	"BrokenFoundryMap":
	[
		"SawtoothWorkshop",
		"CoolingHall",
		"ServiceOffice",
		"DamagedWarehouse",
		"FurnaceBlock",
		"FurnaceBlock"
	],
	"CommandHorizonMap": ["ServiceRuin", "PumpStation", "RelaySubstation"],
	"CoastalFoundry":
	[
		"SawtoothWorkshop",
		"HarborCrane",
		"HarborBeacon",
		"CoolingHall",
		"HarborCrane",
		"HarborBeacon",
		"CargoBarge"
	]
}


static func authored_name(map_path):
	var name = map_path.get_file().get_basename()
	return name.trim_prefix("Expanded") if name in EXPANDED_MAPS else name


# Compact settlements flank the central routes, clear of resource fields and passes.
static func settlements(map_path):
	match authored_name(map_path):
		"PlainAndSimple":
			return [Vector2(18, 25), Vector2(32, 25)]
		"BigArena":
			return [Vector2(40, 45), Vector2(60, 55)]
		"DesertFrontier":
			return [Vector2(45, 57), Vector2(83, 39)]
		"AlpineRelay":
			return [Vector2(45, 46), Vector2(83, 58)]
	return []


static func structures(map_path):
	var result = STRUCTURES.get(authored_name(map_path), []).duplicate()
	for point in settlements(map_path):
		result.append("ServiceOffice")
	return result


static func populate_settlements(map):
	for point in settlements(map.scene_file_path):
		load("res://source/match/maps/IndustrialLandmarks.gd").place(
			map.get_node("Decorations"), Vector3(point.x, 0, point.y), "ServiceOffice", 2.4, .36
		)


# Authored loops are map content, never executable or editable archive data.
static func entries(map_path):
	var result = []
	match authored_name(map_path):
		"CommandHorizonMap":
			_add(result, "car", [[34, 64.5], [67, 64.5], [67, 68], [34, 68]], 2)
			_add(result, "resident", [[45, 37], [59, 37], [59, 51], [45, 51]], 2)
			_add(result, "resident", [[45, 84], [59, 84], [59, 98], [45, 98]], 2)
			_add(result, "resident", [[81, 85], [95, 85], [95, 99], [81, 99]], 2)
			_add(result, "fox", [[33, 103], [42, 105], [41, 113], [30, 111]], 2)
		"BrokenFoundryMap":
			_add(result, "car", [[36, 24.5], [63, 24.5], [63, 28], [36, 28]], 2)
			_add(result, "resident", [[45, 33], [65, 33], [65, 53], [45, 53]], 2)
			_add(result, "resident", [[86, 63], [106, 63], [106, 83], [86, 83]], 2)
			_add(result, "fox", [[15, 11], [26, 13], [25, 19], [13, 18]], 2)
		"IndustrialCrossroads":
			_add(result, "car", [[38.5, 20.5], [89.5, 20.5], [89.5, 83.5], [38.5, 83.5]], 2)
			for point in [[52, 37], [52, 67], [76, 37], [76, 67]]:
				_add(
					result,
					"resident",
					[
						[point[0] - 9, point[1] - 9],
						[point[0] + 9, point[1] - 9],
						[point[0] + 9, point[1] + 9],
						[point[0] - 9, point[1] + 9]
					],
					2
				)
			_add(result, "fox", [[15, 88], [23, 88], [23, 97], [15, 97]], 2)
			_add(result, "fox", [[105, 7], [113, 7], [113, 16], [105, 16]], 2)
		"CoastalFoundry":
			_add(result, "car", [[30, 64], [98, 64], [98, 94], [30, 94]], 2)
			for x in [54, 74]:
				_add(
					result, "resident", [[x - 10, 70], [x + 10, 70], [x + 10, 90], [x - 10, 90]], 3
				)
			_add(result, "gull", [[54, 8], [66, 8], [66, 43], [54, 43]], 4, 3.8)
			_add(result, "tug", [[55, 16], [66, 16], [66, 46], [55, 46]], 1, -.5)
		"AlpineRelay":
			_add(result, "fox", [[27, 12], [39, 16], [36, 24], [25, 22]], 2)
			_add(result, "fox", [[89, 80], [103, 82], [101, 92], [91, 91]], 2)
		"DesertFrontier":
			_add(result, "fox", [[29, 8], [41, 9], [40, 15], [27, 16]], 2)
			_add(result, "fox", [[87, 80], [99, 81], [98, 87], [85, 88]], 2)
	for point in settlements(map_path):
		_add(
			result,
			"resident",
			[
				[point.x - 4, point.y - 4],
				[point.x + 4, point.y - 4],
				[point.x + 4, point.y + 4],
				[point.x - 4, point.y + 4]
			],
			3
		)
	match authored_name(map_path):
		"PlainAndSimple":
			_add(result, "fox", [[22, 32], [28, 32], [28, 36], [22, 36]], 2)
			_add(result, "car", [[22, 18], [28, 18], [28, 20], [22, 20]], 1)
		"BigArena":
			_add(result, "fox", [[46, 56], [52, 56], [52, 62], [46, 62]], 2)
			_add(result, "car", [[40, 49], [60, 49], [60, 51], [40, 51]], 2)
		"DesertFrontier":
			_add(result, "fox", [[53, 42], [61, 42], [61, 52], [53, 52]], 2)
			_add(result, "car", [[44, 47.5], [84, 47.5], [84, 48], [44, 48]], 2)
		"AlpineRelay":
			_add(result, "fox", [[43, 60], [49, 60], [49, 66], [43, 66]], 2)
			_add(result, "car", [[40, 34], [84, 34], [84, 38], [40, 38]], 2)
	if map_path.get_file().get_basename() in EXPANDED_MAPS:
		for entry in result:
			entry.path = entry.path.duplicate()
			for index in entry.path.size():
				entry.path[index] *= Vector3(1.5, 1, 1.5)
			entry.length *= 1.5
			entry.start *= 1.5
	return result


static func _add(result, kind, corners, count, height = 0.0):
	var path = PackedVector3Array()
	# Rounded corners keep traffic from pivoting abruptly at each waypoint.
	for index in corners.size():
		var previous = Vector3(
			corners[posmod(index - 1, corners.size())][0],
			height,
			corners[posmod(index - 1, corners.size())][1]
		)
		var current = Vector3(corners[index][0], height, corners[index][1])
		var next = Vector3(
			corners[(index + 1) % corners.size()][0],
			height,
			corners[(index + 1) % corners.size()][1]
		)
		var radius = minf(2.0, minf(current.distance_to(previous), current.distance_to(next)) * .35)
		var a = current.move_toward(previous, radius)
		var b = current.move_toward(next, radius)
		for step in range(9):
			var t = step / 8.0
			path.append(a.lerp(current, t).lerp(current.lerp(b, t), t))
	var length = 0.0
	for index in path.size():
		length += path[index].distance_to(path[(index + 1) % path.size()])
	for index in count:
		result.append(
			{
				"id": "%s-%02d" % [kind, result.size()],
				"kind": kind,
				"path": path,
				"length": length,
				"start": length * (index + .17) / count
			}
		)


static func point(entry, distance):
	var remaining: float = fposmod(distance, entry.length)
	var route: PackedVector3Array = entry.path
	# Authored routes (including campaign interiors) are immutable after setup.
	# Cache distances on first use, after any map scaling has been applied.
	if not entry.has("cumulative"):
		var measured = PackedFloat64Array([0.0])
		for index in route.size():
			measured.append(
				measured[-1] + route[index].distance_to(route[(index + 1) % route.size()])
			)
		entry.cumulative = measured
	var cumulative: PackedFloat64Array = entry.cumulative
	var low := 0
	var high := route.size() - 1
	while low < high:
		var middle := (low + high) / 2
		if cumulative[middle + 1] < remaining:
			low = middle + 1
		else:
			high = middle
	var length := cumulative[low + 1] - cumulative[low]
	if length <= 0.0:
		return route[low]
	return route[low].lerp(
		route[(low + 1) % route.size()], clampf((remaining - cumulative[low]) / length, 0.0, 1.0)
	)
