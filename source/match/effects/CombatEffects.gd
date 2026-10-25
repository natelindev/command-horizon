# gdlint: disable=max-file-lines
extends Node3D

const CombatRules = preload("res://source/match/combat/CombatRules.gd")
const InfantryRoster = preload("res://source/match/BastionCatalog.gd")
const InfantryMotion = preload("res://source/match/units/traits/InfantryMotion.gd")
const ObjectMaterials = preload("res://source/match/ObjectMaterials.gd")
const SHOCKWAVE_SHADER = preload("res://source/shaders/3d/explosion_shockwave.gdshader")
const SHOCKWAVE_FALLBACK = preload("res://source/shaders/3d/explosion_shockwave_fallback.gdshader")
const RAY_BEAM_SHADER = preload("res://source/shaders/3d/ray_beam.gdshader")

# Shared GPU particle buffers and bounded tracer/wreck pools, independent of combat authority.
const MAX_TRACERS = 96
const MAX_WRECKS = 24
const MAX_COOK_OFFS = 6
const MAX_HIT_FLASHES = 32
const MAX_SHOCKWAVES = 6
const MAX_WRECK_LIGHTS = 4
const HIT_DURATION = .14
const BEAM_DURATION = .24
const SHOCKWAVE_DURATION = .65
const WRECK_BURN_DURATION = 12.0
# Faction-tinted fire so a crossfire reads by owner; rail shots keep a cold charge color.
const FACTION_FIRE = {
	"bastion": Color("ffd9a0"),
	"helix": Color("aee4ee"),
	"frontier": Color("e3f0a6"),
}
const RAIL_FIRE = Color("b6d9e1")
const PRISM_FIRE = Color("8870ff")
var shots_emitted = 0
var impacts_emitted = 0
var deaths_emitted = 0
var aftermath
var _emitters = {}
var _tracers = []
var _free_tracers = []
var _wrecks = []
var _cook_offs = []
var _hit_flashes = []
var _free_hit_flashes = []
var _shockwaves = []
var _materials = {}
var _tracer_mesh = BoxMesh.new()
var _beam_mesh: ArrayMesh
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
	_emitter("mote", 192, 1.2, Vector3(0, 0.25, 0), 2.2, 0.2)
	# Separate bounded buffers keep dense missile trails from starving impact smoke.
	_emitter("trail_smoke", 2048, 1.25, Vector3(.06, .22, .025), 0.0, .72)
	_emitter("exhaust", 768, .1, Vector3.ZERO, 2.8, .38)
	_debris_emitter()


func _debris_emitter():
	var particles = GPUParticles3D.new()
	particles.name = "Shards"
	particles.emitting = false
	particles.amount = 192
	particles.lifetime = 1.1
	particles.local_coords = false
	particles.fixed_fps = 30
	particles.visibility_aabb = AABB(Vector3(-64, -16, -64), Vector3(384, 80, 384))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion = ParticleProcessMaterial.new()
	motion.gravity = Vector3(0, -9.8, 0)
	motion.use_rotation_3d = true
	motion.rotation_3d_min = Vector3(-180, -180, -180)
	motion.rotation_3d_max = Vector3(180, 180, 180)
	motion.use_rotation_velocity_3d = true
	motion.rotation_velocity_3d_min = Vector3(-240, -300, -180)
	motion.rotation_velocity_3d_max = Vector3(240, 300, 180)
	motion.use_scale_3d = true
	motion.scale_3d_min = Vector3(.04, .025, .08)
	motion.scale_3d_max = Vector3(.09, .045, .18)
	var shrink = Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(.65, 1))
	shrink.add_point(Vector2(1, 0))
	var curve = CurveXYZTexture.new()
	curve.curve_x = shrink
	curve.curve_y = shrink
	curve.curve_z = shrink
	motion.scale_curve = curve
	particles.process_material = motion
	var mesh = BoxMesh.new()
	var surface = StandardMaterial3D.new()
	surface.albedo_color = Color("67594a")
	surface.metallic = .45
	surface.roughness = .7
	mesh.material = surface
	particles.draw_pass_1 = mesh
	add_child(particles)
	_emitters.debris = particles


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
	var growth_start = .35 if kind in ["smoke", "dust"] else 1.0
	var growth_end = 1.15 if kind == "smoke" else (1.65 if kind in ["dust", "flash"] else .35)
	if kind == "trail_smoke":
		growth_start = .85
		growth_end = 2.8
	material.set_shader_parameter("growth_start", growth_start)
	material.set_shader_parameter("growth_end", growth_end)
	material.set_shader_parameter("damping", 1.1 if kind == "dust" else 0.45)
	material.set_shader_parameter("grounded", kind in ["dust", "spark"])
	material.set_shader_parameter("directional", kind in ["dust", "exhaust", "spark"])
	particles.process_material = material
	var mesh = QuadMesh.new()
	mesh.size = Vector2.ONE
	var shader = ShaderMaterial.new()
	shader.shader = load("res://source/shaders/3d/combat_particle.gdshader")

	shader.set_shader_parameter("flame", kind == "fire")
	shader.set_shader_parameter("exhaust", kind == "exhaust")
	shader.set_shader_parameter("glow", glow)
	shader.set_shader_parameter("rough_edge", roughness)
	shader.set_shader_parameter(
		"elongation",
		4.0 if kind == "exhaust" else (2.5 if kind == "spark" else (1.7 if kind == "dust" else 1.0))
	)
	mesh.material = shader
	particles.draw_pass_1 = mesh
	add_child(particles)
	_emitters[kind] = particles


func _puff(kind, point, velocity, color, size):
	if (
		_headless
		or get_tree().paused
		or (Globals.options.reduced_flashes and kind in ["flash", "spark", "fire", "exhaust"])
	):
		return
	var transform_here = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), point)
	var ground = _ground_height(point)
	_emitters[kind].emit_particle(
		transform_here, velocity, color, Color(ground, 0, 0, 0), 1 | 2 | 4 | 8 | 16
	)


func _ground_height(point):
	return get_parent().map.height_at(Vector2(point.x, point.z))


# Muzzle presentation and sound for one shot. Physical rounds draw themselves
# (ProjectileRenderer), so only instant rail beams still use a pooled tracer.
func shot(
	unit,
	origin,
	target_point,
	duration,
	missile = false,
	target_unit = null,
	tracer = true,
	weapon = {}
):
	get_parent().combat_audio.shot(unit, origin, weapon)
	shots_emitted += 1
	if not _can_show(unit):
		return
	var color = FACTION_FIRE.get(unit.player.faction, FACTION_FIRE.bastion)
	var rail = (
		weapon.get("kind", "") == "rail"
		or (weapon.is_empty() and unit.type == "AdvancedTank" and unit.player.faction != "frontier")
	)
	var prism = rail and unit.player.faction == "helix"
	if rail:
		color = PRISM_FIRE if prism else RAIL_FIRE
	var heavy = unit.type in ["Tank", "AdvancedTank", "AntiGroundTurret"]
	if heavy:
		_shake_camera(origin, 0.08)
	if not rail and _camera_sees(origin):
		aftermath.flash(origin, .5 if heavy else .18, color, true)
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
	if not tracer or (is_instance_valid(unit.aim_target) and not unit.aim_target.visible):
		return
	var entry = _take_tracer()
	if entry == null:
		return
	entry.origin = origin
	entry.target = target_point
	# Instant hits leave an afterimage along the original firing line.
	entry.target_ref = weakref(target_unit) if target_unit != null and not rail else null
	entry.duration = BEAM_DURATION if rail else maxf(0.05, duration)
	entry.age = 0.0
	entry.missile = missile
	entry.rail = rail
	entry.prism = prism
	entry.width = (.62 if prism else .38) if rail else (.045 if heavy or missile else .018)
	entry.trail_clock = 0.0
	if rail:
		if _beam_mesh == null:
			_beam_mesh = create_beam_mesh()
		entry.node.mesh = _beam_mesh
		if not entry.has("beam_material"):
			entry.beam_material = ShaderMaterial.new()
			entry.beam_material.shader = RAY_BEAM_SHADER
		entry.node.material_override = entry.beam_material
		entry.beam_material.set_shader_parameter("beam_color", color)
		entry.beam_material.set_shader_parameter(
			"core_color", Color("f1eaff") if prism else Color("edfcff")
		)
		entry.beam_material.set_shader_parameter("is_prism", prism)
		entry.beam_material.set_shader_parameter("scroll_speed", 4.0 if prism else 9.0)
		_beam_burst(origin, direction, color, prism)
		_beam_burst(target_point, -direction, color, prism)
	else:
		entry.node.mesh = _tracer_mesh
		entry.node.material_override = _glowing_material(color)
	_update_tracer(entry)
	entry.node.reset_physics_interpolation()
	_tracers.append(entry)


func _beam_burst(point, direction, color, prism):
	if Globals.options.reduced_flashes or not _camera_sees(point):
		return
	aftermath.flash(point, .85 if prism else .7, color, true)
	_puff("flash", point, Vector3.ZERO, color.lerp(Color.WHITE, .65), 1.05 if prism else .8)
	for index in 8:
		var ion_color = color
		if prism:
			ion_color = [Color("72eaff"), PRISM_FIRE, Color("ff72d8")][index % 3]
		var velocity = direction * _random.randf_range(1.0, 4.0) + _jitter(1.8)
		_puff("spark", point, velocity, ion_color, .07)
		if index < 3:
			_puff("mote", point, velocity * .25, ion_color, .12)


func impact(unit, source, point, weapon = {}):
	get_parent().combat_audio.impact(unit, source, point, weapon)
	impacts_emitted += 1
	if not _can_show(unit):
		return
	_material_hit(unit)
	var heavy = get_parent().combat_audio.heavy_impact(source, weapon)
	_water_impact(point, 1.0 if heavy else .3)
	var ground_hit = point.y - _ground_height(point) < 1.6
	var direction = source.global_position.direction_to(point)
	var armor = CombatRules.armor_for(unit.type)
	if armor in [1, 2] and not explosive_impact(source, weapon):
		_ricochet(unit, point, direction)
	if heavy:
		if explosive_impact(source, weapon):
			_explosion(point, .95, ground_hit)
		else:
			_armor_impact(
				point, direction, ground_hit, FACTION_FIRE.get(source.player.faction, RAIL_FIRE)
			)
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
				Vector3(point.x, _ground_height(point) + 0.1, point.z),
				Vector3.UP * 0.4,
				Color(0.49, 0.43, 0.34, 0.5),
				0.6
			)


static func explosive_impact(source, weapon = {}):
	if not weapon.is_empty():
		return weapon.get("kind", "") in ["rocket", "missile", "bomb", "warhead"]
	return (
		source.type
		in ["RocketInfantry", "MercenaryLancer", "Helicopter", "AntiAirTurret", "Fighter"]
	)


func can_show_point(point):
	return (
		not _headless
		and not get_tree().paused
		and not get_parent().restoring
		and (_camera == null or _camera_sees(point))
	)


# A compact white-hot jet cools into an overlapping, slowly rising smoke wake.
func trail(point, direction):
	if not can_show_point(point):
		return
	_puff("exhaust", point, -direction * 2.4, Color(1, .68, .3, .8), .22)
	_puff(
		"trail_smoke",
		point - direction * .12 + _jitter(.025),
		-direction * .22 + Vector3.UP * .12 + _jitter(.06),
		Color(.56, .55, .52, .46),
		_random.randf_range(.56, .66)
	)


# A round that struck the ground, a wreck-free obstacle, or expired in the air.
func miss(point, ground, heavy, color):
	_water_impact(point, .8 if heavy else .25)
	if heavy:
		_explosion(point, 0.75, ground)
		return
	_puff("flash", point, Vector3.ZERO, color, 0.16)
	for _index in range(3):
		_puff("spark", point, _jitter(1.6) + Vector3.UP * 1.2, color, 0.04)
	if ground:
		_puff(
			"dust",
			Vector3(point.x, point.y + 0.05, point.z),
			Vector3.UP * 0.5,
			Color(0.49, 0.43, 0.34, 0.45),
			0.38
		)


# A heavy warhead (bomb) detonating: a large blast scaled by its splash radius.
func warhead(point, radius, ground):
	_water_impact(point, clampf(radius * .4, .5, 2.0))
	_explosion(point, clampf(radius * 0.7, 1.0, 2.2), ground, true)


# Proximity-fused detonation in the air (flak, missiles).
func airburst(point, strength, color):
	_shake_camera(point, strength * 0.06)
	_puff("flash", point, Vector3.ZERO, color, strength * 1.2)
	for _index in range(6):
		_puff("spark", point, _jitter(3.0) * strength, Color("ffd9a0"), 0.05)
	_puff("smoke", point, Vector3.UP * 0.15, Color(0.18, 0.17, 0.16, 0.5), strength * 0.9)


func can_show_construction(unit):
	return _can_show(unit) and (_camera == null or _camera_sees(unit.global_position))


func construction_puff(kind, point, velocity, color, size):
	# Construction sites share the combat pools; callers check can_show_construction.
	_puff(kind, point, velocity, color, size)


func _camera_sees(point):
	if not is_instance_valid(_camera):
		return true
	var screen = _camera.unproject_position(point)
	return (
		not _camera.is_position_behind(point)
		and get_viewport().get_visible_rect().grow(96).has_point(screen)
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


static func ricochet_direction(incoming: Vector3, normal: Vector3) -> Vector3:
	if normal.is_zero_approx():
		return -incoming.normalized()
	return incoming.normalized().bounce(normal.normalized()).normalized()


func _ricochet(unit, point: Vector3, incoming: Vector3):
	# Cosmetic glancing fragments; damage and projectile authority stay unchanged.
	var normal = (point - unit.global_position) * Vector3(1, 0, 1)
	if normal.length_squared() < .01:
		normal = -incoming * Vector3(1, 0, 1)
	var reflected = ricochet_direction(incoming, normal)
	for index in 6:
		var velocity = reflected * _random.randf_range(3.5, 6.5) + _jitter(.7) + Vector3.UP * .9
		_puff("spark", point, velocity, Color("ffe4b0"), _random.randf_range(.035, .065))


func _armor_impact(point, direction, ground_hit, color):
	# A penetrating shell has a short, directional impact. Fireballs and physical
	# debris are reserved for destruction so surviving armor stays readable.
	_shake_camera(point, .08)
	_puff("flash", point, Vector3.ZERO, color, .65)
	for index in 7:
		_puff(
			"spark",
			point,
			-direction * 2.8 + _jitter(2.2) + Vector3.UP,
			color,
			_random.randf_range(.045, .085)
		)
	_puff("smoke", point, Vector3.UP * .4, Color(.25, .26, .27, .28), .55)
	if ground_hit:
		_puff(
			"dust",
			Vector3(point.x, _ground_height(point) + .12, point.z),
			Vector3.UP * .5,
			Color(.48, .40, .30, .38),
			.9
		)
		aftermath.scar(Vector3(point.x, 0, point.z), .65)


func _explosion(point, strength, ground_hit, destructive = false):
	if destructive and strength >= 1.5 and ground_hit:
		_shockwave(point, strength)
	if destructive:
		for index in 10:
			_puff(
				"debris",
				point,
				(_jitter(2.5) + Vector3.UP * 3.0) * sqrt(strength),
				Color.WHITE,
				1.0
			)
	_shake_camera(point, strength * 0.14)
	_puff("flash", point, Vector3.ZERO, Color("ffe9c0"), strength * 1.7)
	for _index in range(10 if destructive else 6):
		var velocity = _jitter(3.8) + Vector3.UP * 2.8
		_puff("spark", point, velocity * strength, Color("ffce8b"), _random.randf_range(0.04, 0.09))
	for _index in range(6 if destructive else 2):
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
		var jets = 12 if destructive else 4
		for index in range(jets):
			var angle = index * TAU / jets + _random.randf_range(-0.2, 0.2)
			var outward = Vector3(cos(angle), 0, sin(angle))
			var velocity = outward * _random.randf_range(1.4, 3.4) * strength
			velocity.y = _random.randf_range(0.15, 1.2)
			_puff(
				"dust",
				Vector3(point.x, _ground_height(point) + 0.15, point.z) + outward * 0.2,
				velocity,
				Color(0.48, 0.40, 0.30, 0.65),
				strength * _random.randf_range(0.8, 1.5)
			)
	if destructive:
		aftermath.burst(point, strength, ground_hit)
	elif ground_hit:
		aftermath.scar(Vector3(point.x, 0, point.z), strength * .7)


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
		_explosion(point, size * 2.0, point.y - _ground_height(point) < 1.6, true)
	else:
		_puff(
			"dust",
			Vector3(point.x, _ground_height(point) + 0.12, point.z),
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
			unit.global_basis.z * -.35 + Vector3.UP * 0.12,
			Color(0.6, 0.49, 0.33, 0.17),
			unit.radius * 0.9
		)


func _wreck(unit, infantry):
	while _wrecks.size() >= MAX_WRECKS:
		_wrecks.pop_front().node.queue_free()
	# Copy the posed meshes only: scripted model builders (convoy, VTOL) must not
	# run again on the wreck and stack a second hull inside it.
	var wreck = load("res://source/match/rendering/UnitBatchRenderer.gd").duplicate_geometry(
		unit.get_node("Geometry"), 0
	)
	add_child(wreck)
	wreck.global_transform = unit.get_node("Geometry").global_transform
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("36383a")
	material.roughness = 0.95
	for mesh in wreck.find_children("*", "GeometryInstance3D", true, false):
		# The wreck replaces every surface, including an unfinished building's shaders.
		# Hidden surface overrides can leave stale renderer RIDs when the wreck expires.
		if mesh is MeshInstance3D:
			for surface in mesh.get_surface_override_material_count():
				mesh.set_surface_override_material(surface, null)
		mesh.material_override = material
		mesh.material_overlay = null
	if (
		not infantry
		and unit.type in ["Tank", "AdvancedTank"]
		and not Globals.options.reduced_flashes
	):
		var turret_node = wreck.find_child("*TurretPivot*", true, false)
		if turret_node != null:
			_launch_turret_cook_off(turret_node, unit.radius)
	(
		_wrecks
		. append(
			{
				"node": wreck,
				"age": 0.0,
				"smoke_clock": 0.0,
				"fire_clock": 0.0,
				"fire_height": clampf(unit.radius * .8, .6, 1.8),
				"light": _wreck_light(wreck, unit.radius) if not infantry else null,
				"secondary": false,
				"size": clampf(unit.radius, 0.5, 2.0),
				"infantry": infantry,
				"origin": wreck.position,
				"rotation": wreck.rotation,
				"motion": unit.get_node("BastionVisuals").death_motion(),
				"momentum": _crash_momentum(unit),
			}
		)
	)


func _material_hit(unit):
	if (
		Globals.options.reduced_flashes
		or not unit.is_visible_in_tree()
		or not _camera_sees(unit.global_position)
	):
		return
	var geometry = unit.get_node_or_null("Geometry")
	if geometry == null:
		return
	for entry in _hit_flashes:
		if entry.unit.get_ref() == unit:
			# Sustained automatic fire does not pin the target at full brightness.
			return
	var recycled = {}
	if _hit_flashes.size() >= MAX_HIT_FLASHES:
		recycled = _hit_flashes.pop_front()
		ObjectMaterials.clear_hit_flash(recycled)
	elif not _free_hit_flashes.is_empty():
		recycled = _free_hit_flashes.pop_back()
	var entry = ObjectMaterials.hit_flash(geometry, Color("ffd6a1"), recycled)
	entry.unit = weakref(unit)
	_hit_flashes.append(entry)


func _shockwave(point, strength):
	if _headless or Globals.options.reduced_flashes or not _camera_sees(point):
		return
	while _shockwaves.size() >= MAX_SHOCKWAVES:
		var old = _shockwaves.pop_front().node
		old.hide()
		old.queue_free()
	var ring = create_shockwave(strength)
	add_child(ring)
	ring.position = Vector3(point.x, _ground_height(point) + .08, point.z)
	_shockwaves.append({"node": ring, "age": 0.0})


static func create_shockwave(strength):
	var ring = MeshInstance3D.new()
	ring.name = "ExplosionShockwave"
	ring.mesh = PlaneMesh.new()
	ring.mesh.size = Vector2.ONE * clampf(strength * 5.0, 4.0, 15.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = (
		SHOCKWAVE_FALLBACK
		if RenderingServer.get_current_rendering_method() == "gl_compatibility"
		else SHOCKWAVE_SHADER
	)
	ring.material_override = material
	return ring


func _wreck_light(wreck, size):
	if _headless or Globals.options.reduced_flashes or not _camera_sees(wreck.global_position):
		return null
	var count = 0
	for entry in _wrecks:
		if is_instance_valid(entry.get("light")):
			count += 1
	if count >= MAX_WRECK_LIGHTS:
		return null
	var light = OmniLight3D.new()
	light.name = "WreckFireLight"
	light.light_color = Color("ff9d4f")
	light.light_energy = .5
	light.omni_range = clampf(size * 2.0, 1.5, 4.0)
	light.shadow_enabled = false
	wreck.add_child(light)
	light.position.y = .65
	return light


func _advance_hit_flashes(delta):
	for index in range(_hit_flashes.size() - 1, -1, -1):
		var entry = _hit_flashes[index]
		entry.age += delta
		var target = entry.unit.get_ref()
		if (
			entry.age >= HIT_DURATION
			or Globals.options.reduced_flashes
			or target == null
			or target.is_queued_for_deletion()
			or not target.is_visible_in_tree()
		):
			ObjectMaterials.clear_hit_flash(entry)
			_hit_flashes.remove_at(index)
			_free_hit_flashes.append(entry)
		else:
			entry.material.set_shader_parameter(
				"hit_strength", .7 * (1.0 - entry.age / HIT_DURATION)
			)
	for index in range(_shockwaves.size() - 1, -1, -1):
		var entry = _shockwaves[index]
		entry.age += delta
		if entry.age >= SHOCKWAVE_DURATION or Globals.options.reduced_flashes:
			entry.node.queue_free()
			_shockwaves.remove_at(index)
		else:
			entry.node.material_override.set_shader_parameter(
				"progress", entry.age / SHOCKWAVE_DURATION
			)


func _advance_wreck_fire(entry, delta):
	var burn = 1.0 - smoothstep(7.0, WRECK_BURN_DURATION, entry.age)
	if is_instance_valid(entry.light):
		if burn <= 0.0 or Globals.options.reduced_flashes:
			entry.light.queue_free()
			entry.light = null
		else:
			entry.light.visible = _camera_sees(entry.node.global_position)
			entry.light.light_energy = (
				burn * (.38 + .09 * sin(entry.age * 7.3) + .04 * sin(entry.age * 13.1))
			)
	if entry.infantry or burn <= 0.0 or not _camera_sees(entry.node.global_position):
		return
	entry.fire_clock += delta
	if entry.fire_clock >= .22:
		entry.fire_clock = 0.0
		_puff(
			"fire",
			entry.node.position + Vector3.UP * entry.get("fire_height", .6) + _jitter(.18),
			Vector3.UP * .5,
			Color(1, .4, .1, .6 * burn),
			entry.size * .65 * burn
		)


# A stricken aircraft keeps its horizontal velocity and slows as it falls, so a
# jet arcs forward into the ground instead of dropping in place.
func _crash_momentum(unit):
	var movement = unit.get_node_or_null("Movement")
	if movement == null or unit.movement_domain != 0:
		return Vector3.ZERO
	var velocity = (
		movement.flight_velocity() if movement.has_method("flight_velocity") else movement.velocity
	)
	return velocity * Vector3(1, 0, 1)


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
	body.reset_physics_interpolation()

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


static func create_beam_mesh() -> ArrayMesh:
	# Two perpendicular ribbons share the firing axis (-Z). UV.x runs muzzle to
	# impact; UV.y always crosses the core, so the Gaussian works on both planes.
	var vertices = PackedVector3Array(
		[
			Vector3(-.5, 0, .5),
			Vector3(.5, 0, .5),
			Vector3(-.5, 0, -.5),
			Vector3(.5, 0, -.5),
			Vector3(0, -.5, .5),
			Vector3(0, .5, .5),
			Vector3(0, -.5, -.5),
			Vector3(0, .5, -.5),
		]
	)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(0, 1),
			Vector2(1, 0),
			Vector2(1, 1),
			Vector2(0, 0),
			Vector2(0, 1),
			Vector2(1, 0),
			Vector2(1, 1),
		]
	)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2, 4, 5, 6, 5, 7, 6])
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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
	# Settings can change while the battle is paused; remove frozen flashes then too.
	if Globals.options.reduced_flashes:
		_advance_hit_flashes(0.0)
		for entry in _tracers:
			if entry.rail:
				entry.beam_material.set_shader_parameter("intensity", .65)
		if is_instance_valid(aftermath):
			aftermath.clear_flashes()
		for entry in _wrecks:
			if is_instance_valid(entry.light):
				entry.light.queue_free()
				entry.light = null
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
	_advance_hit_flashes(delta)
	_advance_tracers(delta)
	_advance_aftermath(delta)


func _advance_tracers(delta):
	for index in range(_tracers.size() - 1, -1, -1):
		var entry = _tracers[index]
		entry.age += delta
		if entry.age >= entry.duration:
			if entry.rail:
				entry.beam_material.set_shader_parameter("progress", 1.0)
			entry.node.hide()
			entry.target_ref = null
			_free_tracers.append(entry)
			_tracers.remove_at(index)
			continue
		if entry.target_ref != null:
			var target = entry.target_ref.get_ref()
			if target != null and not target.is_queued_for_deletion() and target.visible:
				entry.target = target.global_position + Vector3.UP * 0.5
		var tail = _update_tracer(entry)
		if not entry.node.visible:
			continue
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


func _update_tracer(entry):
	var progress = clampf(entry.age / entry.duration, 0.0, 1.0)
	if entry.rail:
		entry.beam_material.set_shader_parameter("progress", progress)
		entry.beam_material.set_shader_parameter(
			"intensity", .65 if Globals.options.reduced_flashes else (3.0 if entry.prism else 2.5)
		)
	var direction = entry.origin.direction_to(entry.target)
	entry.node.visible = not direction.is_zero_approx()
	if not entry.node.visible:
		return entry.origin
	var head = entry.origin.lerp(entry.target, progress)
	if entry.rail:
		head = entry.target
	elif entry.missile:
		var arc = minf(.8, entry.origin.distance_to(entry.target) * .08)
		head.y += sin(progress * PI) * arc
		direction = (
			(entry.target - entry.origin + Vector3.UP * cos(progress * PI) * PI * arc).normalized()
		)
	var tail = (
		entry.origin
		if entry.rail
		else (
			head - direction * minf(head.distance_to(entry.origin), .28 if entry.missile else .55)
		)
	)
	var length = maxf(.01, head.distance_to(tail))
	var up = Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > .98 else Vector3.UP
	entry.node.transform = Transform3D(
		(
			Basis.looking_at(direction, up)
			* Basis.from_scale(Vector3(entry.width, entry.width, length))
		),
		(head + tail) * .5
	)
	return tail


func _advance_aftermath(delta):
	for index in range(_wrecks.size() - 1, -1, -1):
		var entry = _wrecks[index]
		entry.age += delta
		if entry.age > 20.0:
			entry.node.queue_free()
			_wrecks.remove_at(index)
			continue
		_update_wreck(entry)
		_advance_wreck_fire(entry, delta)
		entry.smoke_clock += delta
		if (
			not entry.infantry
			and entry.age < WRECK_BURN_DURATION
			and entry.smoke_clock > 0.8
			and _camera_sees(entry.node.global_position)
		):
			entry.smoke_clock = 0.0
			var point = entry.node.position + Vector3.UP * 0.45
			_puff(
				"smoke",
				point + _jitter(0.2),
				Vector3(0.15, 0.8, 0.07),
				Color(0.16, 0.16, 0.15, 0.32),
				entry.size * 0.9
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
	if motion.get("infantry", false):
		# Soldiers buckle at the knees first, then topple with gravity and a small bounce.
		var fall = clampf((progress - .3) / .7, 0.0, 1.0)
		settle = fall * fall - sin(clampf((progress - .92) / .08, 0.0, 1.0) * PI) * .05
		if progress < 1.0 or not entry.has("posed"):
			InfantryMotion.pose_death(entry.node, progress, motion.style)
			if progress >= 1.0:
				entry.posed = true
	if motion.get("infantry", false):
		if not entry.has("rest_scale"):
			entry.rest_scale = entry.node.scale
		# Euler pitch+roll does not produce a horizontal body for diagonal
		# falls. Rotate around the recipe's horizontal axis through exactly
		# a quarter turn, keeping the original heading and relaxing live lean.
		var axis = Vector3(motion.tilt.x, 0, motion.tilt.z).normalized()
		if axis.is_zero_approx():
			axis = Vector3.RIGHT
		var yaw = Basis(Vector3.UP, entry.rotation.y + motion.tilt.y * settle)
		var lean = Basis.from_euler(Vector3(entry.rotation.x, 0, entry.rotation.z) * (1.0 - settle))
		entry.node.basis = (
			yaw * Basis(axis, PI * .5 * settle) * lean * Basis.from_scale(entry.rest_scale)
		)
	else:
		entry.node.rotation = entry.rotation + motion.tilt * settle
		# Stricken aircraft yaw as they fall.
		entry.node.rotation.y += motion.get("spin", 0.0) * settle
	entry.node.position = entry.origin + motion.slide * settle
	entry.node.position += (
		entry.get("momentum", Vector3.ZERO)
		* motion.duration
		* (progress - progress * progress * .5)
	)
	var ground = 0.02 if motion.mobile else entry.origin.y - 0.18
	entry.node.position.y = lerpf(entry.origin.y, ground, settle)
	if motion.get("infantry", false):
		# Tilting the rig about its origin puts the chest and helmet through the
		# ground. Keep its visible geometry above the floor as the knees buckle.
		# Only moving wrecks need this solve; retain the final offset at rest.
		if not entry.has("ground_clearance"):
			var clearance = _infantry_ground_clearance(entry, ground)
			entry.node.position.y += clearance
			if progress >= 1.0:
				entry.ground_clearance = clearance
		else:
			entry.node.position.y += entry.ground_clearance
	entry.node.position.y -= maxf(0.0, entry.age - maxf(16.0, motion.sink_start)) * 0.25


func _infantry_ground_clearance(entry, ground):
	if not entry.has("ground_bounds"):
		entry.ground_bounds = []
		for mesh in entry.node.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh != null and mesh.is_visible_in_tree():
				entry.ground_bounds.append({"node": mesh, "bounds": mesh.get_aabb()})
	var parent_inverse = entry.node.get_parent().global_transform.affine_inverse()
	var lowest = ground
	for part in entry.ground_bounds:
		var transform: Transform3D = parent_inverse * part.node.global_transform
		var bounds: AABB = transform * part.bounds
		if bounds.position.y >= lowest:
			continue
		# Batched meshes have empty AABB corners: rotating those bounds alone
		# lifts a corpse off the floor. Resolve only potential contacts against
		# the actual authored vertices, caching them the first time needed.
		if not part.has("points"):
			part.points = PackedVector3Array()
			for surface in part.node.mesh.get_surface_count():
				part.points.append_array(
					part.node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				)
		for point in part.points:
			lowest = minf(lowest, (transform * point).y)
	return ground - lowest


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
	for entry in _hit_flashes:
		ObjectMaterials.clear_hit_flash(entry)
	_hit_flashes.clear()
	_free_hit_flashes.clear()
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


func _water_impact(point: Vector3, strength: float):
	var atmosphere = get_parent().get_node_or_null("WorldAtmosphere")
	if atmosphere != null and atmosphere.effects != null:
		atmosphere.effects.water_interactions.impact(point, strength)
