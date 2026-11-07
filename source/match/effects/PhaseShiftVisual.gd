extends Node3D

## A short world-space remnant, never attached to the relocated gameplay body.
const SHADER = preload("res://source/shaders/3d/phase_shift.gdshader")
const DURATION = .8
var age = 0.0
var material: ShaderMaterial
var point = Vector3.ZERO
var player
var _materials = []
var _silhouette: Node3D


func setup(at: Vector3, arriving: bool, side, unit = null):
	point = at
	player = side
	position = point
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("arriving", arriving)
	_materials.append(material)
	var shell = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = .85
	sphere.height = 1.7
	shell.mesh = sphere
	shell.position.y = .8
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	var ring = MeshInstance3D.new()
	var disc = QuadMesh.new()
	disc.size = Vector2(5, 5)
	ring.mesh = disc
	ring.rotation.x = -PI * .5
	ring.position.y = .09
	var ring_material = material.duplicate()
	ring_material.set_shader_parameter("ground_ring", true)
	ring.material_override = ring_material
	_materials.append(ring_material)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	if unit != null:
		var geometry = unit.get_node_or_null("Geometry")
		if geometry != null:
			_silhouette = (
				load("res://source/match/rendering/UnitBatchRenderer.gd")
				. duplicate_geometry(geometry, 0)
			)
			_silhouette.top_level = false
			_silhouette.transform = Transform3D(geometry.global_basis, Vector3.ZERO)
			var shadow = ShaderMaterial.new()
			shadow.shader = SHADER
			shadow.set_shader_parameter("silhouette", true)
			_materials.append(shadow)
			for part in _silhouette.find_children("*", "MeshInstance3D", true, false):
				part.material_override = shadow
				part.material_overlay = null
				part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_silhouette)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func advance(delta: float) -> bool:
	age += delta
	for surface in _materials:
		surface.set_shader_parameter("progress", clampf(age / DURATION, 0, 1))
	if _silhouette != null:
		_silhouette.scale = Vector3.ONE * maxf(.01, 1.0 - pow(age / DURATION, 2.0))
	return age >= DURATION
