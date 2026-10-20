extends RefCounted

# Deterministic scenery inside the battlefield. Every solid model shares its real
# footprint with navigation, sight and aircraft clearance; low cover is instanced.
const Landmarks = preload("res://source/match/world/MapLandmarks.gd")
const Catalog = preload("res://source/match/campaign/CampaignCatalog.gd")
const Obstacle = preload("res://source/match/units/traits/MovementObstacle.tscn")
const KITS = {
	"city": ["industrial/ServiceOffice", "industrial/SawtoothWorkshop", "industrial/CoolingHall"],
	"spire":
	["industrial/ServiceOffice", "industrial-surroundings/Substation", "industrial/CoolingHall"],
	"desert": ["desert/AbandonedFreightBay", "supply/RoadPumpStation", "supply/RuinedTransferBay"],
	"ford": ["supply/RoadPumpStation", "coastal/PortUtilities", "industrial/ServiceOffice"],
	"tunnels":
	["quarry/QuarryCrusher", "quarry/QuarryConveyor", "industrial-surroundings/DistrictUtilities"],
	"alpine":
	["alpine/AbandonedCableStation", "alpine/MountainWeatherStation", "industrial/ServiceOffice"]
}
const TREES = {
	"city": "industrial-surroundings/BirchScrub",
	"spire": "industrial-surroundings/BirchScrub",
	"desert": "desert/DesertAcacia",
	"ford": "coastal/ShorePines",
	"tunnels": "desert/DesertJuniper",
	"alpine": "alpine/SnowPineGrove"
}


static func populate(map, mission_id):
	if mission_id.is_empty() or map.has_node("CampaignInterior"):
		return
	var biome = _biome(mission_id)
	var district = Node3D.new()
	district.name = "CampaignInterior"
	map.add_child(district)
	var protected = protection(map, mission_id)
	var occupied = protected.circles.duplicate()
	var batches = {}
	var extents = {}
	var random = RandomNumberGenerator.new()
	# Cinder Ford is the same place across all three accounts.
	random.seed = hash("cinder_ford" if biome == "ford" else mission_id)
	var urban = biome in ["city", "spire", "tunnels"]
	var compact = map.size.x < 120
	var spacing = 8.0 if compact else (11.0 if urban else 18.0)
	var serial = 0
	for row in range(1, int(map.size.y / spacing)):
		for column in range(1, int(map.size.x / spacing)):
			var point = Vector2(column * spacing, row * spacing)
			if not urban:
				point += Vector2(random.randf_range(-3, 3), random.randf_range(-3, 3))
			var radius = 2.5 if compact else (4.4 if urban else 3.8)
			if not _clear(
				point, radius, map.size, occupied, protected.roads, protected.road_clearance
			):
				continue
			var asset = KITS[biome][serial % KITS[biome].size()]
			var heading = (serial % 2) * PI if urban else (serial % 4) * PI / 2
			_solid(map, district, batches, extents, asset, point, radius, heading)
			occupied.append([point, radius + 2.0])
			serial += 1
	# Groves and scrub occupy the spaces between districts, not just the border.
	var count = int(map.size.x * map.size.y / 100)
	for index in count * 4:
		if index >= count and batches.get(TREES[biome], []).size() >= count / 2:
			break
		var point = Vector2(
			random.randf_range(4, map.size.x - 4), random.randf_range(4, map.size.y - 4)
		)
		if not _clear(point, 1.7, map.size, occupied, protected.roads, protected.road_clearance):
			continue
		# Three plants form a grove, with enough open space between groves for troops.
		for member in 3:
			var plant = point + Vector2.from_angle(member * TAU / 3) * 1.1
			var size = random.randf_range(.35, .65) if urban else random.randf_range(.45, .8)
			_batch(
				batches,
				TREES[biome],
				Transform3D(
					Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * size),
					Vector3(plant.x, 0, plant.y)
				)
			)
		occupied.append([point, 3.0])
	# Shared meshes keep the added population cheap to render.
	for asset in batches:
		Landmarks._multimesh(district, asset, batches[asset])
		district.get_child(-1).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_ground_patches(district, biome)
	var life = load("res://source/match/ambient/CampaignInteriorLife.gd").new()
	life.buildings = map.interior_obstacles
	map.add_child(life)
	district.set_meta("building_count", serial)
	district.set_meta("biome", biome)


static func _biome(id):
	if Catalog.is_story(id):
		return Catalog.STORIES[id].biome
	if id == "split_signal":
		return "alpine"
	return "city" if id in ["broken_foundry", "command_horizon"] else "desert"


static func protection(map, id):
	var circles = []
	var roads = []
	var starts = map.get_node("SpawnPoints").get_children()
	for start in starts:
		circles.append(
			[Vector2(start.position.x, start.position.z), 17.0 if map.size.x < 120 else 22.0]
		)
	for obstacle in map.find_children("*", "NavigationObstacle3D", true, false):
		if obstacle.get_parent().has_meta("campaign_scenery"):
			continue
		var point = map.to_local(obstacle.get_parent().global_position)
		circles.append([Vector2(point.x, point.z), obstacle.radius + 2.0])
	for resource in map.get_node("Resources").get_children():
		if not ("resource_a" in resource or "resource_b" in resource):
			continue
		var point = Vector2(resource.position.x, resource.position.z)
		circles.append([point, 5.0])
		var nearest = starts[0].position
		for start in starts:
			if (
				start.position.distance_squared_to(resource.position)
				< nearest.distance_squared_to(resource.position)
			):
				nearest = start.position
		roads.append(Vector4(nearest.x, nearest.z, point.x, point.y))
	for key in ["ENTRIES", "NODES", "SITES"]:
		if key in map:
			for point in map.get(key):
				circles.append([Vector2(point.x, point.z), 10.0])
	if "ENTRY" in map:
		circles.append([Vector2(map.ENTRY.x, map.ENTRY.z), 10.0])
	if map.has_method("overview"):
		roads.append_array(map.overview().get("roads", []))
	if "road_segments" in map:
		roads.append_array(map.road_segments)
	if id == "command_horizon":
		# The forward construction pocket is part of the mission's expansion space.
		circles.append([Vector2(65, 105), 7.0])
	if Catalog.is_story(id):
		var previous = Vector2(18, 100)
		for objective in Catalog.STORIES[id].objectives:
			var point = Vector2(objective.point[0], objective.point[1])
			circles.append([point, 13.0])
			roads.append(Vector4(previous.x, previous.y, point.x, point.y))
			previous = point
			if objective.has("destination"):
				var destination = Vector2(objective.destination[0], objective.destination[1])
				circles.append([destination, 10.0])
				roads.append(Vector4(point.x, point.y, destination.x, destination.y))
		var biome = Catalog.STORIES[id].biome
		if biome in ["city", "spire"]:
			for x in [40, 80, 120]:
				roads.append(Vector4(x, 0, x, map.size.y))
			for z in [32, 64, 96]:
				roads.append(Vector4(0, z, map.size.x, z))
		elif biome == "ford":
			roads.append(Vector4(81, 0, 81, map.size.y))
		elif biome == "tunnels":
			for z in [20, 108]:
				roads.append(Vector4(0, z, map.size.x, z))
	elif id == "supply_line":
		var route = [Vector2(18, 100), Vector2(64, 100), Vector2(100, 40), Vector2(170, 40)]
		for index in route.size() - 1:
			var a = route[index]
			var b = route[index + 1]
			roads.append(Vector4(a.x, a.y, b.x, b.y))
		for point in route:
			circles.append([point, 13.0])
	elif id == "first_orders":
		circles.append([Vector2(42, 40), 12.0])
		for road in [
			Vector4(14, 15, 42, 40),
			Vector4(14, 15, 26, 47),
			Vector4(26, 47, 42, 40),
			Vector4(42, 40, 65, 40)
		]:
			roads.append(road)
	# Objective nodes in the authored Bastion missions retain wide capture and combat space.
	for node in map.get_children():
		if node is Node3D and ("captured_by" in node or "capture_progress" in node):
			circles.append([Vector2(node.position.x, node.position.z), 12.0])
	# The finale sends replacement infantry past a standing armored guard. Preserve
	# lateral room for local avoidance along both reinforcement and assault corridors.
	return {
		"circles": circles,
		"roads": roads,
		"road_clearance": 11.0 if id == "command_horizon" else 5.0
	}


static func _clear(point, radius, size, circles, roads, road_clearance):
	if not Rect2(Vector2.ONE * (radius + 2), size - Vector2.ONE * (radius + 2) * 2).has_point(
		point
	):
		return false
	for circle in circles:
		if point.distance_to(circle[0]) < radius + circle[1]:
			return false
	for road in roads:
		var nearest = Geometry2D.get_closest_point_to_segment(
			point, Vector2(road.x, road.y), Vector2(road.z, road.w)
		)
		if point.distance_to(nearest) < radius + road_clearance:
			return false
	return true


static func _solid(map, parent, batches, extents, asset, point, radius, heading):
	if not extents.has(asset):
		var model = load("res://assets/models/environment/%s.glb" % asset).instantiate()
		extents[asset] = Landmarks._extent(model, Transform3D.IDENTITY)
		model.free()
	var extent = extents[asset]
	var scale = radius / maxf(.1, extent.x)
	var body = Node3D.new()
	body.name = "DistrictBuilding%d" % map.interior_obstacles.size()
	body.position = Vector3(point.x, 0, point.y)
	body.set_meta("campaign_scenery", asset)
	body.set_meta("clearance_radius", radius)
	body.set_meta("clearance_height", extent.y * scale)
	parent.add_child(body)
	var obstacle = Obstacle.instantiate()
	obstacle.name = "MovementObstacle"
	obstacle.radius = radius
	obstacle.sight_height = extent.y * scale
	obstacle.path_height_offset = .6
	obstacle.affect_navigation_mesh = true
	body.add_child(obstacle)
	map.interior_obstacles.append(body)
	if "flight_obstacles" in map:
		map.flight_obstacles.append(body)
	_batch(
		batches,
		asset,
		Transform3D(Basis(Vector3.UP, heading).scaled(Vector3.ONE * scale), body.position)
	)


static func _batch(batches, asset, transform):
	if not batches.has(asset):
		batches[asset] = []
	batches[asset].append(transform)


static func _ground_patches(parent, biome):
	var material = StandardMaterial3D.new()
	material.albedo_color = (
		Color("666b66") if biome in ["city", "spire", "tunnels"] else Color("877d61")
	)
	material.roughness = 1
	var mesh = BoxMesh.new()
	mesh.size = Vector3(9, .025, 9)
	mesh.material = material
	var buildings = parent.get_children().filter(
		func(node): return node.has_meta("campaign_scenery")
	)
	var batch = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = buildings.size()
	for index in buildings.size():
		batch.set_instance_transform(
			index,
			Transform3D(
				Basis.IDENTITY.scaled(
					Vector3.ONE * (buildings[index].get_meta("clearance_radius") * 2 + 1) / 9.0
				),
				buildings[index].position + Vector3(0, .02, 0)
			)
		)
	var instance = MultiMeshInstance3D.new()
	instance.name = "DistrictCourtyards"
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
