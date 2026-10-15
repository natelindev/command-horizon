extends Node3D

const InfantryRoster = preload("res://source/match/BastionCatalog.gd")

# Shared GPU particle buffers and bounded tracer/wreck pools, independent of combat authority.
const MAX_TRACERS = 96
const MAX_WRECKS = 24
const MAX_COOK_OFFS = 6
# Faction-tinted fire so a crossfire reads by owner; rail shots keep a cold charge color.
const FACTION_FIRE = {
	"bastion": Color("ffd9a0"),
	"helix": Color("aee4ee"),
	"frontier": Color("e3f0a6"),
}
const RAIL_FIRE = Color("b6d9e1")
var shots_emitted = 0
var impacts_emitted = 0
var deaths_emitted = 0
var aftermath
var _emitters = {}
var _tracers = []
var _free_tracers = []
var _wrecks = []
var _cook_offs = []
var _materials = {}
var _tracer_mesh = BoxMesh.new()
var _random = RandomNumberGenerator.new()
var _headless = false
var _paused = false
var _camera = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	_random.seed = 73819  # Cosmetic randomness never changes the gameplay RNG.
	_tracer_mesh.size = Vector3.ONE
	var signals = get_node_or_null("/root/MatchSignals")
	if signals != null and not signals.tactical_ping.is_connected(_on_tactical_ping):
		signals.tactical_ping.connect(_on_tactical_ping)
	if _headless:
		return
	if get_parent() != null:
		_camera = get_parent().get_node_or_null("IsometricCamera3D")
	aftermath = preload("res://source/match/effects/BattleAftermath.gd").new()
	aftermath.name = "BattleAftermath"
	add_child(aftermath)
	_emitter("flash", 128, 0.075, Vector3.ZERO, 2.4, 0.25)
	_emitter("spark", 768, 0.65, Vector3(0, -9.8, 0), 1.6, 0.1)
	_emitter("smoke", 384, 1.8, Vector3(0.08, 0.16, 0.035), 0.0, 0.95)
	_emitter("dust", 512, 2.1, Vector3(0, -0.15, 0), 0.0, 0.95)
	_emitter("fire", 256, 0.65, Vector3(0, 0.8, 0), 2.0, 0.85)


func _emitter(kind, amount, lifetime, gravity, glow, roughness):
	var particles = GPUParticles3D.new()
	particles.name = kind.capitalize()
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-64, -16, -64), Vector3(384, 80, 384))
	particles.fixed_fps = 60
	particles.local_coords = false
	particles.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	var material = ShaderMaterial.new()
	material.shader = load("res://source/shaders/3d/combat_particle_process.gdshader")
	material.set_shader_parameter("gravity", gravity)
	material.set_shader_parameter("growth_start", 0.35 if kind in ["smoke", "dust"] else 1.0)
	material.set_shader_parameter(
		"growth_end", 1.15 if kind == "smoke" else (1.65 if kind == "dust" else 0.35)
	)
	material.set_shader_parameter("damping", 1.1 if kind == "dust" else 0.45)
	material.set_shader_parameter("grounded", kind in ["dust", "spark"])
	particles.process_material = material
	var mesh = QuadMesh.new()
	mesh.size = Vector2.ONE
	var shader = ShaderMaterial.new()
	shader.shader = load("res://source/shaders/3d/combat_particle.gdshader")

	shader.set_shader_parameter("flame", kind == "fire")
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
	if not _can_show(unit):
		return
	var color = FACTION_FIRE.get(unit.player.faction, FACTION_FIRE.bastion)
	if unit.type == "AdvancedTank" and unit.player.faction != "frontier":
		color = RAIL_FIRE
	var heavy = unit.type in ["Tank", "AdvancedTank", "AntiGroundTurret"]
	if heavy:
		_shake_camera(origin, 0.08)
		aftermath.flash(origin, 0.3, color, true)
	var direction = origin.direction_to(target_point)
	_puff("flash", origin, direction * 0.2, color, 0.65 if heavy else 0.3)
	for _index in range(5 if heavy else 2):
		_puff(
			"spark", origin, direction * _random.randf_range(2.0, 5.0) + _jitter(0.5), color, 0.12
		)
	if heavy:
		_puff(
			"smoke", origin, direction * 0.8 + Vector3.UP * 0.2, Color(0.48, 0.46, 0.41, 0.2), 0.55
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
	entry.width = 0.045 if heavy or missile else 0.018
	entry.trail_clock = 0.0
	entry.node.show()
	_tracers.append(entry)


func impact(unit, source, point):
	get_parent().combat_audio.impact(unit, source, point)
	impacts_emitted += 1
	if not _can_show(unit):
		return
	var heavy = (
		source.type
		in [
			"Tank",
			"AdvancedTank",
			"Helicopter",
			"AntiGroundTurret",
			"AntiAirTurret",
			"RocketInfantry"
		]
	)
	var ground_hit = point.y < 1.6
	var direction = source.global_position.direction_to(point)
	if heavy:
		_explosion(point, 0.95 if source.type == "RocketInfantry" else 1.25, ground_hit)
	else:
		_puff("flash", point, Vector3.ZERO, Color("ffe2a8"), 0.24)
		for _index in range(5):
			_puff(
				"spark",
				point,
				-direction * 1.6 + _jitter(1.8) + Vector3.UP,
				Color("ffd19a"),
				_random.randf_range(0.035, 0.07)
			)
		_puff("smoke", point, Vector3.UP * 0.2, Color(0.32, 0.3, 0.27, 0.18), 0.3)
		if ground_hit:
			_puff(
				"dust",
				Vector3(point.x, 0.1, point.z),
				Vector3.UP * 0.4,
				Color(0.49, 0.43, 0.34, 0.5),
				0.6
			)


func _can_show(unit):
	return (
		not _headless
		and is_instance_valid(unit)
		and unit.visible
		and not get_tree().paused
		and not get_parent().restoring
		and get_parent().combat_audio._observed(unit)
	)


func _shake_camera(point, amount):
	if _headless or not is_instance_valid(_camera) or not _camera.has_method("add_trauma"):
		return
	if Globals.options.reduced_flashes:
		return
	var screen = _camera.unproject_position(point)
	if not get_viewport().get_visible_rect().grow(128).has_point(screen):
		return
	var dist = point.distance_to(_camera.global_position)
	var factor = clampf(1.0 - (dist / 70.0), 0.25, 1.0)
	_camera.add_trauma(amount * factor)


func _explosion(point, strength, ground_hit):
	_shake_camera(point, strength * 0.14)
	_puff("flash", point, Vector3.ZERO, Color("ffe9c0"), strength * 1.7)
	for _index in range(10):
		var velocity = _jitter(3.8) + Vector3.UP * 2.8
		_puff("spark", point, velocity * strength, Color("ffce8b"), _random.randf_range(0.04, 0.09))
	for _index in range(6):
		var offset = _jitter(strength * 0.3)
		_puff(
			"fire",
			point + offset,
			offset * 2.0 + Vector3.UP * 0.6,
			Color(1, 0.5, 0.15, 0.9),
			strength * _random.randf_range(0.7, 1.3)
		)
		# Two compact wisps keep repeated impacts from blanketing the firing line.
		if _index < 2:
			_puff(
				"smoke",
				point + offset,
				offset + Vector3.UP * _random.randf_range(0.6, 1.0),
				Color(0.22, 0.21, 0.20, 0.42),
				strength * _random.randf_range(0.7, 1.15)
			)
	if ground_hit:
		# Uneven radial dirt jets, not a uniform expanding ring.
		for index in range(12):
			var angle = index * TAU / 12.0 + _random.randf_range(-0.2, 0.2)
			var outward = Vector3(cos(angle), 0, sin(angle))
			var velocity = outward * _random.randf_range(1.4, 3.4) * strength
			velocity.y = _random.randf_range(0.15, 1.2)
			_puff(
				"dust",
				Vector3(point.x, 0.15, point.z) + outward * 0.2,
				velocity,
				Color(0.48, 0.40, 0.30, 0.65),
				strength * _random.randf_range(0.8, 1.5)
			)
	aftermath.burst(point, strength, ground_hit)


func destruction(unit):
	get_parent().combat_audio.destruction(unit)
	deaths_emitted += 1
	if not _can_show(unit):
		return
	var point = unit.global_position + Vector3.UP * 0.35
	var infantry = InfantryRoster.is_infantry(unit.type)
	var size = clampf(unit.radius, 0.5, 2.0)
	_shake_camera(point, size * 0.18)
	if not infantry:
		_explosion(point, size * 2.0, point.y < 1.6)
	else:
		_puff(
			"dust",
			Vector3(point.x, 0.12, point.z),
			Vector3.UP * 0.3,
			Color(0.5, 0.43, 0.33, 0.45),
			size * 1.4
		)
	_wreck(unit, infantry)


func movement_dust(unit):
	if _can_show(unit):
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
		# The wreck replaces every surface, including an unfinished building's shaders.
		# Hidden surface overrides can leave stale renderer RIDs when the wreck expires.
		for surface in mesh.get_surface_override_material_count():
			mesh.set_surface_override_material(surface, null)
		mesh.material_override = material
	if (
		not infantry
		and unit.type in ["Tank", "AdvancedTank"]
		and not Globals.options.reduced_flashes
	):
		var turret_node = wreck.find_child("*TurretPivot*", true, false)
		if turret_node != null:
			_launch_turret_cook_off(turret_node, unit.radius)
	_wrecks.append(
		{
			"node": wreck,
			"age": 0.0,
			"smoke_clock": 0.0,
			"secondary": false,
			"size": clampf(unit.radius, 0.5, 2.0),
			"infantry": infantry,
			"origin": wreck.position,
			"rotation": wreck.rotation,
			"motion": unit.get_node("BastionVisuals").death_motion()
		}
	)


func _launch_turret_cook_off(turret_node, unit_radius):
	while _cook_offs.size() >= MAX_COOK_OFFS:
		var old = _cook_offs.pop_front()
		if is_instance_valid(old.node):
			old.node.queue_free()
	var global_xform = (
		turret_node.global_transform if turret_node.is_inside_tree() else turret_node.transform
	)
	var parent = turret_node.get_parent()
	if parent != null:
		parent.remove_child(turret_node)

	var body = RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.input_ray_pickable = false
	body.mass = 2.5
	body.continuous_cd = true
	body.linear_damp = 0.2
	body.angular_damp = 0.5
	if aftermath != null:
		body.physics_material_override = aftermath._physics_material

	body.add_child(turret_node)
	# Physics bodies must stay unscaled: the physics server discards body scale.
	# Keep the imported vehicle scale on the detached visual instead.
	turret_node.transform = Transform3D(
		Basis.IDENTITY.scaled(global_xform.basis.get_scale()), Vector3.ZERO
	)

	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(unit_radius * 0.9, 0.45, unit_radius * 0.9)
	collider.shape = shape
	body.add_child(collider)

	add_child(body)
	body.global_transform = Transform3D(global_xform.basis.orthonormalized(), global_xform.origin)

	var angle = _random.randf() * TAU
	var up_speed = _random.randf_range(4.5, 6.8)
	var out_speed = _random.randf_range(1.0, 2.2)
	body.linear_velocity = Vector3(cos(angle) * out_speed, up_speed, sin(angle) * out_speed)
	body.angular_velocity = Vector3(
		_random.randf_range(-8, 8), _random.randf_range(-12, 12), _random.randf_range(-8, 8)
	)
	(
		_cook_offs
		. append(
			{
				"node": body,
				"age": 0.0,
				"smoke_clock": 0.0,
			}
		)
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
		for entry in _cook_offs:
			if is_instance_valid(entry.node) and entry.node is RigidBody3D:
				entry.node.freeze = _paused


func _physics_process(delta):
	if get_tree().paused:
		return
	for index in range(_tracers.size() - 1, -1, -1):
		var entry = _tracers[index]
		entry.age += delta
		if entry.age >= (minf(entry.duration, 0.075) if entry.rail else entry.duration):
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
			var arc = minf(0.8, entry.origin.distance_to(entry.target) * 0.08)
			head.y += sin(progress * PI) * arc
			direction = (
				(entry.target - entry.origin + Vector3.UP * cos(progress * PI) * PI * arc)
				. normalized()
			)
		var tail = (
			entry.origin
			if entry.rail
			else (
				head
				- direction * minf(head.distance_to(entry.origin), 0.28 if entry.missile else 0.55)
			)
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
			_puff(
				"smoke",
				tail,
				Vector3.UP * 0.1,
				Color(0.58, 0.56, 0.52, 0.3),
				_random.randf_range(0.18, 0.32)
			)
	for index in range(_wrecks.size() - 1, -1, -1):
		var entry = _wrecks[index]
		entry.age += delta
		if entry.age > 20.0:
			entry.node.queue_free()
			_wrecks.remove_at(index)
			continue
		_update_wreck(entry)
		entry.smoke_clock += delta
		if not entry.infantry and entry.age < 4.0 and entry.smoke_clock > 0.65:
			entry.smoke_clock = 0.0
			var point = entry.node.position + Vector3.UP * 0.45
			_puff(
				"smoke",
				point + _jitter(0.2),
				Vector3(0.15, 0.8, 0.07),
				Color(0.16, 0.16, 0.15, 0.32),
				entry.size * 0.9
			)
			if entry.age < 4.0:
				_puff(
					"fire",
					point + _jitter(0.25),
					Vector3.UP * 0.5,
					Color(1, 0.4, 0.1, 0.7),
					entry.size * 0.7
				)
		if not entry.infantry and not entry.secondary and entry.age > 0.7:
			entry.secondary = true
			_explosion(
				entry.node.position + Vector3.UP * 0.35,
				entry.size * 0.65,
				entry.node.position.y < 1.2
			)
	for index in range(_cook_offs.size() - 1, -1, -1):
		var entry = _cook_offs[index]
		if not is_instance_valid(entry.node):
			_cook_offs.remove_at(index)
			continue
		entry.age += delta
		entry.smoke_clock += delta
		if entry.age < 3.5 and entry.smoke_clock >= 0.09:
			entry.smoke_clock = 0.0
			_puff(
				"smoke",
				entry.node.global_position,
				Vector3.UP * 0.25,
				Color(0.18, 0.18, 0.17, 0.35),
				0.35
			)
		if entry.age >= 14.0:
			entry.node.queue_free()
			_cook_offs.remove_at(index)
	if aftermath != null:
		aftermath.advance(delta)


func _update_wreck(entry):
	var motion = entry.motion
	var progress = clampf(entry.age / motion.duration, 0.0, 1.0)
	# Air wrecks accelerate downward; grounded units ease into a soft settle.
	var settle = progress * progress if motion.airborne else smoothstep(0.0, 1.0, progress)
	entry.node.rotation = entry.rotation + motion.tilt * settle
	entry.node.position = entry.origin + motion.slide * settle
	var ground = 0.02 if motion.mobile else entry.origin.y - 0.18
	entry.node.position.y = lerpf(entry.origin.y, ground, settle)
	entry.node.position.y -= maxf(0.0, entry.age - maxf(16.0, motion.sink_start)) * 0.25


func damage_smoke(unit):
	if InfantryRoster.is_infantry(unit.type):
		return
	if unit.hp == null or unit.hp_max == null or unit.hp <= 0 or unit.hp > unit.hp_max * 0.3:
		return
	if not _can_show(unit):
		return
	var severity = 1.0 - unit.hp / unit.hp_max
	var point = unit.global_position + Vector3.UP * (0.6 if unit.movement_speed > 0 else 1.4)
	_puff(
		"smoke",
		point + _jitter(0.16),
		Vector3(0.12, 0.65, 0.04),
		Color(0.18, 0.18, 0.17, severity * 0.3),
		clampf(unit.radius * 0.7, 0.35, 0.85)
	)
	if severity > 0.8:
		_puff("fire", point, Vector3.UP * 0.3, Color(1, 0.4, 0.1, 0.65), 0.38)


func _exit_tree():
	for entry in _cook_offs:
		if is_instance_valid(entry.node):
			entry.node.queue_free()
	_cook_offs.clear()


func _on_tactical_ping(point):
	var stream = load("res://assets/audio/combat/tactical_ping.wav")
	if stream != null and not _headless:
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.bus = "Effects"
		audio_player.stream = stream
		audio_player.unit_size = 40.0
		audio_player.max_distance = 250.0
		add_child(audio_player)
		audio_player.global_position = point
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)
	_spawn_ping_visual(point)


func _spawn_ping_visual(point):
	if _headless:
		return
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	ring.mesh = torus
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.78, 0.15, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	add_child(ring)
	ring.global_position = point + Vector3.UP * 0.05
	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector3(4.5, 1.0, 4.5), 0.85)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.85)
	tween.tween_callback(ring.queue_free)
