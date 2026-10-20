extends RefCounted

# Story landmarks, salvage caches and ground dressing for skirmish maps.
# A layout authors one half (or quadrant) of a map; the remaining copies follow
# the map's start symmetry, so the starts that face each other in a skirmish
# meet the same landmarks and caches.

const Obstacle = preload("res://source/match/units/traits/MovementObstacle.tscn")
const Sites = preload("res://source/match/world/PointOfInterestCatalog.gd")
const Ambient = preload("res://source/match/ambient/AmbientCatalog.gd")
const Factions = preload("res://source/match/FactionCatalog.gd")
const WEATHERING = {
	"desert":
	[
		"res://source/match/maps/DesertMaterials.gd",
		"res://source/match/maps/QuarryMaterials.gd",
	],
	"alpine": ["res://source/match/maps/AlpineMaterials.gd"],
	"coastal": ["res://source/match/maps/CoastalMaterials.gd"],
	"industrial": ["res://source/match/maps/IndustrialMaterials.gd"],
	"plain": [],
}
# Models are scaled to the neutral settlement scale. The radius is the
# footprint that blocks paths and sight; a model that would overhang it is
# shrunk to fit, and its measured height sets sight and aircraft clearance.
const ASSETS = {
	"tank_wreck": {"wreck": "bastion/demo/Tank", "scale": .45, "crush": .75, "radius": 2.0},
	"gunship_wreck":
	{"wreck": "bastion/demo/Helicopter", "scale": .55, "crush": 1.0, "radius": 2.2},
	"container": {"model": "quarry/QuarryContainerA", "scale": .7, "radius": 1.7},
	"container_b": {"model": "quarry/QuarryContainerB", "scale": .7, "radius": 1.7},
	"service_ruin": {"model": "ServiceRuin", "scale": .55, "radius": 2.5},
	"relay_mast": {"model": "RelaySubstation", "scale": .5, "radius": 2.3},
	"freight_bay": {"model": "desert/AbandonedFreightBay", "scale": .8, "radius": 2.9},
	"transfer_bay": {"model": "supply/RuinedTransferBay", "scale": .8, "radius": 2.9},
	"road_pump": {"model": "supply/RoadPumpStation", "scale": .8, "radius": 2.9},
	"extraction_rig": {"model": "desert/FrontierExtractionRig", "scale": .38, "radius": 1.7},
	"cable_station": {"model": "alpine/AbandonedCableStation", "scale": .6, "radius": 2.8},
	"weather_station": {"model": "alpine/MountainWeatherStation", "scale": .32, "radius": 1.6},
	"substation": {"model": "industrial-surroundings/Substation", "scale": .5, "radius": 3.4},
	"pump_house": {"model": "coastal/PortPumpHouse", "scale": .55, "radius": 2.8},
	"port_utilities": {"model": "coastal/PortUtilities", "scale": .5, "radius": 3.1},
}
# Story groups in local metres: [asset, offset, heading in degrees].
const PREFABS = {
	"convoy":
	[
		["tank_wreck", Vector2.ZERO, 8.0],
		["container", Vector2(0, 4.8), -6.0],
		["container_b", Vector2(0.6, -4.7), 14.0],
	],
	"crash_site": [["gunship_wreck", Vector2.ZERO, 35.0]],
	"outpost": [["service_ruin", Vector2.ZERO, 0.0], ["container", Vector2(4.2, 2.6), 64.0]],
	"comms": [["relay_mast", Vector2.ZERO, 0.0]],
	"freight": [["freight_bay", Vector2.ZERO, 0.0]],
	"transfer": [["transfer_bay", Vector2.ZERO, 0.0], ["container_b", Vector2(-4.3, 1.4), 80.0]],
	"pump": [["road_pump", Vector2.ZERO, 0.0]],
	"rig": [["extraction_rig", Vector2.ZERO, 0.0], ["container", Vector2(3.6, -1.2), 28.0]],
	"cable_station": [["cable_station", Vector2.ZERO, 0.0]],
	"weather_station": [["weather_station", Vector2.ZERO, 0.0]],
	"substation": [["substation", Vector2.ZERO, 0.0]],
	"pump_house": [["pump_house", Vector2.ZERO, 0.0]],
	"port_utilities": [["port_utilities", Vector2.ZERO, 0.0]],
}
# Salvage cache deposits in local metres: [kind, offset, stock]. Piles stay
# 3.1 m apart so the largest ground unit can pass between them.
const CACHE = [
	["resource_a", Vector2(-1.75, 0), 300],
	["resource_a", Vector2(1.75, 0), 300],
	["resource_b", Vector2(0, 3.0), 300],
]
const SCATTER = {
	"desert": ["industrial-surroundings/BirchScrub"],
	"alpine": ["alpine/SnowPineGrove"],
	"industrial": ["industrial-surroundings/BirchScrub"],
	"coastal": ["industrial-surroundings/BirchScrub"],
	"plain": ["industrial-surroundings/BirchScrub"],
}

# Authored layouts: landmarks are [prefab, position, heading]; caches are
# [position, heading, optional story prefab, story position, story heading].
const LAYOUTS = {
	# The original desert keeps its compact open layout; it gains ground cover.
	"BastionDesert":
	{
		"biome": "desert",
		"symmetry": "rotate",
		"center": Vector2(32, 32),
		"landmarks": [["freight", Vector2(8, 57), 15.0]],
		"caches": [[Vector2(16, 43), 0.0]],
		"scatter": 34,
	},
	"DesertFrontier":
	{
		"biome": "desert",
		"symmetry": "rotate",
		"center": Vector2(64, 48),
		"landmarks":
		[
			["freight", Vector2(8, 84), 15.0],
			["rig", Vector2(30, 4), -10.0],
			["convoy", Vector2(38, 62), -15.0],
			["comms", Vector2(6, 6), 0.0],
		],
		"caches": [[Vector2(48, 90), 0.0, "crash_site", Vector2(41, 92), 30.0]],
		"scatter": 90,
	},
	"AlpineRelay":
	{
		"biome": "alpine",
		"symmetry": "rotate",
		"center": Vector2(64, 52),
		"landmarks":
		[
			["cable_station", Vector2(8, 94), 10.0],
			["weather_station", Vector2(4, 60), 0.0],
			["convoy", Vector2(50, 78), 90.0],
			["outpost", Vector2(24, 99), -6.0],
		],
		"caches": [[Vector2(40, 86), 20.0, "crash_site", Vector2(33, 90), 50.0]],
		"scatter": 90,
	},
	"IndustrialCrossroads":
	{
		"biome": "industrial",
		"symmetry": "rotate",
		"center": Vector2(64, 52),
		"landmarks":
		[
			["substation", Vector2(28, 100), 0.0],
			["convoy", Vector2(52, 87), 90.0],
		],
		"caches": [[Vector2(64, 100), 0.0]],
		"scatter": 60,
	},
	"CoastalFoundry":
	{
		"biome": "coastal",
		"symmetry": "mirror",
		"center": Vector2(64, 52),
		"landmarks":
		[
			["pump_house", Vector2(18, 100), 0.0],
			["port_utilities", Vector2(38, 74), 0.0],
			["crash_site", Vector2(56, 100), 30.0],
		],
		"caches": [[Vector2(64, 99), 0.0]],
		"scatter": 60,
	},
	"PlainAndSimple":
	{
		"biome": "plain",
		"symmetry": "quad",
		"center": Vector2(25, 25),
		# The open arena floor stays clear; contested refineries and cover only.
		"landmarks": [],
		"caches": [],
		"scatter": 24,
	},
	# Great Expanse hosts its sites on the flanks between the starts that face
	# each other in a skirmish; its open centre and home quarters stay clear.
	"BigArena":
	{
		"biome": "plain",
		"symmetry": "rotate",
		"center": Vector2(50, 50),
		"landmarks": [["crash_site", Vector2(33, 73), 20.0], ["freight", Vector2(25, 38), 0.0]],
		"caches": [[Vector2(25, 50), 0.0]],
		"scatter": 70,
	},
}


static func layout_name(map_path):
	return Ambient.authored_name(map_path)


# Every placement in final map coordinates, generated by the map's symmetry.
static func placements(map_path):
	var layout = LAYOUTS.get(layout_name(map_path), {})
	var result = {"landmarks": [], "caches": []}
	if layout.is_empty():
		return result
	var center = layout.center
	for entry in layout.landmarks:
		_add_group(result.landmarks, layout, center, entry[0], entry[1], entry[2])
	for entry in layout.caches:
		var anchor = entry[0]
		for deposit in CACHE:
			_add_copies(
				result.caches,
				layout,
				center,
				{
					"kind": deposit[0],
					"stock": deposit[2],
					"anchor": anchor,
					"position": anchor + deposit[1].rotated(deg_to_rad(entry[1])),
					"heading": entry[1]
				}
			)
		if entry.size() > 2:
			_add_group(result.landmarks, layout, center, entry[2], entry[3], entry[4])
	return result


static func _add_group(target, layout, center, prefab, position, heading):
	for part in PREFABS.get(prefab, [[prefab, Vector2.ZERO, 0.0]]):
		_add_copies(
			target,
			layout,
			center,
			{
				"asset": part[0],
				"position": position + part[1].rotated(deg_to_rad(heading)),
				"heading": heading + part[2]
			}
		)


static func _add_copies(target, layout, center, item):
	for transform in _symmetry(layout):
		var copy = item.duplicate()
		copy.position = _apply(transform, item.position, center)
		if item.has("anchor"):
			copy.anchor = _apply(transform, item.anchor, center)
		copy.heading = item.heading * transform.handedness + transform.turn
		# Elements on a symmetry axis are shared by both sides.
		if target.any(
			func(other):
				return (
					other.position.distance_to(copy.position) < .05
					and other.get("asset") == copy.get("asset")
				)
		):
			continue
		target.append(copy)


# Positions of a point under every symmetry of the map, in final coordinates.
static func images(map_path, point):
	var layout = LAYOUTS.get(layout_name(map_path), {})
	return _symmetry(layout).map(func(transform): return _apply(transform, point, layout.center))


static func _symmetry(layout):
	var identity = {"flip": Vector2.ONE, "handedness": 1.0, "turn": 0.0}
	match layout.symmetry:
		"rotate":
			return [identity, {"flip": -Vector2.ONE, "handedness": 1.0, "turn": 180.0}]
		"mirror":
			return [identity, {"flip": Vector2(-1, 1), "handedness": -1.0, "turn": 0.0}]
		"quad":
			return [
				identity,
				{"flip": Vector2(-1, 1), "handedness": -1.0, "turn": 0.0},
				{"flip": Vector2(1, -1), "handedness": -1.0, "turn": 180.0},
				{"flip": -Vector2.ONE, "handedness": 1.0, "turn": 180.0},
			]
	return [identity]


static func _apply(transform, point, center):
	return center + (point - center) * transform.flip


static func populate(map):
	if "points_of_interest" in map and map.points_of_interest.is_empty():
		Sites.populate(map)
	var layout = LAYOUTS.get(layout_name(map.scene_file_path), {})
	if layout.is_empty() or map.has_node("WorldDressing"):
		return
	var dressing = Node3D.new()
	dressing.name = "WorldDressing"
	map.add_child(dressing)
	var placed = placements(map.scene_file_path)
	for item in placed.landmarks:
		_landmark(map, dressing, item, layout.biome)
	for item in placed.caches:
		_cache(map, item)
	_scatter(map, dressing, layout, placed)


static func _landmark(map, parent, item, biome):
	var asset = ASSETS[item.asset]
	var body = Node3D.new()
	body.name = "%s%d" % [item.asset.to_pascal_case(), parent.get_child_count()]
	body.position = Vector3(item.position.x, 0, item.position.y)
	# Headings turn the same way as the authored 2D layout offsets.
	body.rotation.y = -deg_to_rad(item.heading)
	body.set_meta("landmark", item.asset)
	parent.add_child(body)
	var model = _wreck(asset) if asset.has("wreck") else _model(asset, biome)
	model.name = "Model"
	body.add_child(model)
	# The whole model stays inside the footprint that blocks paths and sight,
	# and aircraft clear its real height.
	var extent = _extent(model, Transform3D.IDENTITY)
	if extent.x > asset.radius:
		model.scale *= asset.radius / extent.x
		model.position *= asset.radius / extent.x
		extent *= asset.radius / extent.x
	var height = maxf(extent.y, .5)
	body.set_meta("clearance_radius", asset.radius)
	body.set_meta("clearance_height", height)
	var obstacle = Obstacle.instantiate()
	obstacle.name = "MovementObstacle"
	obstacle.radius = asset.radius
	obstacle.sight_height = height
	obstacle.path_height_offset = .6
	obstacle.affect_navigation_mesh = true
	body.add_child(obstacle)
	# Maps with aircraft clearance lift flights over every solid landmark.
	if "flight_obstacles" in map:
		map.flight_obstacles.append(body)


# Largest horizontal reach and height of every mesh vertex below a node.
static func _extent(node, parent_transform):
	var transform = parent_transform * node.transform if node is Node3D else parent_transform
	var result = Vector2.ZERO
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			for vertex in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point = transform * vertex
				result.x = maxf(result.x, Vector2(point.x, point.z).length())
				result.y = maxf(result.y, point.y)
	for child in node.get_children():
		var inner = _extent(child, transform)
		result = Vector2(maxf(result.x, inner.x), maxf(result.y, inner.y))
	return result


static func _model(asset, biome):
	var model = load("res://assets/models/environment/%s.glb" % asset.model).instantiate()
	model.scale = Vector3.ONE * asset.scale
	for script in WEATHERING[biome]:
		var materials = load(script)
		if materials.has_method("weather"):
			materials.weather(model)
		else:
			materials.weather_stone(model)
	return model


# A stripped, scorched hull of a lost vehicle; it is scenery, not salvage.
static func _wreck(asset):
	var holder = Node3D.new()
	var model = load("res://assets/models/%s.glb" % asset.wreck).instantiate()
	model.scale = Vector3(asset.scale, asset.scale * asset.crush, asset.scale)
	holder.add_child(model)
	var bounds = Factions._bounds(model, Transform3D.IDENTITY)
	model.position.y = -bounds.position.y - .12
	model.rotation = Vector3(.08, 0, -.11)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("5c5444")
	material.metallic = .35
	material.roughness = .92
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
	for node in model.find_children("*", "AnimationPlayer", true, false):
		node.queue_free()
	return holder


static func _cache(map, item):
	var scene = "ResourceA" if item.kind == "resource_a" else "ResourceB"
	var deposit = load("res://source/match/units/non-player/%s.tscn" % scene).instantiate()
	deposit.set(item.kind, item.stock)
	deposit.position = Vector3(item.position.x, 0, item.position.y)
	deposit.rotation.y = deg_to_rad(item.heading + item.position.x * 17.0)
	deposit.set_meta("salvage_cache", item.anchor)
	map.get_node("Resources").add_child(deposit)


# Scenic vegetation drawn with one multimesh per plant model. It never blocks
# paths, sight or construction and stays off roads, bases and objectives.
static func _scatter(map, parent, layout, placed):
	var count = maxi(1, roundi(layout.scatter * .35))
	var random = RandomNumberGenerator.new()
	random.seed = hash(layout_name(map.scene_file_path))
	var blockers = _scatter_blockers(map, placed)
	var assets = SCATTER[layout.biome]
	var transforms = []
	for index in assets.size():
		transforms.append([])
	var attempts = 0
	var accepted = 0
	# Plants gather in loose clumps of one kind rather than an even sprinkle.
	while accepted < count and attempts < count * 30:
		attempts += 1
		var center = Vector2(random.randf() * map.size.x, random.randf() * map.size.y)
		if not _open_ground(map, center, blockers):
			continue
		var choice = random.randi_range(0, assets.size() - 1)
		for member in random.randi_range(2, 5):
			var point = center + Vector2.from_angle(random.randf() * TAU) * random.randf() * 3.2
			if accepted >= count or not _open_ground(map, point, blockers):
				continue
			var size = random.randf_range(.9, 1.1)
			var basis = Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3(size, size, size))
			transforms[choice].append(Transform3D(basis, Vector3(point.x, .012, point.y)))
			accepted += 1
	for index in assets.size():
		if not transforms[index].is_empty():
			_multimesh(parent, assets[index], transforms[index])


static func _scatter_blockers(map, placed):
	var circles = []
	for start in map.get_node("SpawnPoints").get_children():
		circles.append([Vector2(start.position.x, start.position.z), 9.0])
	for deposit in map.get_node("Resources").find_children("*", "", true, false):
		if "resource_a" in deposit or "resource_b" in deposit:
			circles.append([Vector2(deposit.position.x, deposit.position.z), 2.4])
	for item in placed.landmarks:
		circles.append([item.position, ASSETS[item.asset].radius + 1.2])
	for site in Sites.definitions(map.scene_file_path):
		circles.append([site.position, 6.0])
	for child in map.get_node("Decorations").get_children():
		if child.has_node("MovementObstacle"):
			var radius = child.get_node("MovementObstacle").radius
			circles.append([Vector2(child.position.x, child.position.z), radius + 1.0])
	if map.has_method("overview"):
		var overview = map.overview()
		for point in overview.ridges:
			circles.append([point, overview.radius + 1.0])
		for point in overview.relays:
			circles.append([point, 4.0])
		return {"circles": circles, "overview": overview}
	return {"circles": circles, "overview": {}}


static func _open_ground(map, point, blockers):
	var margin = 3.0
	if (
		point.x < margin
		or point.y < margin
		or point.x > map.size.x - margin
		or point.y > map.size.y - margin
	):
		return false
	if map.has_method("is_land") and not map.is_land(Vector3(point.x, 0, point.y)):
		return false
	for circle in blockers.circles:
		if point.distance_to(circle[0]) < circle[1]:
			return false
	var overview = blockers.overview
	var half_width = overview.get("road_width", 4.0) / 2.0 + 2.5
	for road in overview.get("roads", []):
		var closest = Geometry2D.get_closest_point_to_segment(
			point, Vector2(road.x, road.y), Vector2(road.z, road.w)
		)
		if closest.distance_to(point) < half_width:
			return false
	for rect in overview.get("buildings", []):
		if rect.grow(1.5).has_point(point):
			return false
	return true


static func _multimesh(parent, asset, transforms):
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _merged_mesh(asset, 6.5 if "Pine" in asset else 1.9)
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var instance = MultiMeshInstance3D.new()
	instance.name = "%sCover" % asset.get_file()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)


# One mesh per model with a surface per material keeps each cover type to a
# few draw calls however many pieces the source model contains.
static func _merged_mesh(asset, height):
	var source = load("res://assets/models/environment/%s.glb" % asset).instantiate()
	load("res://source/match/maps/Vegetation.gd").fit_height(source, height)
	var tools = {}
	for mesh in source.find_children("*", "MeshInstance3D", true, false):
		var local = Transform3D.IDENTITY
		var node = mesh
		while node != source:
			local = node.transform * local
			node = node.get_parent()
		local = source.transform * local
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			if not tools.has(material):
				tools[material] = SurfaceTool.new()
				tools[material].begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material].set_material(material)
			tools[material].append_from(mesh.mesh, surface, local)
	var merged = ArrayMesh.new()
	for material in tools:
		tools[material].commit(merged)
	source.free()
	return merged
