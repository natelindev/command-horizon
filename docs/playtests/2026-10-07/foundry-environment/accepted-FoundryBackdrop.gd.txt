extends Node3D

# Scenic footprint is outside the 160 x 116 m playable district.
const LANDMARKS = [
	["RailServiceBay", Vector2(44, -29), 1.0, 0.0, 12.0],
	["RailWagon", Vector2(76, -15), 1.0, 0.0, 11.0],
	["RailWagon", Vector2(99, -15), 1.0, 0.0, 11.0],
	["DistrictUtilities", Vector2(64, 134), 1.0, 0.0, 10.0],
	["Substation", Vector2(112, 135), 1.0, 0.0, 10.0],
	["RailServiceBay", Vector2(180, 58), 0.9, PI / 2, 12.0]
]
const GROVES = [
	Vector3(-9, 12, .9),
	Vector3(-11, 35, .8),
	Vector3(-9, 82, 1.0),
	Vector3(-8, 108, .8),
	Vector3(171, 12, .9),
	Vector3(173, 32, .8),
	Vector3(171, 87, .9),
	Vector3(175, 111, 1.0),
	Vector3(16, 127, 1.0),
	Vector3(27, 133, .8),
	Vector3(86, 130, .9),
	Vector3(143, 128, 1.0),
	Vector3(153, 134, .8),
	Vector3(13, -9, .9),
	Vector3(129, -10, .8),
	Vector3(143, -8, 1.0)
]
var ground_material
var ground
var models = []


func _ready():
	name = "FoundryExterior"
	_ground()
	for entry in LANDMARKS:
		_model(entry[0], entry[1], entry[2], entry[3], entry[4])
	for grove in GROVES:
		_model("BirchScrub", Vector2(grove.x, grove.y), grove.z, grove.x * .13, 4.6)
	_rail_siding()


func _outside(point):
	return maxf(maxf(-point.x, point.x - 160), maxf(-point.y, point.y - 116))


func _raw_height(point):
	var relief = 2.6 + 1.2 * sin(point.x * .073 + point.y * .12)
	# The service yards are flat; the distant edge rises into reclaimed embankments.
	return relief * smoothstep(34.0, 46.0, _outside(point))


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
	for x in range(-46, 206, 2):
		for z in range(-46, 162, 2):
			if x >= -2 and x < 162 and z >= -2 and z < 118:
				continue
			var corners = [
				Vector2(x, z), Vector2(x + 2, z), Vector2(x, z + 2), Vector2(x + 2, z + 2)
			]
			for index in [0, 1, 2, 1, 3, 2]:
				var point = corners[index]
				surface.set_normal(_normal_at(point))
				surface.add_vertex(Vector3(point.x, height_at(point), point.y))
	ground = MeshInstance3D.new()
	ground.name = "ReclaimedServiceGround"
	ground.mesh = surface.commit()
	add_child(ground)


func _model(asset, point, model_scale, turn, radius):
	var model = (
		load("res://assets/models/environment/industrial-surroundings/%s.glb" % asset).instantiate()
	)
	load("res://source/match/maps/IndustrialMaterials.gd").weather(model)
	model.name = asset
	model.position = Vector3(point.x, height_at(point), point.y)
	model.scale = Vector3.ONE * model_scale
	model.rotation.y = turn
	model.set_meta("exterior_radius", radius * model_scale)
	add_child(model)
	models.append(model)


func _box(label, point, dimensions, material):
	var mesh = MeshInstance3D.new()
	mesh.name = label
	var shape = BoxMesh.new()
	shape.size = dimensions
	shape.material = material
	mesh.mesh = shape
	mesh.position = point
	add_child(mesh)


func _rail_siding():
	var ballast = StandardMaterial3D.new()
	ballast.albedo_color = Color("555953")
	ballast.roughness = 1.0
	var timber = StandardMaterial3D.new()
	timber.albedo_color = Color("51443a")
	var rail = StandardMaterial3D.new()
	rail.albedo_color = Color("797a72")
	rail.metallic = .7
	rail.roughness = .6
	_box("Ballast bed", Vector3(80, .06, -15), Vector3(184, .12, 5), ballast)
	for x in range(-10, 172, 2):
		_box("Sleeper", Vector3(x, .17, -15), Vector3(.25, .18, 3.6), timber)
	for z in [-16.4, -13.6]:
		_box("Rail", Vector3(80, .32, z), Vector3(184, .16, .13), rail)
