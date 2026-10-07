extends Node3D

# Scenic footprint is outside the 184 x 132 m playable district.
const LANDMARKS = [
	["CanyonMesa2", Vector2(-22, 16), 1.2, .5, 11.0],
	["CanyonMesa1", Vector2(-23, 113), 1.35, 1.8, 11.0],
	["CanyonMesa3", Vector2(22, -19), 1.2, .3, 11.0],
	["CanyonMesa1", Vector2(70, -24), 1.3, 2.1, 11.0],
	["CanyonMesa2", Vector2(116, -22), 1.25, .4, 11.0],
	["CanyonMesa3", Vector2(173, -22), 1.2, 2.4, 11.0],
	["CanyonMesa1", Vector2(208, 16), 1.3, .7, 11.0],
	["CanyonMesa3", Vector2(211, 119), 1.15, 1.5, 11.0],
	["CanyonMesa2", Vector2(164, 157), 1.25, 1.9, 11.0],
	["CanyonMesa1", Vector2(31, 155), 1.1, .8, 11.0],
	["AbandonedFreightBay", Vector2(-15, 54), 1.0, 0.0, 6.0],
	["FrontierExtractionRig", Vector2(67, 150), 1.0, 1.2, 6.0],
	["DistrictUtilities", Vector2(206, 49), 1.0, 0.0, 10.0],
	["Substation", Vector2(206, 87), 1.0, .0, 10.0]
]
const SCRUB = [
	Vector2(-8, 35),
	Vector2(-9, 91),
	Vector2(8, -8),
	Vector2(42, -9),
	Vector2(86, -7),
	Vector2(141, -9),
	Vector2(163, -8),
	Vector2(193, 37),
	Vector2(195, 100),
	Vector2(187, 140),
	Vector2(142, 143),
	Vector2(91, 140),
	Vector2(54, 142),
	Vector2(10, 141)
]
var ground_material
var ground
var models = []


func _ready():
	name = "HorizonExterior"
	_ground()
	for entry in LANDMARKS:
		_model(entry[0], entry[1], entry[2], entry[3], entry[4])
	for point in SCRUB:
		_model("DryScrub", point, 1.0, point.x * .13, 1.8)


func _outside(point):
	return maxf(maxf(-point.x, point.x - 184), maxf(-point.y, point.y - 132))


func _raw_height(point):
	var relief = 1.6 + .7 * sin(point.x * .073 + point.y * .12)
	# The perimeter rises gently into a dry basin; landmarks sit on flat foundations.
	return relief * smoothstep(8.0, 30.0, _outside(point))


func height_at(point):
	var height = _raw_height(point)
	for entry in LANDMARKS:
		var radius = entry[2] * entry[4]
		var blend = 1.0 - smoothstep(radius, radius + 5, point.distance_to(entry[1]))
		height = lerpf(height, _raw_height(entry[1]), blend)
	return height * smoothstep(0.0, 3.0, _outside(point))


func _normal_at(point):
	var dx = Vector2(.1, 0)
	var dz = Vector2(0, .1)
	return (
		Vector3(
			height_at(point - dx) - height_at(point + dx),
			.2,
			height_at(point - dz) - height_at(point + dz)
		)
		. normalized()
	)


func _ground():
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(ground_material)
	for x in range(-46, 230, 2):
		for z in range(-46, 178, 2):
			if x >= -2 and x < 186 and z >= -2 and z < 134:
				continue
			var corners = [
				Vector2(x, z), Vector2(x + 2, z), Vector2(x, z + 2), Vector2(x + 2, z + 2)
			]
			for index in [0, 1, 2, 1, 3, 2]:
				var point = corners[index]
				surface.set_normal(_normal_at(point))
				surface.add_vertex(Vector3(point.x, height_at(point), point.y))
	ground = MeshInstance3D.new()
	ground.name = "DesertPerimeterGround"
	ground.mesh = surface.commit()
	add_child(ground)


func _model(asset, point, model_scale, turn, radius):
	var directory = (
		"industrial-surroundings" if asset in ["DistrictUtilities", "Substation"] else "desert"
	)
	var model = load("res://assets/models/environment/%s/%s.glb" % [directory, asset]).instantiate()
	load("res://source/match/maps/IndustrialMaterials.gd").weather(model)
	load("res://source/match/maps/DesertMaterials.gd").weather_stone(model)
	model.name = asset
	model.position = Vector3(point.x, height_at(point), point.y)
	model.scale = Vector3.ONE * model_scale
	model.rotation.y = turn
	model.set_meta("exterior_radius", radius * model_scale)
	add_child(model)
	models.append(model)
