extends Node3D

# Scenic mountain terrain only. All solid silhouettes stay outside 128 x 104 m.
const LANDMARKS = [
	["AlpineMassifA", Vector2(9, -24), 1.10, 0.25, 13.0],
	["AlpineMassifB", Vector2(56, -21), 1.20, 1.2, 13.0],
	["AlpineMassifA", Vector2(110, -26), 1.30, 2.0, 13.0],
	["AlpineMassifB", Vector2(150, 4), 1.15, 0.5, 13.0],
	["AlpineMassifA", Vector2(155, 60), 1.25, 2.4, 13.0],
	["AlpineMassifB", Vector2(140, 126), 1.10, 1.7, 13.0],
	["AlpineMassifA", Vector2(86, 131), 1.35, 2.8, 13.0],
	["AlpineMassifB", Vector2(25, 127), 1.15, 0.1, 13.0],
	["AlpineMassifA", Vector2(-23, 111), 1.20, 1.0, 13.0],
	["AlpineMassifB", Vector2(-24, 57), 1.25, 2.5, 13.0],
	["MountainWeatherStation", Vector2(89, -12), 1.0, 0.05, 7.4],
	["AbandonedCableStation", Vector2(-13, 24), 1.0, 0.15, 7.6],
	["AbandonedCableStation", Vector2(142, 90), 0.85, 2.2, 7.6]
]
const GROVES = [
	Vector3(29, -9, 0.85),
	Vector3(38, -13, 1.0),
	Vector3(119, -9, 0.75),
	Vector3(-9, 6, 0.8),
	Vector3(-11, 42, 0.95),
	Vector3(-8, 76, 0.85),
	Vector3(-10, 88, 1.0),
	Vector3(6, 114, 0.85),
	Vector3(44, 114, 1.0),
	Vector3(56, 116, 0.85),
	Vector3(106, 114, 0.9),
	Vector3(123, 114, 0.8),
	Vector3(137, 18, 0.9),
	Vector3(139, 32, 1.0),
	Vector3(136, 73, 0.8)
]
var ground
var models = []


func _ready():
	name = "AlpineExterior"
	_ground()
	for entry in LANDMARKS:
		var model = _model(entry[0], entry[1], entry[2], entry[3])
		model.set_meta("exterior_radius", entry[2] * entry[4])
		models.append(model)
	for grove in GROVES:
		var model = _model("SnowPineGrove", Vector2(grove.x, grove.y), grove.z, grove.x * 0.13)
		model.set_meta("exterior_radius", grove.z * 5.4)
		models.append(model)


func _raw_height(point):
	var outside = maxf(maxf(-point.x, point.x - 128), maxf(-point.y, point.y - 104))
	var rolling = 1.8 + 0.7 * sin(point.x * 0.10 + point.y * 0.04)
	rolling += 0.42 * cos(point.y * 0.14 - point.x * 0.055)
	rolling += 0.21 * sin(point.x * 0.26 + point.y * 0.17)
	return smoothstep(4.0, 18.0, outside) * rolling


func height_at(point):
	var height = _raw_height(point)
	for entry in LANDMARKS:
		var radius = entry[2] * entry[4]
		var blend = 1.0 - smoothstep(radius, radius + 3.0, point.distance_to(entry[1]))
		height = lerpf(height, _raw_height(entry[1]), blend)
	for grove in GROVES:
		var center = Vector2(grove.x, grove.y)
		var blend = 1.0 - smoothstep(4.0 * grove.z, 6.0 * grove.z, point.distance_to(center))
		height = lerpf(height, _raw_height(center), blend)
	var outside = maxf(maxf(-point.x, point.x - 128), maxf(-point.y, point.y - 104))
	return height * smoothstep(2.0, 4.0, outside)


func _normal_at(point):
	var dx = Vector2(0.1, 0)
	var dz = Vector2(0, 0.1)
	return (
		Vector3(
			height_at(point - dx) - height_at(point + dx),
			0.2,
			height_at(point - dz) - height_at(point + dz)
		)
		. normalized()
	)


func _ground():
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material = ShaderMaterial.new()
	material.shader = load("res://source/shaders/3d/alpine.gdshader")
	material.set_shader_parameter("exterior", true)
	surface.set_material(material)
	for x in range(-46, 174, 2):
		for z in range(-46, 150, 2):
			if x >= -2 and x < 130 and z >= -2 and z < 106:
				continue
			var corners = [
				Vector2(x, z), Vector2(x + 2, z), Vector2(x, z + 2), Vector2(x + 2, z + 2)
			]
			for index in [0, 1, 2, 1, 3, 2]:
				var point = corners[index]
				surface.set_uv(point / Vector2(128, 104))
				surface.set_normal(_normal_at(point))
				surface.add_vertex(Vector3(point.x, height_at(point), point.y))
	ground = MeshInstance3D.new()
	ground.name = "MountainSnowfield"
	ground.mesh = surface.commit()
	add_child(ground)


func _model(asset, point, model_scale, turn):
	var model = load("res://assets/models/environment/alpine/%s.glb" % asset).instantiate()
	model.name = asset
	load("res://source/match/maps/AlpineMaterials.gd").weather(model)
	model.position = Vector3(point.x, height_at(point), point.y)
	model.scale = Vector3.ONE * model_scale
	model.rotation.y = turn
	add_child(model)
	return model
