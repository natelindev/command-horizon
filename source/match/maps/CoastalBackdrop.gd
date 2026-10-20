extends Node3D

# Public scenery, separate from the authored 128 x 104 m battlefield.
const LANDMARKS = [
	["CoastalHeadland", Vector2(-18, 4), 1.3, 0.4, 10.5],
	["CoastalHeadland", Vector2(147, 3), 1.25, 2.6, 10.5],
	["HarborBreakwater", Vector2(-12, -6), 1.0, PI / 2, 8.5],
	["HarborBreakwater", Vector2(0, -12), 1.0, 0.0, 8.5],
	["HarborBreakwater", Vector2(16, -12), 1.0, 0.0, 8.5],
	["HarborBreakwater", Vector2(32, -12), 1.0, 0.0, 8.5],
	["HarborBreakwater", Vector2(47, -12), 1.0, 0.0, 8.5],
	["HarborBreakwater", Vector2(81, -12), 1.0, 0.0, 8.5],
	["HarborBreakwater", Vector2(96, -12), 1.0, 0.0, 8.5],
	["HarborBreakwater", Vector2(112, -12), 1.0, 0.0, 8.5],
	["HarborBreakwater", Vector2(128, -12), 1.0, 0.0, 8.5],
	["HarborBreakwater", Vector2(140, -6), 1.0, PI / 2, 8.5],
	["PortPumpHouse", Vector2(-12, 34), 1.0, 0.2, 7.4],
	["PortUtilities", Vector2(144, 68), 1.0, -0.25, 8.8],
	["PortFreightYard", Vector2(32, 121), 1.0, 0.1, 9.0],
	["PortFreightYard", Vector2(95, 123), 1.1, -0.15, 9.0],
	["PortUtilities", Vector2(64, 130), 0.9, 0.1, 8.8],
	["CoastalHeadland", Vector2(-19, 94), 1.1, 1.9, 10.5],
	["CoastalHeadland", Vector2(146, 115), 1.1, 0.5, 10.5]
]
const GROVES = [
	Vector3(-7, 54, 1),
	Vector3(-12, 68, 1.15),
	Vector3(-8, 80, 0.8),
	Vector3(136, 41, 1.0),
	Vector3(141, 50, 0.9),
	Vector3(136, 91, 1.1),
	Vector3(8, 115, 1.15),
	Vector3(14, 119, 0.9),
	Vector3(119, 118, 1.1)
]
var ground
var models = []


func _ready():
	name = "CoastalExterior"
	_ground()
	for entry in LANDMARKS:
		var base = (
			-0.65
			if entry[0] in ["HarborBreakwater", "CoastalHeadland"] and entry[1].y < 15
			else height_at(entry[1])
		)
		var model = _model(entry[0], entry[1], entry[2], entry[3], base)
		model.set_meta("exterior_radius", entry[2] * entry[4])
		models.append(model)
	for grove in GROVES:
		var point = Vector2(grove.x, grove.y)
		var model = _model("CoastalPineStand", point, grove.z, grove.x * .13, height_at(point))
		model.set_meta("exterior_radius", grove.z * 3.6)
		models.append(model)


func _outside(point):
	return maxf(maxf(-point.x, point.x - 128), maxf(-point.y, point.y - 104))


func _raw_height(point):
	var outside = _outside(point)
	var coast = 15.0 + smoothstep(2.0, 14.0, outside) * (3.0 * sin(point.x * 0.13) - 2.5)
	if point.y < coast:
		return -1.5 * smoothstep(0.0, 4.0, coast - point.y)
	var rolling = 3.0 + 0.9 * sin(point.x * .10 + point.y * .055)
	rolling += 0.65 * cos(point.y * .14 - point.x * .045)
	return rolling * smoothstep(3.0, 18.0, outside) * smoothstep(coast, coast + 10, point.y)


func height_at(point):
	var height = _raw_height(point)
	for entry in LANDMARKS:
		if entry[1].y < 15:
			continue
		var radius = entry[2] * entry[4]
		var blend = 1.0 - smoothstep(radius, radius + 6, point.distance_to(entry[1]))
		height = lerpf(height, _raw_height(entry[1]), blend)
	return height * smoothstep(0.0, 3.0, _outside(point)) if point.y >= 15 else height


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
	material.shader = load("res://source/shaders/3d/coastal_ground.gdshader")
	load("res://source/match/TerrainTextures.gd").apply(material)
	material.set_shader_parameter("exterior", true)
	material.set_shader_parameter("road_count", 0)
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
				surface.set_uv(point / Vector2(128, 104))
				surface.set_normal(_normal_at(point))
				surface.add_vertex(Vector3(point.x, height_at(point), point.y))
	ground = MeshInstance3D.new()
	ground.name = "CoastalMeadowAndShore"
	ground.mesh = surface.commit()
	add_child(ground)


func _model(asset, point, model_scale, turn, base):
	var model = load("res://assets/models/environment/coastal/%s.glb" % asset).instantiate()
	model.name = asset
	load("res://source/match/maps/CoastalMaterials.gd").weather(model)
	model.position = Vector3(point.x, base, point.y)
	model.scale = Vector3.ONE * model_scale
	model.rotation.y = turn
	add_child(model)
	return model
