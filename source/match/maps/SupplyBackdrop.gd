extends Node3D

const LANDMARKS = [
	["CanyonMesa1", Vector2(-15, 20), .8, .4],
	["CanyonMesa2", Vector2(-18, 76), 1.0, 1.4],
	["CanyonMesa3", Vector2(-14, 124), .8, 2.1],
	["CanyonMesa2", Vector2(28, -17), .95, .5],
	["CanyonMesa1", Vector2(96, -20), 1.2, 1.8],
	["CanyonMesa3", Vector2(171, -15), .85, 2.5],
	["CanyonMesa2", Vector2(207, 18), .8, .3],
	["CanyonMesa1", Vector2(210, 82), 1.0, 2.3],
	["CanyonMesa3", Vector2(173, 146), 1.0, 1.1],
	["CanyonMesa1", Vector2(92, 148), 1.15, .8],
	["CanyonMesa2", Vector2(16, 146), .8, 2.8],
	["AbandonedFreightBay", Vector2(-10, 103), 1.2, .2],
	["FrontierExtractionRig", Vector2(202, 43), 1.0, -.3]
]
var ground


func _ready():
	name = "SupplyExterior"
	_make_ground()
	for entry in LANDMARKS:
		var model = load("res://assets/models/environment/desert/%s.glb" % entry[0]).instantiate()
		load("res://source/match/maps/DesertMaterials.gd").weather_stone(model)
		model.position = Vector3(entry[1].x, height_at(entry[1]), entry[1].y)
		model.scale = Vector3.ONE * entry[2]
		model.rotation.y = entry[3]
		add_child(model)


func _raw_height(point):
	var outside = maxf(maxf(-point.x, point.x - 192), maxf(-point.y, point.y - 128))
	return (
		smoothstep(4, 20, outside)
		* (1.8 + .6 * sin(point.x * .08 + point.y * .03) + .4 * cos(point.y * .11))
	)


func height_at(point):
	var height = _raw_height(point)
	for entry in LANDMARKS:
		var radius = entry[2] * (11.0 if entry[0].begins_with("Canyon") else 6.0)
		var blend = 1.0 - smoothstep(radius, radius + 3.0, point.distance_to(entry[1]))
		height = lerpf(height, _raw_height(entry[1]), blend)
	var outside = maxf(maxf(-point.x, point.x - 192), maxf(-point.y, point.y - 128))
	return height * smoothstep(2, 4, outside)


func _make_ground():
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material = ShaderMaterial.new()
	material.shader = load("res://source/shaders/3d/supply_ground.gdshader")
	load("res://source/match/TerrainTextures.gd").apply(material)
	material.set_shader_parameter("exterior", true)
	surface.set_material(material)
	for x in range(-42, 234, 2):
		for z in range(-42, 170, 2):
			if x >= -2 and x < 194 and z >= -2 and z < 130:
				continue
			var corners = [
				Vector2(x, z), Vector2(x + 2, z), Vector2(x, z + 2), Vector2(x + 2, z + 2)
			]
			for index in [0, 1, 2, 1, 3, 2]:
				var point = corners[index]
				surface.set_uv(point / Vector2(192, 128))
				surface.set_normal(_normal_at(point))
				surface.add_vertex(Vector3(point.x, height_at(point), point.y))
	ground = MeshInstance3D.new()
	ground.name = "DryValleySurroundings"
	ground.mesh = surface.commit()
	add_child(ground)


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
