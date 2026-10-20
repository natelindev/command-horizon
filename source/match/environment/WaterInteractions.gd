extends Node

const GPU = preload("res://source/match/environment/WaterRippleGPU.gd")
const SPAN = 64.0
const CELL = SPAN / GPU.RESOLUTION
const STEP = 1.0 / 30.0
const MAX_STEPS = 2
const MAX_UNITS = 64
var gpu
var origin = Vector2.ZERO
var steps_dispatched = 0
var _game
var _camera
var _field
var _materials = []
var _last_time = -1.0
var _accumulator = 0.0
var _sample_time = 0.0
var _last_positions = {}
var _pending = PackedFloat32Array()
var _reset = true
var _splashes: GPUParticles3D


func setup(game, camera, materials):
	_game = game
	_camera = camera
	_materials = materials
	_field = game.map.water_flow if "water_flow" in game.map else null


func apply_options():
	var options = Globals.options
	var enabled = (
		_field != null
		and not _field.waters.is_empty()
		and options.graphics_liquids
		and options.environment_quality == 1
		and DisplayServer.get_name() != "headless"
		and RenderingServer.get_rendering_device() != null
	)
	if enabled and gpu == null:
		gpu = GPU.new()
		gpu.initialize(_field.image)
		_create_splashes()
		_reset = true
	elif not enabled and gpu != null:
		_release()
	for material in _materials:
		material.set_shader_parameter("interactive_water", enabled)
		material.set_shader_parameter("ripple_state", gpu.texture if gpu != null else null)
	_last_time = _game.simulation_time
	_accumulator = 0.0
	_pending.clear()
	_last_positions.clear()


func update(elapsed: float):
	if gpu == null:
		return
	var delta = elapsed - _last_time
	_last_time = elapsed
	if delta < 0.0 or delta > .5:
		_reset = true
		_pending.clear()
		_last_positions.clear()
		_accumulator = 0.0
	if delta <= 0.0 or _game.restoring:
		return
	# No catch-up spiral after a stall or changing match speed.
	_accumulator = minf(_accumulator + delta, STEP * MAX_STEPS)
	_sample_time += delta
	var center = (
		_camera.global_position
		- _camera.global_basis.z * (_camera.global_position.y / maxf(.1, _camera.global_basis.z.y))
	)
	var next_origin = (
		((Vector2(center.x, center.z) - Vector2.ONE * SPAN * .5) / CELL).floor() * CELL
	)
	var shift = (next_origin - origin) / CELL
	if shift.abs().x >= GPU.RESOLUTION or shift.abs().y >= GPU.RESOLUTION:
		_reset = true
	if _accumulator < STEP:
		return
	origin = next_origin
	if _sample_time >= .1:
		_sample_units()
		_sample_time = 0.0
	for material in _materials:
		material.set_shader_parameter("ripple_region", Vector4(origin.x, origin.y, SPAN, CELL))
	var steps = 0
	while _accumulator >= STEP and steps < MAX_STEPS:
		var parameters = PackedFloat32Array(
			[
				origin.x,
				origin.y,
				SPAN,
				STEP,
				_field.size.x,
				_field.size.y,
				_pending.size() / 4,
				float(_reset),
				shift.x,
				shift.y,
				0.0,
				0.0
			]
		)
		gpu.step(parameters, _pending)
		_pending = PackedFloat32Array()
		_reset = false
		shift = Vector2.ZERO
		_accumulator -= STEP
		steps += 1
		steps_dispatched += 1


func impact(point: Vector3, strength: float):
	if gpu == null or get_tree().paused or _game.restoring:
		return
	if (
		not _game.combat_effects.can_show_point(point)
		or not _game.battlefield_wear._observed_point(point)
	):
		return
	var flat = Vector2(point.x, point.z)
	var level = _field.level_at(flat)
	if absf(point.y - level) > 1.6:
		return
	if _queue(flat, clampf(strength, .5, 2.0), -.09 * clampf(strength, .2, 2.0)):
		for index in 8:
			var angle = index * TAU / 8.0
			_splashes.emit_particle(
				Transform3D(Basis.IDENTITY, Vector3(point.x, level + .1, point.z)),
				Vector3(cos(angle), 2.0, sin(angle)) * strength,
				Color(.7, .83, .82, .8),
				Color(),
				(
					GPUParticles3D.EMIT_FLAG_POSITION
					| GPUParticles3D.EMIT_FLAG_VELOCITY
					| GPUParticles3D.EMIT_FLAG_COLOR
				)
			)


func _queue(point: Vector2, radius: float, strength: float) -> bool:
	if (
		_pending.size() >= GPU.MAX_IMPULSES * 4
		or not Rect2(origin, Vector2.ONE * SPAN).grow(-2).has_point(point)
	):
		return false
	var pixel = Vector2i(point / _field.size * _field.RESOLUTION)
	if (
		pixel.x < 0
		or pixel.y < 0
		or pixel.x >= _field.RESOLUTION
		or pixel.y >= _field.RESOLUTION
		or _field.image.get_pixelv(pixel).a < .5
	):
		return false
	_pending.append_array(PackedFloat32Array([point.x, point.y, radius, strength]))
	return true


func _sample_units():
	var center = origin + Vector2.ONE * SPAN * .5
	var units = _game.battlefield.nearby_units(Vector3(center.x, 0, center.y), SPAN * .72)
	var next_positions = {}
	var count = 0
	for unit in units:
		if count >= MAX_UNITS:
			break
		if not unit.visible or not _game.combat_audio._observed(unit) or unit.movement_speed <= 0:
			continue
		count += 1
		var point = unit.global_position
		var flat = Vector2(point.x, point.z)
		if absf(point.y - _field.level_at(flat)) > .85:
			continue
		var id = unit.get_instance_id()
		next_positions[id] = flat
		if not _last_positions.has(id):
			continue
		var travel = flat.distance_to(_last_positions[id])
		if travel < .06 or travel > 3.0:
			continue
		_queue(flat, clampf(unit.radius, .45, 1.3), -.035 * minf(travel / .25, 1.0))
	_last_positions = next_positions


func _create_splashes():
	_splashes = GPUParticles3D.new()
	_splashes.amount = 64
	_splashes.lifetime = .7
	_splashes.emitting = false
	_splashes.visibility_aabb = AABB(
		Vector3(-20, -20, -20), Vector3(_field.size.x + 40, 80, _field.size.y + 40)
	)
	_splashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process = ParticleProcessMaterial.new()
	process.gravity = Vector3(0, -7, 0)
	_splashes.process_material = process
	var mesh = QuadMesh.new()
	mesh.size = Vector2(.06, .14)
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	_splashes.draw_pass_1 = mesh
	add_child(_splashes)


func _release():
	for material in _materials:
		material.set_shader_parameter("interactive_water", false)
		material.set_shader_parameter("ripple_state", null)
	gpu.dispose()
	gpu = null
	if is_instance_valid(_splashes):
		_splashes.queue_free()
	_splashes = null


func _exit_tree():
	if gpu != null:
		_release()
