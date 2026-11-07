extends Node3D

const SHADER = preload("res://source/shaders/3d/ability_aura.gdshader")
const FOIL_SHADER = preload("res://source/shaders/3d/chaff_foil.gdshader")
var kind = ""
var material: ShaderMaterial
var _foil: ShaderMaterial
var _beacons = []
var _map


func setup(style: String, radius: float, unit, map):
	kind = style
	_map = map
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("mode", 0 if kind == "flux" else (1 if kind == "chaff" else 2))
	if kind == "overhaul":
		for index in 8:
			var direction = Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 8.0)
			var beacon = _mesh(CylinderMesh.new(), direction * radius, Vector3(.12, .45, .12))
			_beacons.append(beacon)
		return
	var height = 1.5
	var center = Vector3.UP * .7
	if kind == "flux" and unit != null:
		var bounds = load("res://source/match/FactionCatalog.gd")._bounds(
			unit.get_node("Geometry"), Transform3D.IDENTITY
		)
		height = maxf(1.0, bounds.size.y)
		center = bounds.get_center()
	_mesh(SphereMesh.new(), center, Vector3(radius * 2.15, height * 1.15, radius * 2.15))
	if kind == "chaff":
		_add_foil(radius)


func _mesh(shape, at, extent):
	var node = MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.position = at
	node.scale = extent
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _add_foil(radius):
	var foil = MultiMeshInstance3D.new()
	var batch = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	var quad = QuadMesh.new()
	quad.size = Vector2(.09, .16)
	_foil = ShaderMaterial.new()
	_foil.shader = FOIL_SHADER
	quad.material = _foil
	batch.mesh = quad
	batch.instance_count = 32
	for index in 32:
		var angle = index * 2.39996
		var reach = radius * sqrt(float(index + 1) / 32.0)
		var point = Vector3(cos(angle) * reach, .2 + fposmod(index * .37, 1.8), sin(angle) * reach)
		batch.set_instance_transform(
			index, Transform3D(Basis.from_euler(Vector3(angle, angle * .7, 0)), point)
		)
		batch.set_instance_custom_data(index, Color(float(index) / 32.0, 0, 0, 0))
	foil.multimesh = batch
	foil.custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 5, 6))
	foil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foil)


func advance(clock: float, steady: bool):
	material.set_shader_parameter("phase", clock)
	material.set_shader_parameter("steady", steady)
	if _foil != null:
		_foil.set_shader_parameter("phase", clock)
		_foil.set_shader_parameter("steady", steady)
	for beacon in _beacons:
		var point = beacon.global_position
		point.y = _map.height_at(Vector2(point.x, point.z)) + .45
		beacon.global_position = point


func emit_haze(effects):
	if kind != "overhaul":
		return
	for beacon in _beacons:
		if (
			effects._camera_sees(beacon.global_position)
			and effects.get_parent().combat_audio.point_observed(beacon.global_position)
		):
			effects.construction_puff(
				"smoke",
				beacon.global_position,
				Vector3(.05, .25, .02),
				Color(.38, .36, .3, .12),
				.6
			)


func update_beacon_visibility(effects, owner):
	for beacon in _beacons:
		beacon.visible = (
			effects._camera_sees(beacon.global_position)
			and effects.get_parent().combat_audio.point_observed(beacon.global_position, owner)
		)
