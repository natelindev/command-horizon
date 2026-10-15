extends RefCounted


static func create(reach):
	if reach == null or reach <= 0:
		return null
	var ring = MeshInstance3D.new()
	ring.name = "TacticalRangeRing"
	var mesh = TorusMesh.new()
	mesh.inner_radius = maxf(.01, reach - .025)
	mesh.outer_radius = reach + .025
	mesh.rings = 96
	mesh.ring_segments = 8
	ring.mesh = mesh
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(.60, .66, .63, .18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = .065
	return ring
