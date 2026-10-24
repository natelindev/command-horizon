extends Node3D

const Cache = preload("res://source/utils/RuntimeCache.gd")

@onready var _particles = find_child("GPUParticles3D")


func _ready():
	_particles.process_material = _motion_material()
	await get_tree().physics_frame  # wait one frame for transform to propagate
	_particles.emitting = true


static func _motion_material():
	# Godot 4.7.2's serialized particle material retains a generated shader after
	# destruction. Build the same settings at runtime, shared by all workers.
	var materials = Cache.bucket("unit_particle_materials")
	if materials.has("sparkling"):
		return materials.sparkling
	var material = ParticleProcessMaterial.new()
	material.emission_shape_offset = Vector3(0, .15, 0)
	material.emission_shape_scale = Vector3(1, 1, .5)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = .3
	material.gravity = Vector3(0, 1, 0)
	material.linear_accel_min = .5
	material.linear_accel_max = 2.0
	material.radial_accel_min = 1.8
	material.radial_accel_max = 1.8
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var ramp = GradientTexture1D.new()
	ramp.gradient = gradient
	material.color_ramp = ramp
	materials.sparkling = material
	return material
