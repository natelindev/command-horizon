extends Node3D

var _pillar: MeshInstance3D
var _ring: MeshInstance3D
var _crystal: Node3D
var _clock := 0.0


func _ready():
	if DisplayServer.get_name() == "headless":
		return
	_build_visuals()


func _build_visuals():
	_pillar = MeshInstance3D.new()
	_pillar.name = "LightPillar"
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.12
	cylinder.bottom_radius = 0.38
	cylinder.height = 14.0
	cylinder.radial_segments = 16
	cylinder.rings = 1
	_pillar.mesh = cylinder
	_pillar.position.y = 7.0
	_pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var pillar_mat = StandardMaterial3D.new()
	pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar_mat.albedo_color = Color(1.0, 0.78, 0.18, 0.28)
	pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pillar_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pillar.material_override = pillar_mat
	add_child(_pillar)

	_ring = MeshInstance3D.new()
	_ring.name = "GroundRing"
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.05
	torus.rings = 32
	torus.ring_segments = 8
	_ring.mesh = torus
	_ring.position.y = 0.05
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.82, 0.25, 0.45)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = ring_mat
	add_child(_ring)

	_crystal = Node3D.new()
	_crystal.name = "HoverMarker"
	_crystal.position.y = 2.4
	add_child(_crystal)

	var crystal_mat = StandardMaterial3D.new()
	crystal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crystal_mat.albedo_color = Color("ffe082")
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color("ffca62")
	crystal_mat.emission_energy_multiplier = 1.3

	var top_prism = MeshInstance3D.new()
	var prism_mesh = PrismMesh.new()
	prism_mesh.size = Vector3(0.28, 0.38, 0.28)
	top_prism.mesh = prism_mesh
	top_prism.material_override = crystal_mat
	top_prism.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crystal.add_child(top_prism)

	var bottom_prism = MeshInstance3D.new()
	bottom_prism.mesh = prism_mesh
	bottom_prism.rotation.x = PI
	bottom_prism.material_override = crystal_mat
	bottom_prism.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crystal.add_child(bottom_prism)


func _process(delta):
	if DisplayServer.get_name() == "headless":
		return
	_clock += delta
	if is_instance_valid(_ring):
		var ring_pulse = 1.0 + 0.12 * sin(_clock * 2.8)
		_ring.scale = Vector3(ring_pulse, 1.0, ring_pulse)
	if is_instance_valid(_crystal):
		_crystal.position.y = 2.4 + 0.12 * sin(_clock * 2.2)
		_crystal.rotation.y += delta * 1.6
	if is_instance_valid(_pillar):
		var pillar_mat = _pillar.material_override as StandardMaterial3D
		if pillar_mat != null:
			pillar_mat.albedo_color.a = 0.28 + 0.08 * sin(_clock * 2.5)
