extends Node3D

const Cache = preload("res://source/utils/RuntimeCache.gd")

@onready var _particles = find_child("GPUParticles3D")


func _ready():
	_particles.process_material = _motion_material()
	await get_tree().physics_frame  # wait one frame for transform to propagate
	_particles.finished.connect(queue_free)
	_particles.emitting = true


static func _motion_material():
	# Match harvesting's runtime material lifetime; serialized process materials
	# leave a generated shader behind in Godot 4.7.2 when the scene is released.
	var materials = Cache.bucket("unit_particle_materials")
	if materials.has("resource_decay"):
		return materials.resource_decay
	var material = ParticleProcessMaterial.new()
	material.emission_shape_offset = Vector3(0, .1, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = .5
	material.gravity = Vector3(0, .1, 0)
	material.linear_accel_min = .01
	material.linear_accel_max = .05
	material.scale_min = .05
	material.scale_max = .15
	var curve = Curve.new()
	curve.max_value = 3.0
	curve.add_point(Vector2(0, .396055))
	curve.add_point(Vector2(.0147602, 3.0))
	var scale_curve = CurveTexture.new()
	scale_curve.curve = curve
	material.scale_over_velocity_curve = scale_curve
	material.color = Color(.960784, .745098, .654902, 1)
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var ramp = GradientTexture1D.new()
	ramp.gradient = gradient
	material.color_ramp = ramp
	materials.resource_decay = material
	return material
