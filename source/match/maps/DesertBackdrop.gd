extends Node3D

# Public, non-playable surroundings. Every model is outside the map rectangle;
# this terrain never joins navigation, placement, selection or sight groups.
const LANDMARKS = [
	["CanyonMesa1", Vector2(-19, 6), 0.9, 0.3, 11.0],
	["CanyonMesa2", Vector2(-22, 61), 1.3, 1.1, 11.0],
	["CanyonMesa3", Vector2(-15, 97), 1.0, 2.0, 11.0],
	["CanyonMesa2", Vector2(20, -19), 1.1, 2.6, 11.0],
	["CanyonMesa1", Vector2(72, -24), 1.4, 0.6, 11.0],
	["CanyonMesa3", Vector2(121, -18), 0.95, 1.3, 11.0],
	["CanyonMesa2", Vector2(150, 22), 1.2, 0.8, 11.0],
	["CanyonMesa1", Vector2(153, 80), 1.4, 2.5, 11.0],
	["CanyonMesa2", Vector2(102, 119), 1.1, 1.9, 11.0],
	["CanyonMesa3", Vector2(46, 119), 1.5, 0.5, 11.0],
	["CanyonMesa1", Vector2(-2, 123), 1.0, 2.8, 11.0],
	["FrontierExtractionRig", Vector2(-12, 35), 1.0, -0.2, 6.0],
	["AbandonedFreightBay", Vector2(140, 57), 1.0, 0.8, 6.0],
	["AbandonedFreightBay", Vector2(37, -11), 1.0, 0.0, 6.0]
]
const DesertMaterials = preload("res://source/match/maps/DesertMaterials.gd")
var ground
var models = []


func _ready():
	name = "DesertExterior"
	_ground()
	for entry in LANDMARKS:
		var model = _model(entry[0], entry[1], entry[2], entry[3])
		model.set_meta("exterior_radius", entry[2] * entry[4])
		models.append(model)
	# Varied trees follow boundary pockets, outside construction space and unit routes.
	var trees = DesertMaterials.TREES
	var tree_index = 0
	for point in [
		Vector2(-7, 18),
		Vector2(-9, 23),
		Vector2(-8, 47),
		Vector2(-10, 50),
		Vector2(12, -7),
		Vector2(17, -9),
		Vector2(46, -6),
		Vector2(85, -8),
		Vector2(133, 36),
		Vector2(135, 42),
		Vector2(138, 94),
		Vector2(77, 103),
		Vector2(83, 106),
		Vector2(24, 103)
	]:
		var model = _model(trees[tree_index % trees.size()], point, 1.0, point.x * 0.37)
		load("res://source/match/maps/Vegetation.gd").fit_height(model, 7.0)
		tree_index += 1
		model.set_meta("exterior_radius", 5.0)
		models.append(model)


func _raw_height(point):
	var outside = maxf(maxf(-point.x, point.x - 128), maxf(-point.y, point.y - 96))
	var rise = smoothstep(4.0, 16.0, outside)
	var rolling = (
		1.7
		+ 0.55 * sin(point.x * 0.095 + point.y * 0.033)
		+ 0.35 * cos(point.y * 0.13 - point.x * 0.04)
		+ 0.18 * sin(point.x * 0.28 + point.y * 0.18)
	)
	return rise * rolling


func height_at(point):
	var height = _raw_height(point)
	for entry in LANDMARKS:
		var radius = entry[2] * entry[4]
		var distance = point.distance_to(entry[1])
		var blend = 1.0 - smoothstep(radius, radius + 3.0, distance)
		height = lerpf(height, _raw_height(entry[1]), blend)
	var outside = maxf(maxf(-point.x, point.x - 128), maxf(-point.y, point.y - 96))
	return height * smoothstep(2.0, 4.0, outside)


func _ground():
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material = ShaderMaterial.new()
	material.shader = load("res://source/shaders/3d/frontier.gdshader")
	material.set_shader_parameter("exterior", true)
	surface.set_material(material)
	for x in range(-46, 174, 2):
		for z in range(-46, 142, 2):
			if x >= -2 and x < 130 and z >= -2 and z < 98:
				continue
			var corners = [
				Vector2(x, z), Vector2(x + 2, z), Vector2(x, z + 2), Vector2(x + 2, z + 2)
			]
			for index in [0, 1, 2, 1, 3, 2]:
				var point = corners[index]
				surface.set_uv(point / Vector2(128, 96))
				surface.set_normal(_normal_at(point))
				surface.add_vertex(Vector3(point.x, height_at(point), point.y))
	ground = MeshInstance3D.new()
	ground.name = "WindSculptedSurroundings"
	ground.mesh = surface.commit()
	add_child(ground)


func _normal_at(point):
	# Sample the continuous height field so the flat inner edge shares the
	# playable plane's upward normal, including beside landmark foundations.
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


func _model(asset, point, model_scale, turn):
	var model = load("res://assets/models/environment/desert/%s.glb" % asset).instantiate()
	model.name = asset
	DesertMaterials.weather_stone(model)
	model.position = Vector3(point.x, height_at(point), point.y)
	model.scale = Vector3.ONE * model_scale
	model.rotation.y = turn
	add_child(model)
	return model
