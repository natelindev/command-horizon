extends Node3D

# Scenic footprint is outside the 128 x 104 m playable district.
const LANDMARKS = [
	["RailServiceBay", Vector2(34, -29), 1.0, 0.0, 12.0],
	["RailWagon", Vector2(64, -15), 1.0, 0.0, 11.0],
	["RailWagon", Vector2(85, -15), 1.0, 0.0, 11.0],
	["DistrictUtilities", Vector2(35, 120), 1.0, 0.0, 10.0],
	["Substation", Vector2(91, 122), 1.0, 0.0, 10.0],
	["RailServiceBay", Vector2(148, 65), 0.9, PI / 2, 12.0]
]
const GROVES = [
	Vector3(-8, 8, 1),
	Vector3(-12, 15, .8),
	Vector3(-9, 35, 1.1),
	Vector3(-10, 70, 1),
	Vector3(-8, 94, .9),
	Vector3(135, 10, .9),
	Vector3(141, 30, 1.1),
	Vector3(136, 39, .8),
	Vector3(139, 93, 1),
	Vector3(9, 114, 1),
	Vector3(17, 120, .8),
	Vector3(57, 116, 1),
	Vector3(66, 121, 1.1),
	Vector3(116, 116, .9),
	Vector3(123, 123, 1),
	Vector3(111, -7, .8),
	Vector3(119, -10, 1.0)
]
var ground
var models = []


func _ready():
	name = "IndustrialExterior"
	_ground()
	for entry in LANDMARKS:
		_model(entry[0], entry[1], entry[2], entry[3], entry[4])
	for grove in GROVES:
		_model("BirchScrub", Vector2(grove.x, grove.y), grove.z, grove.x * .13, 4.6)
	_rail_siding()


func _outside(point):
	return maxf(maxf(-point.x, point.x - 128), maxf(-point.y, point.y - 104))


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
	var material = ShaderMaterial.new()
	material.shader = load("res://source/shaders/3d/district_ground.gdshader")
	load("res://source/match/SurfaceTextures.gd").configure_ground(material)
	material.set_shader_parameter("district_wear", true)
	material.set_shader_parameter("pavement_extent", Vector2(34, 40))
	material.set_shader_parameter("road_count", 3)
	var roads = PackedVector4Array(
		[Vector4(-46, 22, 174, 22), Vector4(-46, 52, 174, 52), Vector4(-46, 82, 174, 82)]
	)
	roads.resize(8)
	material.set_shader_parameter("roads", roads)
	surface.set_material(material)
	for x in range(-46, 174, 2):
		for z in range(-46, 150, 2):
			if x >= 0 and x < 128 and z >= 0 and z < 104:
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
	_box("Ballast bed", Vector3(64, .06, -15), Vector3(160, .12, 5), ballast)
	for x in range(-14, 144, 2):
		_box("Sleeper", Vector3(x, .17, -15), Vector3(.25, .18, 3.6), timber)
	for z in [-16.4, -13.6]:
		_box("Rail", Vector3(64, .32, z), Vector3(160, .16, .13), rail)
