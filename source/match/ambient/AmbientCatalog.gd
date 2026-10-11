extends RefCounted

const STATS = {
	"car": {"health": 95.0, "radius": 1.45, "height": 1.25, "speed": 2.8},
	"resident": {"health": 22.0, "radius": .4, "height": 1.6, "speed": .85},
	"fox": {"health": 18.0, "radius": .55, "height": 1.05, "speed": 1.2},
	"gull": {"health": 12.0, "radius": .5, "height": .7, "speed": 3.5},
	"tug": {"health": 220.0, "radius": 1.8, "height": 2.4, "speed": 1.3}
}

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


static func structures(map_path):
	return STRUCTURES.get(map_path.get_file().get_basename(), [])


# Authored loops are map content, never executable or editable archive data.
static func entries(map_path):
	var result = []
	match map_path.get_file().get_basename():
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
	var remaining = fposmod(distance, entry.length)
	for index in entry.path.size():
		var a = entry.path[index]
		var b = entry.path[(index + 1) % entry.path.size()]
		var length = a.distance_to(b)
		if remaining <= length and length > 0:
			return a.lerp(b, remaining / length)
		remaining -= length
	return entry.path[0]
