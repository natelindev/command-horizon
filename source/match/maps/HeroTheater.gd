extends "res://source/match/Map.gd"

const Landmarks = preload("res://source/match/world/MapLandmarks.gd")
const Catalog = preload("res://source/match/campaign/CampaignCatalog.gd")
var relays = []


func _ready():
	var mission = Catalog.STORIES[get_parent().settings.mission_id]
	var colors = {
		"city": "787b75",
		"spire": "626a72",
		"ford": "777966",
		"tunnels": "777060",
		"desert": "aa9270"
	}
	var ground = StandardMaterial3D.new()
	ground.albedo_color = Color(colors[mission.biome])
	ground.roughness = 1
	$Geometry/Terrain.material_override = ground
	for objective in mission.objectives:
		if objective.kind not in ["capture", "hold"]:
			relays.append(load("res://source/match/campaign/ObjectiveState.gd").new())
			continue
		var relay = load("res://source/match/objectives/CaptureRelay.gd").new()
		relay.position = Vector3(objective.point[0], 0, objective.point[1])
		relay.label_title = objective.title
		add_child(relay)
		relays.append(relay)
	_resources()
	_dress(mission)


func _resources():
	for anchor in [Vector2(9, 112), Vector2(38, 108), Vector2(66, 22), Vector2(120, 100)]:
		for index in 8:
			var kind = "ResourceB" if index > 5 else "ResourceA"
			var unit = load("res://source/match/units/non-player/%s.tscn" % kind).instantiate()
			unit.position = Vector3(anchor.x + (index % 4) * 2, 0, anchor.y + int(index / 4) * 3)
			$Resources.add_child(unit)


func _dress(mission):
	var assets = ["service_ruin", "road_pump", "relay_mast"]
	var biome = "industrial"
	if mission.biome == "desert":
		assets = ["freight_bay", "extraction_rig", "container"]
		biome = "desert"
	elif mission.biome in ["city", "spire"]:
		assets = ["substation", "service_ruin", "port_utilities"]
	elif mission.biome == "ford":
		assets = ["road_pump", "tank_wreck", "transfer_bay"]
		biome = "coastal"
	_terrain_details(mission.biome)
	var anchors = [
		Vector2(20, 24),
		Vector2(40, 14),
		Vector2(68, 105),
		Vector2(76, 12),
		Vector2(108, 18),
		Vector2(150, 20),
		Vector2(152, 110),
		Vector2(12, 56)
	]
	for index in anchors.size():
		var point = anchors[index]
		Landmarks._landmark(
			self,
			$Decorations,
			{"asset": assets[index % assets.size()], "position": point, "heading": index * 90.0},
			biome
		)
	# Roadside props give every approach landmarks while leaving broad convoy routes.
	for index in 24:
		var vegetation = load("res://source/match/maps/Vegetation.gd")
		var vegetation_biome = (
			"urban"
			if mission.biome in ["city", "spire"]
			else ("coastal" if mission.biome == "ford" else "desert")
		)
		var prop = (
			vegetation.tree(vegetation_biome, index, 6.5 + index % 3 * .5)
			if index % 3 == 0
			else vegetation.bush(index)
		)
		prop.position = Vector3(10 + index % 12 * 13, 0, 8 if index < 12 else 117)
		$Decorations.add_child(prop)
	# Urban objectives use the street network rather than a diagonal stripe across blocks.
	if mission.biome in ["city", "spire"]:
		return
	var route = [Vector3(18, 0, 100)]
	for objective in mission.objectives:
		route.append(Vector3(objective.point[0], 0, objective.point[1]))
	for index in route.size() - 1:
		var a = route[index]
		var b = route[index + 1]
		if a.distance_to(b) < 1:
			continue
		var road = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(7, .025, a.distance_to(b))
		road.mesh = mesh
		road.position = (a + b) / 2 + Vector3.UP * .02
		road.rotation.y = atan2(b.x - a.x, b.z - a.z)
		var material = StandardMaterial3D.new()
		material.albedo_color = Color("5e5c53")
		material.roughness = 1
		road.material_override = material
		$Decorations.add_child(road)


# The ford is shallow and traversable along its whole length. Its banks and
# crossing routes share coordinates in all three accounts of Cinder Ford.
func _terrain_details(biome):
	if biome == "ford":
		_surface("Riverbed", Vector3(81, .005, 60), Vector3(18, .01, 120), "8f8b73")
		_surface("ShallowWater", Vector3(81, .017, 60), Vector3(12, .01, 120), "66898c")
		for z in [32, 60, 82]:
			_surface("Ford", Vector3(81, .035, z), Vector3(23, .02, 9), "a29b7b")
	elif biome == "tunnels":
		# Open service trenches retain the isometric view of the escort route.
		for z in [20, 108]:
			_surface("DrainageChannel", Vector3(84, .02, z), Vector3(120, .02, 4), "4d6665")
			for x in [48, 88, 128]:
				_surface("ServiceBridge", Vector3(x, .05, z), Vector3(8, .04, 8), "88877a")
	elif biome in ["city", "spire"]:
		for x in [40, 80, 120]:
			_surface("DistrictStreet", Vector3(x, .008, 60), Vector3(9, .01, 116), "555d62")
		for z in [32, 64, 96]:
			_surface("CrossStreet", Vector3(84, .009, z), Vector3(164, .01, 7), "555d62")
		if biome == "spire":
			_surface("SpirePlaza", Vector3(138, .015, 44), Vector3(28, .01, 28), "929a9d")


func _surface(label, point, dimensions, color):
	var surface = MeshInstance3D.new()
	surface.name = label
	var mesh = BoxMesh.new()
	mesh.size = dimensions
	surface.mesh = mesh
	surface.position = point
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = .8
	surface.material_override = material
	$Decorations.add_child(surface)
