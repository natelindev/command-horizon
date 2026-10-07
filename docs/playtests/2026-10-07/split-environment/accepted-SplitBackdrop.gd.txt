extends Node3D

# Scenic mountain terrain only. All solid silhouettes stay outside 108 x 88 m.
const LANDMARKS = [
	["AlpineMassifA", Vector2(9, -24), 1.10, .25, 13.0],
	["AlpineMassifB", Vector2(56, -25), 1.20, 1.2, 13.0],
	["AlpineMassifA", Vector2(110, -26), 1.30, 2.0, 13.0],
	["AlpineMassifB", Vector2(131, 4), 1.15, .5, 13.0],
	["AlpineMassifA", Vector2(135, 60), 1.25, 2.4, 13.0],
	["AlpineMassifB", Vector2(120, 112), 1.10, 1.7, 13.0],
	["AlpineMassifA", Vector2(66, 115), 1.35, 2.8, 13.0],
	["AlpineMassifB", Vector2(15, 111), 1.15, .1, 13.0],
	["AlpineMassifA", Vector2(-23, 91), 1.20, 1.0, 13.0],
	["AlpineMassifB", Vector2(-24, 49), 1.25, 2.5, 13.0],
	["MountainWeatherStation", Vector2(54, -11), 1.0, .05, 7.4],
	["AbandonedCableStation", Vector2(-13, 24), 1.0, .15, 7.6],
	["AbandonedCableStation", Vector2(122, 78), .85, 2.2, 7.6]
]
const GROVES = [
	Vector3(24, -9, .85),
	Vector3(34, -13, 1.0),
	Vector3(90, -9, .75),
	Vector3(-9, 6, .8),
	Vector3(-11, 42, .95),
	Vector3(-8, 64, .85),
	Vector3(-10, 80, 1.0),
	Vector3(6, 98, .85),
	Vector3(34, 98, 1.0),
	Vector3(56, 100, .85),
	Vector3(96, 98, .9),
	Vector3(116, 18, .9),
	Vector3(119, 32, 1.0),
	Vector3(118, 58, .8)
]
var ground
var models = []


func _ready():
	name = "SplitExterior"
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
	var outside = maxf(maxf(-point.x, point.x - 108), maxf(-point.y, point.y - 88))
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
	var outside = maxf(maxf(-point.x, point.x - 108), maxf(-point.y, point.y - 88))
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
	material.shader = load("res://source/shaders/3d/split_signal.gdshader")
	material.set_shader_parameter("exterior", true)
	surface.set_material(material)
	for x in range(-46, 154, 2):
		for z in range(-46, 134, 2):
			if x >= -2 and x < 110 and z >= -2 and z < 90:
				continue
			var corners = [
				Vector2(x, z), Vector2(x + 2, z), Vector2(x, z + 2), Vector2(x + 2, z + 2)
			]
			for index in [0, 1, 2, 1, 3, 2]:
				var point = corners[index]
				surface.set_uv(point / Vector2(108, 88))
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
