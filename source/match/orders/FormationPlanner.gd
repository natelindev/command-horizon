extends RefCounted

## Tactical slot geometry and role-aware, minimum-distance assignment.
## All sizes describe clear space between hulls, rather than center spacing.
const POSTURES = ["line", "box", "flank", "staggered"]
const SUPPORT = [
	"Worker",
	"Artillery",
	"Howitzer",
	"RepairRobot",
	"RepairDepot",
	"ReconDrone",
	"Hero",
	"Commander"
]
const HEAVY = ["Tank", "AdvancedTank", "SiegeColossus", "Behemoth", "MobileRig"]
const FLANK_CORRIDOR = 6.0
const SPREAD_BUFFER = 2.5
const BOX_BUFFER = 1.5


static func posture(units) -> String:
	for unit in units:
		if "manual_orders" in unit and unit.manual_orders != null:
			return unit.manual_orders.formation
	return "line"


static func role(unit) -> int:
	var kind = str(unit.get("type"))
	if kind in SUPPORT or "Artillery" in kind or "Engineer" in kind or "Drone" in kind:
		return 2
	return 0 if kind in HEAVY else 1


static func spacing(units, formation: String, custom = 0.0, maximum_radius = -1.0) -> float:
	if custom > 0:
		return custom
	var radius = maximum_radius if maximum_radius >= 0.0 else _maximum_radius(units)
	return radius * 2.0 + (SPREAD_BUFFER if formation == "staggered" else BOX_BUFFER)


static func _maximum_radius(units) -> float:
	var radius = 0.0
	for unit in units:
		var value = unit.get("radius")
		if value != null:
			radius = maxf(radius, float(value))
	return radius


static func offsets(count: int, step: float, formation: String, radius = 0.0) -> Array:
	var result = []
	if count == 0:
		return result
	if count == 1:
		return [Vector2.ZERO]
	if formation == "flank":
		var wing_size = ceili(count / 2.0)
		var columns = maxi(1, ceili(sqrt(wing_size)))
		for index in count:
			var wing = index % 2
			var rank = index / 2
			var lateral = FLANK_CORRIDOR * .5 + radius + (rank % columns) * step
			result.append(Vector2(lateral * (-1.0 if wing == 0 else 1.0), -(rank / columns) * step))
	elif formation == "box":
		# Center sites first, then square rings. Role assignment protects support.
		result.append(Vector2.ZERO)
		var ring = 1
		while result.size() < count:
			for z in range(-ring, ring + 1):
				for x in range(-ring, ring + 1):
					if maxi(absi(x), absi(z)) == ring and result.size() < count:
						result.append(Vector2(x, z) * step)
			ring += 1
	elif formation == "staggered":
		var columns = ceili(sqrt(count))
		var rows = ceili(float(count) / columns)
		for index in count:
			var row = index / columns
			var column = index % columns
			result.append(
				Vector2(
					(column - (columns - 1) * .5 + (row % 2) * .5) * step,
					(row - (rows - 1) * .5) * step * sqrt(3.0) * .5
				)
			)
	else:
		# Two or three broad ranks. Small squads retain a single firing line.
		var rows = mini(3, ceili(count / 8.0))
		var columns = ceili(float(count) / rows)
		for index in count:
			var row = index / columns
			var column = index % columns
			var in_rank = mini(columns, count - row * columns)
			result.append(Vector2((column - (in_rank - 1) * .5) * step, -row * step))
	return result


static func positions(
	units,
	center: Vector3,
	heading: Vector3,
	formation = "line",
	custom = 0.0,
	maximum_radius = -1.0
) -> Array:
	var forward = (heading * Vector3(1, 0, 1)).normalized()
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	var right = Vector3(-forward.z, 0, forward.x)
	var radius = maximum_radius if maximum_radius >= 0.0 else _maximum_radius(units)
	var step = spacing(units, formation, custom, radius)
	var result = []
	for point in offsets(units.size(), step, formation, radius):
		result.append(center + right * point.x + forward * point.y)
	return result


static func assign(
	units, points: Array, formation = "line", captured_origins = PackedVector3Array()
) -> Array:
	# Partition role bands, then solve each band optimally. Reversed selection
	# order therefore cannot send every rear unit through the frontline.
	var indices = range(points.size())
	if formation == "box":
		var center = Vector3.ZERO
		for point in points:
			center += point
		center /= maxf(1, points.size())
		indices.sort_custom(
			func(a, b):
				return points[a].distance_squared_to(center) > points[b].distance_squared_to(center)
		)
	# Line points are already front-to-back. Flank/Staggered preserve free matching.
	var groups = [[], [], []] if formation in ["line", "box"] else [[]]
	for index in units.size():
		groups[role(units[index]) if groups.size() > 1 else 0].append(index)
	var result = []
	result.resize(units.size())
	var cursor = 0
	for group in groups:
		var origins = PackedVector3Array()
		var targets = PackedVector3Array()
		for index in group:
			var origin = (
				captured_origins[index]
				if captured_origins.size() == units.size()
				else units[index].global_position
			)
			origins.append(origin * Vector3(1, 0, 1))
		for index in group.size():
			targets.append(points[indices[cursor + index]] * Vector3(1, 0, 1))
		var columns = hungarian(origins, targets)
		for row in group.size():
			result[group[row]] = [units[group[row]], points[indices[cursor + columns[row]]]]
		cursor += group.size()
	return result


static func warm_native_solver() -> bool:
	# Load numerical kernels while the match opens, before the player's first
	# formation command. This does not enable optional movement or rendering.
	if OS.has_feature("double") or "--disable-native-kernels" in OS.get_cmdline_user_args():
		return false
	if ClassDB.class_exists("CopperfinCrowdRuntime"):
		return true
	var relative = "native/bin/copperfin.gdextension"
	var candidates = [
		OS.get_executable_path().get_base_dir().path_join(relative),
		ProjectSettings.globalize_path("res://" + relative),
	]
	for path in candidates:
		# Exported res:// paths can be relative. Resolve the library beside the
		# executable, as the production rendering loader does.
		if path.is_absolute_path() and _native_library_available(path):
			GDExtensionManager.load_extension(path)
			if ClassDB.class_exists("CopperfinCrowdRuntime"):
				return true
	return false


static func _native_library_available(path: String, feature_query = Callable()) -> bool:
	# A checkout may contain a descriptor generated for another platform. Avoid
	# asking the extension manager to load an unsupported or absent binary.
	if not FileAccess.file_exists(path):
		return false
	var descriptor = ConfigFile.new()
	if descriptor.load(path) != OK or not descriptor.has_section("libraries"):
		return false
	for key in descriptor.get_section_keys("libraries"):
		var compatible = true
		for feature in key.split("."):
			var supported: bool = (
				feature_query.call(feature) if feature_query.is_valid() else OS.has_feature(feature)
			)
			if not supported:
				compatible = false
				break
		if not compatible:
			continue
		var library = str(descriptor.get_value("libraries", key, ""))
		if library.is_empty():
			return false
		if not library.is_absolute_path():
			library = path.get_base_dir().path_join(library)
		return FileAccess.file_exists(library)
	return false


static func hungarian(origins: PackedVector3Array, points: PackedVector3Array) -> PackedInt32Array:
	if warm_native_solver():
		var solver = ClassDB.instantiate("CopperfinCrowdRuntime")
		if solver.has_method("assign_formation"):
			return solver.assign_formation(origins, points)
	return _hungarian_script(origins, points)


static func _hungarian_script(
	origins: PackedVector3Array, points: PackedVector3Array
) -> PackedInt32Array:
	var count = origins.size()
	if count != points.size() or count == 0:
		return PackedInt32Array()
	for index in count:
		if not origins[index].is_finite() or not points[index].is_finite():
			return PackedInt32Array()
	var cost = []
	for origin in origins:
		var row = PackedFloat64Array()
		for point in points:
			var x: float = float(origin.x) - float(point.x)
			var z: float = float(origin.z) - float(point.z)
			row.append(sqrt(x * x + z * z))
		cost.append(row)
	var u = PackedFloat64Array()
	var v = PackedFloat64Array()
	var row_of = PackedInt32Array()
	var way = PackedInt32Array()
	u.resize(count + 1)
	v.resize(count + 1)
	row_of.resize(count + 1)
	way.resize(count + 1)
	for row in range(1, count + 1):
		row_of[0] = row
		var column = 0
		var minimum = PackedFloat64Array()
		var used = PackedByteArray()
		minimum.resize(count + 1)
		minimum.fill(INF)
		used.resize(count + 1)
		while true:
			used[column] = 1
			var current = row_of[column]
			var delta = INF
			var next = 0
			for candidate in range(1, count + 1):
				if used[candidate] == 0:
					var reduced = cost[current - 1][candidate - 1] - u[current] - v[candidate]
					if reduced < minimum[candidate]:
						minimum[candidate] = reduced
						way[candidate] = column
					if minimum[candidate] < delta:
						delta = minimum[candidate]
						next = candidate
			for candidate in range(count + 1):
				if used[candidate] == 1:
					u[row_of[candidate]] += delta
					v[candidate] -= delta
				else:
					minimum[candidate] -= delta
			column = next
			if row_of[column] == 0:
				break
		while column != 0:
			var previous = way[column]
			row_of[column] = row_of[previous]
			column = previous
	var result = PackedInt32Array()
	result.resize(count)
	for column in range(1, count + 1):
		result[row_of[column] - 1] = column - 1
	return result


## Probe the common route once per command, compressing to one or two columns
## before a narrow portal and releasing the full final footprint beyond it.
static func funnel_routes(
	units, destination: Vector3, heading: Vector3, formation: String
) -> Dictionary:
	var result = {}
	units = units.filter(
		func(unit): return unit.movement_domain == 1 and not unit.get_node("Movement")._hovering
	)
	if units.size() < 3:
		return result
	var movement = units[0].get_node("Movement")
	if not movement._synchronized or movement.domain != 1:
		return result
	var nav = movement.get_navigation_map()
	var center = Vector3.ZERO
	var radius = .0
	for unit in units:
		center += unit.global_position
		radius = maxf(radius, unit.radius)
	center /= units.size()
	var path = movement._match.navigation.path_query.path(nav, center, destination)
	if path.size() < 2:
		return result
	var raw = positions(units, Vector3.ZERO, heading, formation, 0.0, radius)
	var full_width = 0.0
	var right = Vector3(-heading.z, 0, heading.x).normalized()
	if right.is_zero_approx():
		right = Vector3.RIGHT
	for point in raw:
		full_width = maxf(full_width, absf(point.dot(right)) + radius)
	var gates = []
	var travelled = 0.0
	var previous_gate = -100.0
	for segment in range(1, path.size()):
		var delta = (path[segment] - path[segment - 1]) * Vector3(1, 0, 1)
		var length = delta.length()
		if length <= .01:
			continue
		var forward = delta / length
		var lateral = Vector3(-forward.z, 0, forward.x)
		for sample in range(ceili(length / 2.0) + 1):
			var along = minf(length, sample * 2.0)
			var point = path[segment - 1] + forward * along
			var distance = travelled + along
			if (
				distance < 3.0
				or distance - previous_gate < 3.0
				or point.distance_to(destination) < 3.0
			):
				continue
			var width = full_width
			for sign_value in [-1.0, 1.0]:
				var clearance = full_width
				for probe in range(1, ceili(full_width) + 1):
					var offset = minf(full_width, probe * 1.0)
					var candidate = point + lateral * offset * sign_value
					var projected = NavigationServer3D.map_get_closest_point(nav, candidate)
					if ((projected - candidate) * Vector3(1, 0, 1)).length() > .2:
						clearance = maxf(0.0, offset - 1.0)
						break
				width = minf(width, clearance)
			if width >= full_width - .01:
				continue
			var columns = 2 if width >= radius * 2.0 + .4 else 1
			gates.append({"point": point, "forward": forward, "right": lateral, "columns": columns})
			previous_gate = distance
		travelled += length
	if gates.is_empty():
		return result
	# Every member uses one of the same one/two lanes at a gate. Project each
	# lane once per command, rather than repeating an identical navmesh search
	# for every unit. Keep the route arrays below independent: units consume
	# their own waypoints as they cross each portal.
	for gate in gates:
		var lanes = []
		for column in gate.columns:
			var offset = (float(column) - (gate.columns - 1) * .5) * (radius * 2.0 + .35)
			var point = gate.point + gate.right * offset
			lanes.append(NavigationServer3D.map_get_closest_point(nav, point) * Vector3(1, 0, 1))
		gate.lanes = lanes
	# Sort by route-relative position so the nearest units enter the portal first.
	var ordered = units.duplicate()
	ordered.sort_custom(
		func(a, b):
			return (
				a.global_position.distance_squared_to(gates[0].point)
				< b.global_position.distance_squared_to(gates[0].point)
			)
	)
	for index in ordered.size():
		var route = []
		for gate in gates:
			route.append(gate.lanes[index % gate.columns])
		result[ordered[index]] = route
	return result
