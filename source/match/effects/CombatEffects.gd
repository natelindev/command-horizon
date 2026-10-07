extends Node3D

# Shared GPU particle buffers and bounded tracer/wreck pools, independent of combat authority.
const MAX_TRACERS = 96
const MAX_WRECKS = 24
var shots_emitted = 0
var impacts_emitted = 0
var deaths_emitted = 0
var _emitters = {}
var _tracers = []
var _free_tracers = []
var _wrecks = []
var _materials = {}
var _tracer_mesh = BoxMesh.new()
var _random = RandomNumberGenerator.new()
var _headless = false
var _paused = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	_random.seed = 73819  # Cosmetic randomness never changes the gameplay RNG.
	_tracer_mesh.size = Vector3.ONE
	if _headless:
		return
	_emitter("flash", 128, 0.12, Vector3.ZERO, 3.0, 0.1)
	_emitter("spark", 768, 0.45, Vector3(0, -7, 0), 2.0, 0.1)
	_emitter("smoke", 384, 1.7, Vector3(0, 0.35, 0), 0.0, 0.8)
	_emitter("dust", 256, 0.8, Vector3(0, -0.3, 0), 0.0, 0.7)
	_emitter("fire", 192, 0.55, Vector3(0, 1.4, 0), 1.7, 0.65)


func _emitter(kind, amount, lifetime, gravity, glow, roughness):
	var particles = GPUParticles3D.new()
	particles.name = kind.capitalize()
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(150, 40, 150))
	particles.fixed_fps = 30
	var material = ShaderMaterial.new()
	material.shader = load("res://source/shaders/3d/combat_particle_process.gdshader")
	material.set_shader_parameter("gravity", gravity)
	material.set_shader_parameter("growth_start", 0.55 if kind in ["smoke", "dust"] else 1.0)
	material.set_shader_parameter("growth_end", 1.0 if kind in ["smoke", "dust"] else 0.2)
	particles.process_material = material
	var mesh = QuadMesh.new()
	mesh.size = Vector2.ONE
	var shader = ShaderMaterial.new()
	shader.shader = load("res://source/shaders/3d/combat_particle.gdshader")

	shader.set_shader_parameter("glow", glow)
	shader.set_shader_parameter("rough_edge", roughness)
	mesh.material = shader
	particles.draw_pass_1 = mesh
	add_child(particles)
	_emitters[kind] = particles


func _puff(kind, point, velocity, color, size):
	if (
		_headless
		or get_tree().paused
		or (Globals.options.reduced_flashes and kind in ["flash", "spark", "fire"])
	):
		return
	var transform_here = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), point)
	_emitters[kind].emit_particle(transform_here, velocity, color, Color(), 1 | 2 | 4 | 8)


func shot(unit, origin, target_point, duration, missile = false, target_unit = null):
	get_parent().combat_audio.shot(unit, origin)
	shots_emitted += 1
	if _headless or not unit.visible:
		return
	var color = (
		Color("75edff")
		if (
			unit.player.faction == "helix"
			or (unit.type == "AdvancedTank" and unit.player.faction != "frontier")
		)
		else Color("ffd388")
	)
	var heavy = unit.type in ["Tank", "AdvancedTank", "AntiGroundTurret"]
	var direction = origin.direction_to(target_point)
	_puff("flash", origin, direction * 0.2, color, 0.65 if heavy else 0.3)
	for _index in range(5 if heavy else 2):
		_puff(
			"spark", origin, direction * _random.randf_range(2.0, 5.0) + _jitter(0.5), color, 0.12
		)
	if heavy:
		_puff(
			"smoke", origin, direction * 0.8 + Vector3.UP * 0.2, Color(0.48, 0.46, 0.41, 0.35), 0.9
		)
	if is_instance_valid(unit.aim_target) and not unit.aim_target.visible:
		return
	var entry = _take_tracer()
	if entry == null:
		return
	entry.node.material_override = _glowing_material(color)
	entry.origin = origin
	entry.target = target_point
	entry.target_ref = weakref(target_unit) if target_unit != null else null
	entry.duration = maxf(0.05, duration)
	entry.age = 0.0
	entry.missile = missile
	entry.rail = unit.type == "AdvancedTank" and unit.player.faction != "frontier"
	entry.width = 0.07 if heavy or missile else 0.035
	entry.trail_clock = 0.0
	entry.node.show()
	_tracers.append(entry)


func impact(unit, source, point):
	get_parent().combat_audio.impact(unit, source, point)
	impacts_emitted += 1
	if _headless or not unit.visible:
		return
	var heavy = (
		source.type in ["Tank", "AdvancedTank", "Helicopter", "AntiGroundTurret", "AntiAirTurret"]
	)
	var color = Color("b9faff") if source.type == "AdvancedTank" else Color("ffcc75")
	_puff("flash", point, Vector3.ZERO, color, 0.9 if heavy else 0.35)
	for _index in range(12 if heavy else 4):
		_puff(
			"spark", point, _jitter(3.0) + Vector3.UP * 1.8, color, _random.randf_range(0.05, 0.13)
		)
	if heavy:
		for _index in range(3):
			_puff("fire", point + _jitter(0.18), _jitter(0.6), Color(1.0, 0.35, 0.06, 0.85), 0.65)
			_puff(
				"smoke",
				point + _jitter(0.25),
				Vector3.UP * 0.5 + _jitter(0.3),
				Color(0.22, 0.22, 0.23, 0.55),
				1.1
			)
		_puff(
			"dust",
			Vector3(point.x, 0.12, point.z),
			Vector3.UP * 0.3,
			Color(0.54, 0.43, 0.29, 0.45),
			1.8
		)


func destruction(unit):
	get_parent().combat_audio.destruction(unit)
	deaths_emitted += 1
	if _headless or not unit.visible:
		return
	var point = unit.global_position + Vector3.UP * 0.35
	var infantry = unit.type == "Infantry"
	var size = clampf(unit.radius, 0.5, 2.0)
	if not infantry:
		_puff("flash", point, Vector3.ZERO, Color("ffe0a0"), size * 3.0)
		for _index in range(16):
			_puff("spark", point, _jitter(4.0) + Vector3.UP * 3.0, Color("ffb746"), 0.15)
		for _index in range(7):
			_puff(
				"fire",
				point + _jitter(size * 0.5),
				_jitter(1.0),
				Color(1, 0.28, 0.03, 0.8),
				size * 1.7
			)
			_puff(
				"smoke",
				point + _jitter(size * 0.4),
				Vector3.UP * 0.8 + _jitter(0.4),
				Color(0.13, 0.14, 0.16, 0.7),
				size * 2.5
			)
	_puff(
		"dust",
		Vector3(point.x, 0.12, point.z),
		Vector3.UP * 0.2,
		Color(0.5, 0.4, 0.28, 0.7),
		size * 3.0
	)
	_wreck(unit, infantry)


func movement_dust(unit):
	if not _headless and unit.visible:
		_puff(
			"dust",
			unit.global_position + Vector3.UP * 0.12,
			Vector3.UP * 0.12,
			Color(0.6, 0.49, 0.33, 0.17),
			unit.radius * 0.9
		)


func _wreck(unit, infantry):
	while _wrecks.size() >= MAX_WRECKS:
		_wrecks.pop_front().node.queue_free()
	var wreck = unit.get_node("Geometry").duplicate()
	add_child(wreck)
	wreck.global_transform = unit.get_node("Geometry").global_transform
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("36383a")
	material.roughness = 0.95
	for mesh in wreck.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
	_wrecks.append(
		{
			"node": wreck,
			"age": 0.0,
			"infantry": infantry,
			"origin": wreck.position,
			"rotation": wreck.rotation,
			"motion": unit.get_node("BastionVisuals").death_motion()
		}
	)


func _jitter(amount):
	return Vector3(
		_random.randf_range(-amount, amount),
		_random.randf_range(-amount, amount),
		_random.randf_range(-amount, amount)
	)


func _take_tracer():
	if not _free_tracers.is_empty():
		return _free_tracers.pop_back()
	if _tracers.size() >= MAX_TRACERS:
		return null
	var node = MeshInstance3D.new()
	node.mesh = _tracer_mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return {"node": node}


func _glowing_material(color):
	if not _materials.has(color):
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0
		_materials[color] = material
	return _materials[color]


func _process(_delta):
	if _paused != get_tree().paused:
		_paused = get_tree().paused
		for emitter in _emitters.values():
			emitter.speed_scale = 0.0 if _paused else 1.0


func _physics_process(delta):
	if get_tree().paused:
		return
	for index in range(_tracers.size() - 1, -1, -1):
		var entry = _tracers[index]
		entry.age += delta
		if entry.age >= entry.duration:
			entry.node.hide()
			_free_tracers.append(entry)
			_tracers.remove_at(index)
			continue
		if entry.target_ref != null:
			var target = entry.target_ref.get_ref()
			if target != null and not target.is_queued_for_deletion() and target.visible:
				entry.target = target.global_position + Vector3.UP * 0.5
		var direction = entry.origin.direction_to(entry.target)
		if direction.is_zero_approx():
			entry.node.hide()
			continue
		var progress = entry.age / entry.duration
		var head = entry.origin.lerp(entry.target, progress)
		if entry.missile:
			head.y += sin(progress * PI) * minf(0.8, entry.origin.distance_to(entry.target) * 0.08)
		var tail = (
			entry.origin if entry.rail else head - direction * (0.45 if entry.missile else 0.8)
		)
		if entry.rail:
			head = entry.target
		var length = maxf(0.01, head.distance_to(tail))
		var up = Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
		entry.node.transform = Transform3D(
			Basis.looking_at(direction, up).scaled(Vector3(entry.width, entry.width, length)),
			(head + tail) * 0.5
		)
		entry.trail_clock += delta
		if entry.missile and entry.trail_clock >= 0.04:
			entry.trail_clock = 0.0
			_puff("smoke", tail, Vector3.UP * 0.1, Color(0.65, 0.64, 0.61, 0.4), 0.3)
	for index in range(_wrecks.size() - 1, -1, -1):
		var entry = _wrecks[index]
		entry.age += delta
		if entry.age > 8.0:
			entry.node.queue_free()
			_wrecks.remove_at(index)
			continue
		_update_wreck(entry)


func _update_wreck(entry):
	var motion = entry.motion
	var progress = clampf(entry.age / motion.duration, 0.0, 1.0)
	# Air wrecks accelerate downward; grounded units ease into a soft settle.
	var settle = progress * progress if motion.airborne else smoothstep(0.0, 1.0, progress)
	entry.node.rotation = entry.rotation + motion.tilt * settle
	entry.node.position = entry.origin + motion.slide * settle
	var ground = 0.02 if motion.mobile else entry.origin.y - 0.18
	entry.node.position.y = lerpf(entry.origin.y, ground, settle)
	entry.node.position.y -= maxf(0.0, entry.age - motion.sink_start) * 0.25
