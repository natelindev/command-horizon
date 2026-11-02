extends Node3D

## One static world-sized heightfield, refreshed only after topology changes.
## Cosmetic only: bridges/overhangs still use authoritative CPU projectile tests.
var _heightfield: GPUParticlesCollisionHeightField3D
var _emitters: Dictionary
var _dirty := true
var _enabled := false


func setup(map, emitters: Dictionary):
	_emitters = emitters
	_heightfield = GPUParticlesCollisionHeightField3D.new()
	_heightfield.name = "TerrainHeightfield"
	_heightfield.size = Vector3(
		map.size.x + 4.0, map.max_height() - map.min_height() + 16.0, map.size.y + 4.0
	)
	_heightfield.position = Vector3(
		map.size.x * .5, (map.max_height() + map.min_height()) * .5 + 2.0, map.size.y * .5
	)
	_heightfield.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_1024
	_heightfield.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	add_child(_heightfield)
	Globals.options.changed.connect(apply_options)
	MatchSignals.schedule_navigation_rebake.connect(_topology_changed)
	apply_options()


func apply_options():
	_enabled = Globals.options.environment_quality == 1 and Globals.options.graphics_ground_detail
	_heightfield.visible = _enabled
	for kind in ["debris", "clod"]:
		var particles: GPUParticles3D = _emitters[kind]
		var material: ParticleProcessMaterial = particles.process_material
		material.collision_mode = (
			ParticleProcessMaterial.COLLISION_RIGID
			if _enabled
			else ParticleProcessMaterial.COLLISION_DISABLED
		)
		material.collision_bounce = .25
		material.collision_friction = .65
	var sparks: GPUParticles3D = _emitters.spark
	sparks.process_material.set_shader_parameter("terrain_collision", _enabled)
	_dirty = true


func _topology_changed(_domain: int):
	_dirty = true


func _process(_delta: float):
	if _dirty and _enabled:
		_dirty = false
		RenderingServer.particles_collision_height_field_update(_heightfield.get_rid())
