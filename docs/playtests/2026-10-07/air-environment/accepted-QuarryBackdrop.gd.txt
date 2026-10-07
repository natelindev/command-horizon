extends Node3D

const LANDMARKS = [
	["QuarryBenchA", Vector2(-19, 12), 3.0, .4],
	["QuarryBenchB", Vector2(-22, 72), 3.0, 1.5],
	["QuarryBenchC", Vector2(24, -22), 3.2, .1],
	["QuarryBenchA", Vector2(71, -24), 3.5, 2.0],
	["QuarryBenchB", Vector2(126, -23), 3.0, .6],
	["QuarryBenchC", Vector2(165, 16), 3.0, 2.5],
	["QuarryBenchB", Vector2(170, 83), 3.6, .7],
	["QuarryBenchA", Vector2(126, 129), 3.5, 1.2],
	["QuarryBenchC", Vector2(51, 133), 4.0, .8],
	["QuarryBenchB", Vector2(-12, 126), 3.2, 2.4],
	["QuarryCrusher", Vector2(87, 117), 1.0, .0],
	["QuarryConveyor", Vector2(158, 52), 1.0, PI / 2],
	["QuarryCrusher", Vector2(-13, 43), .85, PI / 2]
]
var ground


func _ready():
	name = "QuarryExterior"
	_make_ground()
	for entry in LANDMARKS:
		var model = load("res://assets/models/environment/quarry/%s.glb" % entry[0]).instantiate()
		load("res://source/match/maps/QuarryMaterials.gd").weather_stone(model)
		# The narrow foundation joins playable cuts; standalone exterior hills omit it.
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			if String(mesh.name).begins_with("Continuous"):
				mesh.hide()
		model.position = Vector3(entry[1].x, height_at(entry[1]), entry[1].y)
		model.scale = Vector3.ONE * entry[2]
		model.rotation.y = entry[3]
		add_child(model)


func _raw_height(point):
	var outside = maxf(maxf(-point.x, point.x - 144), maxf(-point.y, point.y - 104))
	return (
		smoothstep(4, 20, outside)
		* (1.8 + .6 * sin(point.x * .08 + point.y * .03) + .4 * cos(point.y * .11))
	)


func height_at(point):
	var height = _raw_height(point)
	for entry in LANDMARKS:
		var radius = entry[2] * (6.5 if entry[0].begins_with("QuarryBench") else 12.0)
		var blend = 1.0 - smoothstep(radius, radius + 3.0, point.distance_to(entry[1]))
		height = lerpf(height, _raw_height(entry[1]), blend)
	var outside = maxf(maxf(-point.x, point.x - 144), maxf(-point.y, point.y - 104))
	return height * smoothstep(2, 4, outside)


func _make_ground():
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material = ShaderMaterial.new()
	material.shader = load("res://source/shaders/3d/quarry_ground.gdshader")
	material.set_shader_parameter("exterior", true)
	surface.set_material(material)
	for x in range(-52, 196, 2):
		for z in range(-52, 156, 2):
			if x >= -2 and x < 146 and z >= -2 and z < 106:
				continue
			var corners = [
				Vector2(x, z), Vector2(x + 2, z), Vector2(x, z + 2), Vector2(x + 2, z + 2)
			]
			for index in [0, 1, 2, 1, 3, 2]:
				var point = corners[index]
				surface.set_uv(point / Vector2(144, 104))
				surface.set_normal(_normal_at(point))
				surface.add_vertex(Vector3(point.x, height_at(point), point.y))
	ground = MeshInstance3D.new()
	ground.name = "QuarrySurroundings"
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
