# gdlint: disable=duplicated-load,max-file-lines,max-public-methods
# Runtime loading avoids autoload-dependent preload cycles.
extends Node3D

const CombatRules = preload("res://source/match/combat/CombatRules.gd")
const InfantryRoster = preload("res://source/match/BastionCatalog.gd")
const InfantryMotion = preload("res://source/match/units/traits/InfantryMotion.gd")
const ObjectMaterials = preload("res://source/match/ObjectMaterials.gd")
const SHOCKWAVE_SHADER = preload("res://source/shaders/3d/explosion_shockwave.gdshader")
const SHOCKWAVE_FALLBACK = preload("res://source/shaders/3d/explosion_shockwave_fallback.gdshader")
const MUZZLE_SHADER = preload("res://source/shaders/3d/cannon_muzzle.gdshader")
const MUZZLE_FALLBACK = preload("res://source/shaders/3d/cannon_muzzle_fallback.gdshader")
const RAY_BEAM_SHADER = preload("res://source/shaders/3d/ray_beam.gdshader")
const BeamAppearance = preload("res://source/match/effects/BeamAppearance.gd")
const ShieldImpactVisual = preload("res://source/match/effects/ShieldImpactVisual.gd")
const PhaseShiftVisual = preload("res://source/match/effects/PhaseShiftVisual.gd")
const GroundContact = preload("res://source/match/effects/GroundContactProfile.gd")

# Shared GPU particle buffers and bounded tracer/wreck pools, independent of combat authority.
const MAX_TRACERS = 96
const MAX_WRECKS = 24
const MAX_COOK_OFFS = 6
const MAX_HIT_FLASHES = 32
const MAX_SHOCKWAVES = 6
const MAX_WRECK_LIGHTS = 4
const HIT_DURATION = .14
const SHOCKWAVE_DURATION = .65
const WRECK_BURN_DURATION = 12.0
const MAX_ABILITY_EFFECTS = 64
const MAX_GRENADES = 32
const MAX_BLAST_TAILS = 32
const MAX_SHIELD_RIPPLES = 24
const MAX_PHASE_REMNANTS = 16
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
var shield_impacts_emitted = 0
var deaths_emitted = 0
var aftermath
var foliage
var world_abilities
var _weapon_heat
var _dust_biome := "desert"
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
var _ability_effects = []
var _grenades = []
var _blast_tails = []
var _shield_ripples = []
var _ground_map
var _phase_remnants = []


func watch_unit(unit):
	var watcher = (
		unit.get_meta("combat_effects_watcher") if unit.has_meta("combat_effects_watcher") else null
	)
	if watcher != null and watcher.get_ref() == self:
		return
	unit.set_meta("combat_effects_watcher", weakref(self))
	for pair in [
		[unit.shield_component.broken, ShieldImpactVisual.Mode.BREAK],
		[unit.shield_component.recharge_started, ShieldImpactVisual.Mode.RECHARGE],
		[unit.shield_component.recharged, ShieldImpactVisual.Mode.RESTORED]
	]:
		var callback = _shield_lifecycle.bind(weakref(unit), pair[1])
		if not pair[0].is_connected(callback):
			pair[0].connect(callback)
	var movement = unit.get_node_or_null("Movement")
	if movement != null and movement.has_signal("phase_shifted"):
		var callback = _phase_shifted.bind(weakref(unit))
		if not movement.phase_shifted.is_connected(callback):
			movement.phase_shifted.connect(callback)


func _phase_shifted(origin: Vector3, destination: Vector3, reference: WeakRef):
	var unit = reference.get_ref()
	if is_instance_valid(unit):
		phase_shift(origin, destination, unit.player, unit)


func phase_shift(origin: Vector3, destination: Vector3, owner = null, unit = null):
	for point in [origin, destination]:
		if not can_show_point(point) or not get_parent().combat_audio.point_observed(point, owner):
			continue
		var arriving = point == destination
		if not Globals.options.reduced_flashes:
			while _phase_remnants.size() >= MAX_PHASE_REMNANTS:
				var old = _phase_remnants.pop_front()
				old.hide()
				old.queue_free()
			var remnant = PhaseShiftVisual.new()
			add_child(remnant)
			remnant.setup(point, arriving, owner, unit if not arriving else null)
			_phase_remnants.append(remnant)
		for index in 12:
			var radial = Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 12.0)
			var velocity = radial * (2.5 if arriving else -1.8) + Vector3.UP * .4
			_puff("spark", point + Vector3.UP * .7 + radial * .8, velocity, Color("69ddff"), .055)
			if index % 3 == 0:
				_puff(
					"smoke",
					point + radial * .5 + Vector3.UP * .3,
					velocity * .12,
					Color(.25, .65, .75, .25),
					.45
				)
		if arriving and foliage != null:
			foliage.impulse(point, 2.4)


func _advance_phase_remnants(delta):
	for index in range(_phase_remnants.size() - 1, -1, -1):
		var remnant = _phase_remnants[index]
		if (
			Globals.options.reduced_flashes
			or get_parent().restoring
			or not get_parent().combat_audio.point_observed(remnant.point, remnant.player)
			or remnant.advance(delta)
		):
			remnant.hide()
			remnant.queue_free()
			_phase_remnants.remove_at(index)
		else:
			remnant.visible = _camera_sees(remnant.point)


func watch_abilities(unit):
	if world_abilities != null:
		world_abilities.watch(unit)
	var callback = _ability_triggered.bind(unit)
	if not unit.abilities.ability_triggered.is_connected(callback):
		unit.abilities.ability_triggered.connect(callback)


func _ability_triggered(ability, point, _target, unit):
	if _headless:
		return
	if ability.id == "frag_grenade":
		grenade_flight(unit.global_position, point, .6, unit.player)
		return
	if ability.id not in ["smoke_screen", "combat_sprint", "siege_anchor"]:
		return
	for index in range(_ability_effects.size() - 1, -1, -1):
		if _ability_effects[index].ability == ability:
			_discard_ability_effect(_ability_effects[index])
			_ability_effects.remove_at(index)
	if ability.id == "siege_anchor" and _can_show(unit):
		# A low metallic clack reuses the spatial combat mixer and its voice budget.
		get_parent().combat_audio.ability(unit, "siege_anchor", point)
		for index in 8:
			var direction = Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 8)
			_puff(
				"dust",
				point + direction * unit.radius,
				direction * .8,
				Color(.55, .49, .39, .45),
				.6
			)
	if not ability.is_active:
		return
	while _ability_effects.size() >= MAX_ABILITY_EFFECTS:
		_discard_ability_effect(_ability_effects.pop_front())
	var lock_visual = _siege_lock(unit) if ability.id == "siege_anchor" else null
	_ability_effects.append(
		{"unit": weakref(unit), "ability": ability, "clock": 1.0, "node": lock_visual}
	)


func grenade_flight(origin: Vector3, point: Vector3, left: float, owner):
	if _headless or left <= 0.0:
		return
	while _grenades.size() >= MAX_GRENADES:
		_grenades.pop_front().node.queue_free()
	var grenade = MeshInstance3D.new()
	grenade.name = "FragGrenade"
	grenade.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var mesh = SphereMesh.new()
	mesh.radius = .09
	mesh.height = .18
	mesh.radial_segments = 8
	mesh.rings = 4
	grenade.mesh = mesh
	grenade.material_override = _glowing_material(Color("e6c58a"))
	grenade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grenade)
	var entry = {
		"node": grenade,
		"owner": owner,
		"origin": origin + Vector3.UP * .9,
		"point": point,
		"age": .6 - clampf(left, 0.0, .6),
		"duration": .6
	}
	_grenades.append(entry)
	_pose_grenade(entry)


func _pose_grenade(entry):
	var progress = minf(1.0, entry.age / entry.duration)
	entry.node.position = grenade_position(entry.origin, entry.point, progress)
	entry.node.visible = (
		not _headless
		and _camera_sees(entry.node.position)
		and get_parent().combat_audio.point_observed(entry.node.position, entry.owner)
	)


func _siege_lock(unit):
	var lock_visual = Node3D.new()
	lock_visual.name = "SiegeAnchorLock"
	add_child(lock_visual)
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color("65747b")
	steel.metallic = .7
	for x in [-1, 1]:
		for z in [-1, 1]:
			var foot = MeshInstance3D.new()
			var mesh = BoxMesh.new()
			mesh.size = Vector3(.45, .14, .35)
			foot.mesh = mesh
			foot.material_override = steel
			foot.position = Vector3(x * unit.radius * .9, .1, z * unit.radius * .7)
			lock_visual.add_child(foot)
	var charge = MeshInstance3D.new()
	charge.name = "AnchorCharge"
	var orb = SphereMesh.new()
	orb.radius = .12
	orb.height = .24
	charge.mesh = orb
	charge.material_override = _glowing_material(RAIL_FIRE)
	lock_visual.add_child(charge)
	return lock_visual


func _discard_ability_effect(entry):
	if is_instance_valid(entry.node):
		entry.node.queue_free()


static func grenade_position(origin: Vector3, point: Vector3, progress: float) -> Vector3:
	var t = clampf(progress, 0.0, 1.0)
	# Constant vertical acceleration, with a lower arc for nearby throws.
	var distance = Vector2(point.x - origin.x, point.z - origin.z).length()
	var lift = clampf(distance * .28, .45, 2.2)
	return origin.lerp(point, t) + Vector3.UP * (4.0 * lift * t * (1.0 - t))


func _advance_grenades(delta):
	for index in range(_grenades.size() - 1, -1, -1):
		var entry = _grenades[index]
		entry.age += delta
		_pose_grenade(entry)
		if entry.age >= entry.duration:
			# GrenadeSystem owns the fuse and emits its impact even if the thrower dies.
			entry.node.queue_free()
			_grenades.remove_at(index)


func _advance_abilities(delta):
	for index in range(_ability_effects.size() - 1, -1, -1):
		var entry = _ability_effects[index]
		var unit = entry.unit.get_ref()
		var ability = entry.ability
		if unit == null or unit.is_queued_for_deletion() or unit.hp <= 0 or not ability.is_active:
			_discard_ability_effect(entry)
			_ability_effects.remove_at(index)
			continue
		var shown = _can_show(unit)
		if is_instance_valid(entry.node):
			entry.node.visible = shown
			entry.node.global_transform = unit.global_transform
			var marker = unit.get_node_or_null("ProjectileOrigin")
			var charge = entry.node.get_node("AnchorCharge")
			charge.visible = not Globals.options.reduced_flashes
			if marker != null:
				charge.global_position = marker.global_position
		entry.clock += delta
		if entry.clock < .10 or not shown:
			continue
		entry.clock = 0.0
		if ability.id == "smoke_screen" and _camera_sees(ability.effect_position):
			# Stop replenishing during the shared particles' final 1.8-second
			# lifetime, so the stationary canopy clears with the seven-second timer.
			var fade = clampf((ability.active_left - 1.8) / .6, 0.0, 1.0)
			if fade <= 0.0:
				continue
			for puff in 14:
				var angle = _random.randf() * TAU
				var radius = sqrt(_random.randf()) * ability.radius * .85
				var offset = Vector3(cos(angle) * radius, .7, sin(angle) * radius)
				_puff(
					"smoke",
					ability.effect_position + offset,
					Vector3.UP * .18,
					Color(.58, .60, .59, .72 * fade),
					3.6
				)
		elif ability.id == "combat_sprint":
			var movement = unit.get_node_or_null("Movement")
			if movement != null and movement.velocity.length_squared() > .1:
				_puff(
					"dust",
					unit.global_position + Vector3.UP * .08,
					-movement.velocity * .2 + Vector3.UP * .2,
					Color(.62, .53, .40, .45),
					.65
				)


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	world_abilities = load("res://source/match/effects/AbilityWorldVisuals.gd").new()
	world_abilities.name = "AbilityWorldVisuals"
	add_child(world_abilities)
	_random.seed = 73819  # Cosmetic randomness never changes the gameplay RNG.
	_tracer_mesh.size = Vector3.ONE
	if get_parent() != null and "map" in get_parent():
		var map = get_parent().map
		if map is Object and map.has_method("height_at"):
			_ground_map = map
			if map.has_method("is_elevated") and not map.is_elevated():
				_ground_map = null
		_dust_biome = load("res://source/match/environment/AtmosphereProfiles.gd").biome(
			get_parent().map
		)
	var signals = get_node_or_null("/root/MatchSignals")
	if signals != null and not signals.tactical_ping.is_connected(_on_tactical_ping):
		signals.tactical_ping.connect(_on_tactical_ping)
	if _headless:
		return
	if get_parent() != null:
		_camera = get_parent().get_node_or_null("IsometricCamera3D")
	foliage = load("res://source/match/effects/FoliageResponse.gd").new()
	add_child(foliage)
	_weapon_heat = load("res://source/match/effects/WeaponHeat.gd").new()
	_weapon_heat.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_weapon_heat)
	aftermath = preload("res://source/match/effects/BattleAftermath.gd").new()
	aftermath.name = "BattleAftermath"
	add_child(aftermath)
	_emitter("flash", 128, 0.075, Vector3.ZERO, 2.4, 0.25)
	_emitter("spark", 768, 0.65, Vector3(0, -9.8, 0), 1.6, 0.1)
	_emitter("smoke", 384, 1.8, Vector3(0.08, 0.16, 0.035), 0.0, 0.95)
	_emitter("dust", 512, 2.1, Vector3(0, -0.15, 0), 0.0, 0.95)
	_emitter("fire", 256, 0.65, Vector3(0, 0.8, 0), 2.0, 0.85)
	_emitter("mote", 192, 1.2, Vector3(0, 0.25, 0), 2.2, 0.2)
	_emitter("foam", 384, 1.8, Vector3(0, -7.5, 0), 0.0, .9)
	_emitter("mist", 192, 1.5, Vector3(.05, -.2, .02), 0.0, .8)
	# Separate bounded buffers keep dense missile trails from starving impact smoke.
	_emitter("trail_smoke", 2048, 1.25, Vector3(.06, .22, .025), 0.0, .72)
	_emitter("exhaust", 768, .1, Vector3.ZERO, 2.8, .38)
	_debris_emitter()
	_debris_emitter("clod", 0.0)
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		var collisions = load("res://source/match/effects/TerrainParticleCollision.gd").new()
		collisions.name = "TerrainParticleCollision"
		add_child(collisions)
		collisions.setup(get_parent().map, _emitters)


func _debris_emitter(kind = "debris", metalness = .45):
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		var fallback = load("res://source/match/effects/ManualParticleBuffer.gd").new()
		fallback.name = "Shards" if kind == "debris" else "SoilClods"
		fallback.setup(
			kind,
			192 if kind == "debris" else 128,
			1.1 if kind == "debris" else .55,
			Vector3(0, -9.8, 0),
			0,
			0,
			metalness
		)
		add_child(fallback)
		_emitters[kind] = fallback
		return
	var particles = GPUParticles3D.new()
	particles.name = "Shards" if kind == "debris" else "SoilClods"
	particles.emitting = false
	particles.amount = 192 if kind == "debris" else 128
	particles.lifetime = 1.1 if kind == "debris" else .55
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
	surface.metallic = metalness
	surface.vertex_color_use_as_albedo = kind == "clod"
	surface.roughness = .7
	mesh.material = surface
	particles.draw_pass_1 = mesh
	add_child(particles)
	_emitters[kind] = particles


func _emitter(kind, amount, lifetime, gravity, glow, roughness):
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		var fallback = load("res://source/match/effects/ManualParticleBuffer.gd").new()
		fallback.name = kind.capitalize()
		fallback.setup(kind, amount, lifetime, gravity, glow, roughness)
		add_child(fallback)
		_emitters[kind] = fallback
		return
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
	var growth_start = .35 if kind in ["smoke", "dust", "foam", "mist"] else 1.0
	var growth_end = (
		1.15 if kind in ["smoke", "foam", "mist"] else (1.65 if kind in ["dust", "flash"] else .35)
	)
	if kind == "trail_smoke":
		growth_start = .85
		growth_end = 2.8
	material.set_shader_parameter("growth_start", growth_start)
	material.set_shader_parameter("growth_end", growth_end)
	material.set_shader_parameter("damping", 1.1 if kind == "dust" else 0.45)
	material.set_shader_parameter("grounded", kind in ["dust", "spark"])
	material.set_shader_parameter("directional", kind in ["dust", "exhaust", "spark"])
	material.set_shader_parameter(
		"billow", kind in ["smoke", "dust", "trail_smoke", "foam", "mist"]
	)
	material.set_shader_parameter(
		"fade_in", .06 if kind == "smoke" else (.025 if kind in ["dust", "trail_smoke"] else 0.0)
	)
	particles.process_material = material
	var mesh = QuadMesh.new()
	mesh.size = Vector2.ONE
	var shader = ShaderMaterial.new()
	shader.shader = load("res://source/shaders/3d/combat_particle.gdshader")

	shader.set_shader_parameter("flame", kind == "fire")
	shader.set_shader_parameter("exhaust", kind == "exhaust")
	shader.set_shader_parameter("vapor", kind in ["smoke", "dust", "trail_smoke", "foam", "mist"])
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
		or not _emitters.has(kind)
		or not is_instance_valid(_emitters[kind])
	):
		return
	var transform_here = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), point)
	# Only grounded sparks and dust sample terrain; smoke, fire and trails do
	# not read the ground custom value in their processor.
	var ground = _ground_height(point) if kind in ["dust", "spark"] else 0.0
	_emitters[kind].emit_particle(
		transform_here, velocity, color, Color(ground, 0, 0, 0), 1 | 2 | 4 | 8 | 16
	)


func _ground_height(point):
	return _ground_map.height_at(Vector2(point.x, point.z)) if _ground_map != null else 0.0


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
	var secondary = weapon.get("beam_role", "primary") in ["link", "refraction"]
	if not secondary:
		get_parent().combat_audio.shot(unit, origin, weapon)
	shots_emitted += 1
	if not _can_show(unit):
		return
	var color = FACTION_FIRE.get(unit.player.faction, FACTION_FIRE.bastion)
	var rail = (
		weapon.get("kind", "") == "rail"
		or (weapon.is_empty() and unit.type == "AdvancedTank" and unit.player.faction != "frontier")
	)
	var appearance = BeamAppearance.for_weapon(unit.player.faction, unit.type, weapon)
	var prism = rail and appearance.prism
	if rail:
		color = appearance.color
	var heavy = not secondary and unit.type in ["Tank", "AdvancedTank", "AntiGroundTurret"]
	var cannon = heavy and not rail and not missile and weapon.get("kind", "shell") == "shell"
	if heavy and not rail:
		if cannon:
			_muzzle_shockwave(origin, origin.direction_to(target_point))
		if foliage != null and _camera_sees(origin):
			foliage.impulse(origin, 6.0)
		if _weapon_heat != null and not missile and _camera_sees(origin):
			_weapon_heat.shot(unit)
		if aftermath != null and not missile and _camera_sees(origin):
			aftermath.casing(origin + unit.global_basis.z * .55, unit.global_basis.x)
		var ground = Vector3(origin.x, _ground_height(origin) + .1, origin.z)
		if origin.y - ground.y < 3.0:
			var unit_radius: float = (
				unit.radius if "radius" in unit and unit.radius != null else 1.0
			)
			for side in [-1, 1]:
				_puff(
					"dust",
					ground + unit.global_basis.x * side * .45,
					unit.global_basis.x * side * 1.3 + Vector3.UP * .15,
					dust_color(_dust_biome),
					unit_radius * .65
				)
	if not rail and _camera_sees(origin):
		aftermath.flash(origin, .5 if heavy else .18, color, true)
	var direction = origin.direction_to(target_point)
	if not rail:
		if cannon:
			_cannon_gas(origin, direction, color)
		else:
			_puff("flash", origin, direction * 0.2, color, 0.65 if heavy else 0.3)
		for _index in range(5 if heavy else 2):
			_puff(
				"spark",
				origin,
				direction * _random.randf_range(2.0, 5.0) + _jitter(0.5),
				color,
				0.12
			)
		if heavy:
			_puff(
				"smoke",
				origin,
				direction * 0.8 + Vector3.UP * 0.2,
				Color(0.48, 0.46, 0.41, 0.2),
				0.55
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
	entry.duration = appearance.duration if rail else maxf(0.05, duration)
	entry.age = 0.0
	entry.missile = missile
	entry.rail = rail
	entry.prism = prism
	entry.width = appearance.width if rail else (.045 if heavy or missile else .018)
	entry.power = appearance.power
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
		entry.beam_material.set_shader_parameter("core_color", appearance.core)
		entry.beam_material.set_shader_parameter("is_prism", prism)
		entry.beam_material.set_shader_parameter("beam_role", appearance.role)
		entry.beam_material.set_shader_parameter("scroll_speed", 4.0 if prism else 9.0)
		if not secondary:
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
	aftermath.flash(point, .4 if prism else .7, color, true)
	_puff("flash", point, Vector3.ZERO, color.lerp(Color.WHITE, .4), .45 if prism else .8)
	for index in 8:
		var ion_color = color
		if prism:
			ion_color = [Color("72eaff"), PRISM_FIRE, Color("ff72d8")][index % 3]
		var velocity = direction * _random.randf_range(1.0, 4.0) + _jitter(1.8)
		_puff("spark", point, velocity, ion_color, .07)
		if index < 3:
			_puff("mote", point, velocity * .25, ion_color, .12)


func shield_impact(unit, point):
	shield_impacts_emitted += 1
	if not _can_show(unit) or not _camera_sees(point) or Globals.options.reduced_flashes:
		return
	_add_shield_visual(unit, point, ShieldImpactVisual.Mode.CONTACT)
	# The wave stays on the shield surface; the hull is not lit like damaged armor.
	var cyan = Color(.35, .78, 1.0, .65)
	_puff("flash", point, Vector3.ZERO, cyan, .18)


func _shield_lifecycle(reference: WeakRef, mode):
	var unit = reference.get_ref()
	if (
		not _can_show(unit)
		or not _camera_sees(unit.global_position)
		or Globals.options.reduced_flashes
	):
		return
	_add_shield_visual(unit, unit.global_position, mode)
	if mode == ShieldImpactVisual.Mode.BREAK:
		for index in 12:
			var direction = Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 12.0)
			_puff(
				"spark",
				unit.global_position + Vector3.UP * .7 + direction * unit.radius,
				direction * 2.2 + Vector3.UP * .8,
				Color("78e5ff"),
				.065
			)


func _add_shield_visual(unit, point, mode):
	while _shield_ripples.size() >= MAX_SHIELD_RIPPLES:
		var old = _shield_ripples.pop_front()
		old.hide()
		old.queue_free()
	var ripple = ShieldImpactVisual.new()
	add_child(ripple)
	ripple.setup(unit, point, mode)
	_shield_ripples.append(ripple)


func _advance_shield_ripples(delta):
	for index in range(_shield_ripples.size() - 1, -1, -1):
		var ripple = _shield_ripples[index]
		var unit = ripple.target.get_ref()
		if (
			Globals.options.reduced_flashes
			or not is_instance_valid(unit)
			or unit.is_queued_for_deletion()
			or unit.hp <= 0
			or not unit.is_visible_in_tree()
			or get_parent().restoring
			or not get_parent().combat_audio._observed(unit)
			or (
				ripple.mode == ShieldImpactVisual.Mode.RECHARGE
				and not unit.shield_component._recharging
			)
			or ripple.advance(delta)
		):
			ripple.hide()
			ripple.queue_free()
			_shield_ripples.remove_at(index)
		else:
			ripple.visible = _camera_sees(ripple.global_position)


func impact(unit, source, point, weapon = {}):
	get_parent().combat_audio.impact(unit, source, point, weapon)
	impacts_emitted += 1
	if not _can_show(unit):
		return
	_material_hit(unit)
	var heavy = get_parent().combat_audio.heavy_impact(source, weapon)
	if not heavy or not explosive_impact(source, weapon):
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
	if heavy:
		_explosion(point, 0.75, ground)
		return
	_water_impact(point, .25)
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
	if not can_show_point(point):
		return
	_explosion(point, clampf(radius * 0.7, 1.0, 2.2), ground, true)


func grenade_impact(point: Vector3, radius: float, owner):
	if not can_show_point(point) or not get_parent().combat_audio.point_observed(point, owner):
		return
	# Fragmentation is a tight pressure snap and low dirt fan, not a fuel blast.
	var strength = clampf(radius * .35, .55, 1.1)
	_water_impact(point, strength)
	_puff("flash", point + Vector3.UP * .12, Vector3.ZERO, Color("ffe8b9"), strength * .8)
	for index in 12:
		var angle = index * TAU / 12.0 + _random.randf_range(-.12, .12)
		var outward = Vector3(cos(angle), 0, sin(angle))
		_puff(
			"spark",
			point + Vector3.UP * .12,
			outward * _random.randf_range(3.5, 6.0) + Vector3.UP * _random.randf_range(.4, 2.0),
			Color("f7cc8b"),
			.035
		)
		if index % 2 == 0:
			_puff(
				"dust",
				point + outward * .15 + Vector3.UP * .08,
				outward * _random.randf_range(1.2, 2.4) + Vector3.UP * .2,
				dust_color(_dust_biome),
				strength * .8
			)
	_shockwave(point, .9)
	aftermath.scar(Vector3(point.x, 0, point.z), strength * .6)
	aftermath.flash(point + Vector3.UP * .2, .25, Color("ffe1a0"), true)
	get_parent().combat_audio.point_impact(point, owner)


# Proximity-fused detonation in the air (flak, missiles).
func airburst(point, strength, color):
	if not can_show_point(point):
		return
	_puff("flash", point, Vector3.ZERO, color, strength * .75)
	for index in 6:
		var outward = _jitter(1.0).normalized()
		_puff("spark", point, outward * 3.5 * strength, Color("ffd9a0"), .04)
		if index < 3:
			_puff(
				"smoke",
				point + outward * .18 * strength,
				outward * .45 + Vector3.UP * .22,
				Color(.24, .25, .27, .36),
				strength * .65
			)


func can_show_construction(unit):
	return _can_show(unit) and (_camera == null or _camera_sees(unit.global_position))


func construction_puff(kind, point, velocity, color, size):
	# Construction sites share the combat pools; callers check can_show_construction.
	_puff(kind, point, velocity, color, size)


func construction_completed(unit, bounds = AABB()):
	if not can_show_construction(unit):
		return
	get_parent().combat_audio.construction_completed(unit)
	var faction = unit.player.faction
	var height = maxf(1.0, bounds.end.y)
	for index in 8:
		var direction = Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 8.0)
		var point = unit.global_position + direction * unit.radius * .7
		point.y += height * .65
		if faction == "helix":
			_puff("spark", point, direction * .8 + Vector3.UP * 1.8, Color("91eaff"), .06)
			if not Globals.options.reduced_flashes:
				_puff("mote", point, Vector3.UP * .7, Color(.3, .85, 1, .65), .12)
		else:
			var steam = (
				Color(.8, .84, .82, .45) if faction == "bastion" else Color(.65, .62, .53, .3)
			)
			_puff("smoke", point, direction * 1.0 + Vector3.UP * 1.5, steam, .9)
			if faction == "frontier" and index % 2 == 0:
				_puff("spark", point, direction + Vector3.UP * 2.0, Color("ffb857"), .07)
	if faction == "helix" and not Globals.options.reduced_flashes:
		_add_shield_visual(unit, unit.global_position, ShieldImpactVisual.Mode.RESTORED)


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
		and unit.is_visible_in_tree()
		and not get_tree().paused
		and not get_parent().restoring
		and get_parent().combat_audio._observed(unit)
	)


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
	if not can_show_point(point):
		return
	var water_level = _water_surface(point)
	if is_finite(water_level):
		point.y = water_level + .08
		_water_impact(point, strength)
		_water_geyser(point, strength)
		return
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
	# A bounded cosmetic tail lets ignition precede the slower buoyant smoke.
	if _blast_tails.size() >= MAX_BLAST_TAILS:
		_blast_tails.pop_front()
	_blast_tails.append(
		{"point": point, "strength": strength, "age": 0.0, "stage": 0, "destructive": destructive}
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
				dust_color(_dust_biome),
				strength * _random.randf_range(0.8, 1.5)
			)
	if destructive:
		aftermath.burst(point, strength, ground_hit)
	elif ground_hit:
		aftermath.scar(Vector3(point.x, 0, point.z), strength * .7)


func _advance_blast_tails(delta):
	for index in range(_blast_tails.size() - 1, -1, -1):
		var entry = _blast_tails[index]
		entry.age += delta
		# Do not replay stale plumes after a long suspended/minimized frame.
		if entry.age > .6 or not can_show_point(entry.point):
			_blast_tails.remove_at(index)
			continue
		while entry.stage < 2 and entry.age >= [.09, .24][entry.stage]:
			var late = entry.stage == 1
			var count = 2 if entry.destructive else 1
			for puff in count:
				var offset = _jitter(entry.strength * .16)
				offset.y = absf(offset.y) + (.3 if late else .1)
				_puff(
					"smoke",
					entry.point + offset,
					Vector3(offset.x * .5, .85 if late else .6, offset.z * .5),
					Color(.26, .25, .24, .28 if late else .38),
					entry.strength * (.9 if late else .65)
				)
			entry.stage += 1
		if entry.stage == 2:
			_blast_tails.remove_at(index)


func destruction(unit):
	get_parent().combat_audio.destruction(unit)
	deaths_emitted += 1
	if not _can_show(unit):
		return
	var point = unit.global_position + Vector3.UP * 0.35
	var infantry = InfantryRoster.is_infantry(unit.type)
	var size = clampf(unit.radius, 0.5, 2.0)
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
	# Structures retain a persistent, interactable ruin with its own collapse.
	if unit.type not in InfantryRoster.STRUCTURES:
		_wreck(unit, infantry)


func structural_failure(ruin, settled: bool):
	if _headless or not _can_show(ruin):
		return
	var point = ruin.global_position
	var color = FACTION_FIRE.get(ruin.source_faction, Color("ffd9a0"))
	for index in 12:
		var direction = Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 12.0)
		_puff(
			"dust",
			point + direction * ruin.radius * .6,
			direction * (2.5 if settled else 1.2) + Vector3.UP * .5,
			Color(.48, .43, .36, .5),
			ruin.radius * (.9 if settled else .45)
		)
		if not settled and index % 2 == 0:
			_puff(
				"spark",
				point + Vector3.UP * .7,
				direction * 2.0 + Vector3.UP * 2.0,
				color,
				ruin.radius * .3
			)
			_puff(
				"fire",
				point + direction * ruin.radius * .5,
				Vector3.UP * .6,
				color,
				ruin.radius * .4
			)
	if settled and aftermath != null:
		aftermath.scar(point, ruin.radius * 1.2)


func ruin_smoke(ruin):
	if _headless or not _can_show(ruin):
		return
	var color = Color(.16, .16, .15, .3)
	if ruin.source_faction == "helix":
		color = Color(.14, .35, .39, .22)
	_puff(
		"smoke",
		ruin.global_position + Vector3.UP * .5,
		Vector3(.1, .65, .04),
		color,
		ruin.radius * .7
	)


func obstacle_destruction(obstacle):
	deaths_emitted += 1
	if not _can_show(obstacle):
		return
	var point = obstacle.global_position + Vector3.UP * 0.35
	var size = clampf(obstacle.radius, 0.5, 2.0)
	for index in 16:
		var angle = index * TAU / 16.0 + _random.randf_range(-0.15, 0.15)
		var velocity = Vector3(cos(angle), _random.randf_range(0.6, 2.0), sin(angle))
		_puff("dust", point, velocity * size * 2.0, Color("9d927d"), size * 0.5)
		if index % 2 == 0:
			_puff("spark", point, velocity * size * 3.0, Color("ded2ae"), size * 0.3)
	aftermath.burst(point, size, true)


static func dust_color(biome: String) -> Color:
	match biome:
		"alpine":
			return Color(.82, .88, .93, .24)
		"desert":
			return Color(.6, .49, .33, .2)
		"urban":
			return Color(.42, .43, .43, .15)
		_:
			return Color(.28, .25, .18, .22)


func movement_dust(unit):
	if not _can_show(unit) or not _camera_sees(unit.global_position):
		return
	var map = get_parent().map
	var point: Vector3 = unit.global_position
	# Existing water simulation owns wakes and splashes; never blow dry dust over it.
	if "water_flow" in map and map.water_flow != null:
		if map.water_flow.sample(Vector2(point.x, point.z)).a > .1:
			return
	var movement = unit.get_node_or_null("Movement")
	var velocity: Vector3 = movement.velocity if movement != null else -unit.global_basis.z
	if GroundContact.is_hover(unit):
		_repulsor_wash(unit, velocity)
		return
	var backward := -velocity.normalized()
	# These facts cannot change while this synchronous emission is assembled.
	var radius = unit.radius
	var right: Vector3 = unit.global_basis.x
	var contact_base = point + backward * radius * .65
	var size = radius * (.7 if _dust_biome == "alpine" else .9)
	var color = dust_color(_dust_biome)
	var clods = (
		_dust_biome in ["temperate", "coastal"] and radius > .65 and velocity.length_squared() > 2.0
	)
	for side in [-1, 1]:
		var contact = contact_base + right * side * radius * .55
		contact.y = _ground_height(contact) + .1
		_puff("dust", contact, backward * .55 + Vector3.UP * .16, color, size)
		if clods:
			_puff("clod", contact, backward * 1.2 + Vector3.UP * .8, Color(.4, .32, .22), .65)


func _repulsor_wash(unit, velocity: Vector3):
	var point: Vector3 = unit.global_position
	var color = dust_color(_dust_biome)
	color.a *= .55
	for index in 8:
		var radial = Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 8.0)
		var contact = point + radial * unit.radius * .85
		contact.y = _ground_height(contact) + .1
		_puff(
			"dust",
			contact,
			radial * 1.4 - velocity * .08 + Vector3.UP * .24,
			color,
			clampf(unit.radius * .7, .35, 1.0)
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
	var death = unit.get_node("BastionVisuals").death_motion()
	if infantry and death.get("lift", 0.0) > 0.0 and aftermath != null:
		var weapon = wreck.find_child("WeaponCarry", true, false)
		if weapon != null:
			aftermath.detach_weapon(weapon, death.slide.normalized() * 1.3 + Vector3.UP * 2.2)
	var turret_node = (
		wreck.find_child("*TurretPivot*", true, false)
		if not infantry and unit.type in ["Tank", "AdvancedTank"]
		else null
	)
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
				"secondary_time": _random.randf_range(1.2, 2.6),
				"turret": turret_node,
				"size": clampf(unit.radius, 0.5, 2.0),
				"infantry": infantry,
				"origin": wreck.position,
				"rotation": wreck.rotation,
				"motion": death,
				"failure_part": _failure_part(wreck) if not infantry else {},
				"momentum": _crash_momentum(unit),
			}
		)
	)


func _material_hit(unit, color = Color("ffd6a1")):
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
	var entry = ObjectMaterials.hit_flash(geometry, color, recycled)
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


func _muzzle_shockwave(point: Vector3, direction: Vector3):
	if _headless or Globals.options.reduced_flashes or not _camera_sees(point):
		return
	while _shockwaves.size() >= MAX_SHOCKWAVES:
		var old = _shockwaves.pop_front().node
		old.hide()
		old.queue_free()
	var ring = create_muzzle_wave()
	add_child(ring)
	var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > .95 else Vector3.UP
	ring.global_transform = Transform3D(Basis.looking_at(direction, up), point + direction * .05)
	_shockwaves.append({"node": ring, "age": 0.0, "duration": .18})


func _cannon_gas(point: Vector3, direction: Vector3, color: Color):
	_puff("flash", point, direction * .2, color, .32)
	# Overlapping, tapered jets push out along the bore and cool within 0.1 s.
	for index in 3:
		_puff(
			"exhaust",
			point + direction * (.05 + index * .16),
			direction * (3.2 + index * .6),
			color,
			.22 - index * .05
		)


static func create_muzzle_wave():
	var ring := MeshInstance3D.new()
	ring.name = "CannonMuzzleShockwave"
	ring.mesh = QuadMesh.new()
	ring.mesh.size = Vector2.ONE * 2.4
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = (
		MUZZLE_FALLBACK
		if RenderingServer.get_current_rendering_method() == "gl_compatibility"
		else MUZZLE_SHADER
	)
	ring.material_override = material
	return ring


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
		var duration: float = entry.get("duration", SHOCKWAVE_DURATION)
		if entry.age >= duration or Globals.options.reduced_flashes:
			entry.node.queue_free()
			_shockwaves.remove_at(index)
		else:
			entry.node.material_override.set_shader_parameter("progress", entry.age / duration)


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
	if movement == null:
		return Vector3.ZERO
	if unit.movement_domain != 0:
		return movement.velocity * Vector3(1, 0, 1) * .18
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
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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


func _process(delta):
	_advance_phase_remnants(0.0 if get_tree().paused else delta)
	if world_abilities != null and not _headless:
		world_abilities.advance(0.0 if get_tree().paused else delta)
	# Cosmetic lifetimes use render-frame updates to avoid 60 Hz stepping
	# on fast displays, while the explicit age clock still respects tactical pause.
	if not get_tree().paused:
		_advance_tracers(delta)
		_advance_grenades(delta)
		_advance_hit_flashes(delta)
		_advance_blast_tails(delta)
	_advance_shield_ripples(0.0 if get_tree().paused else delta)
	# A loaded, paused throw retains its exact warning pose without advancing the fuse.
	if get_tree().paused:
		for entry in _grenades:
			_pose_grenade(entry)
	# Settings can change while the battle is paused; remove frozen flashes then too.
	if Globals.options.reduced_flashes:
		if _weapon_heat != null:
			_weapon_heat._process(0.0)
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
	_advance_abilities(delta)
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
			"intensity", .65 if Globals.options.reduced_flashes else entry.power
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
		if (
			not entry.infantry
			and not entry.secondary
			and entry.age > entry.get("secondary_time", 1.6)
		):
			entry.secondary = true
			if not can_show_point(entry.node.global_position):
				continue
			if is_instance_valid(entry.get("turret")) and not Globals.options.reduced_flashes:
				_launch_turret_cook_off(entry.turret, entry.size)
			for side in [-1, 1]:
				_puff(
					"fire",
					entry.node.position + Vector3.UP * .6,
					Vector3(side * 1.8, 2.2, 0),
					Color(1, .45, .1, .6),
					entry.size * .45
				)
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
	var ground = (
		_ground_height(entry.node.position) + .02 if motion.mobile else entry.origin.y - .18
	)
	entry.node.position.y = lerpf(entry.origin.y, ground, settle)
	entry.node.position.y += sin(progress * PI) * motion.get("lift", 0.0)
	var failure = entry.get("failure_part", {})
	if not failure.is_empty() and is_instance_valid(failure.node):
		var collapse = smoothstep(.12, .7, progress)
		failure.node.transform = failure.rest
		if failure.track:
			failure.node.position += Vector3(failure.side * .14, -.06, .05) * collapse
			failure.node.rotation.z += failure.side * .12 * collapse
		else:
			failure.node.rotation.x += .65 * collapse
	if progress >= 1.0 and not entry.has("gouged"):
		entry.gouged = true
		var slide: Vector3 = entry.node.position - entry.origin
		if (
			not motion.get("infantry", false)
			and motion.mobile
			and slide.length() > .25
			and aftermath != null
		):
			for fraction in [.25, .6, 1.0]:
				aftermath.scar(entry.origin.lerp(entry.node.position, fraction), entry.size * .55)
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


func vehicle_damage(unit, band: int, point: Vector3):
	if band <= 0 or unit.hp <= 0 or not _can_show(unit) or not _camera_sees(point):
		return
	var size = clampf(unit.radius * .8, .5, .95)
	point += Vector3.UP * .2
	match unit.player.faction:
		"helix":
			_puff("smoke", point, Vector3(.08, .45, .06), Color(.1, .8, .95, .6), size * .65)
			_puff("spark", point, Vector3(.2, .4, .1), Color(.25, .9, 1, .7), .035)
			if band == 2 and not Globals.options.reduced_flashes:
				for index in 3:
					_puff("spark", point + _jitter(.15), _jitter(1.2), Color(.5, .95, 1), .045)
		"frontier":
			_puff("smoke", point, Vector3(.07, .65, .05), Color(.83, .87, .84, .65), size)
		_:
			_puff("smoke", point, Vector3(.12, .65, .04), Color(.09, .1, .09, .7), size)
			if band == 2:
				_puff("fire", point, Vector3.UP * .3, Color(1, .4, .1, .6), size * .7)
				_puff("spark", point, _jitter(.6) + Vector3.UP * .5, Color(1, .65, .2), .035)


func vehicle_backfire(unit, point: Vector3) -> bool:
	if unit.player.faction != "frontier" or unit.hp <= 0 or not can_show_construction(unit):
		return false
	var exhaust = unit.global_basis.z * .8 + Vector3.UP * .3
	_puff("smoke", point, exhaust * .5, Color(.12, .11, .1, .55), .4)
	_puff("flash", point, exhaust, Color(1, .22, .055, .75), .23)
	for index in 3:
		_puff("spark", point, exhaust + _jitter(.5), Color(1, .38, .08), .045)
	get_parent().combat_audio.vehicle_backfire(unit, point)
	return true


func _exit_tree():
	var signals = get_node_or_null("/root/MatchSignals")
	if signals != null and signals.tactical_ping.is_connected(_on_tactical_ping):
		signals.tactical_ping.disconnect(_on_tactical_ping)
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
	torus.inner_radius = 0.94
	torus.outer_radius = 1.0
	ring.mesh = torus
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.78, 0.15, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = 10
	ring.material_override = mat
	add_child(ring)
	ring.global_position = point + Vector3.UP * 0.05
	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector3(2.0, 1.0, 2.0), 0.85)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.85)
	tween.tween_callback(ring.queue_free)


func _water_impact(point: Vector3, strength: float):
	var atmosphere = get_parent().get_node_or_null("WorldAtmosphere")
	if atmosphere != null and atmosphere.effects != null:
		atmosphere.effects.water_interactions.impact(point, strength)


func _water_surface(point: Vector3) -> float:
	var map = get_parent().map
	if not "water_flow" in map or map.water_flow == null:
		return -INF
	var flat = Vector2(point.x, point.z)
	if map.water_flow.sample(flat).a <= .1:
		return -INF
	var level = map.water_flow.level_at(flat)
	return level if absf(point.y - level) < 1.6 else -INF


func _water_geyser(point: Vector3, strength: float):
	if not can_show_point(point) or not get_parent().combat_audio.point_observed(point):
		return
	var force = sqrt(clampf(strength, .5, 2.2))
	# A narrow fast core, slower frothy shoulders, then a low collapsing mist skirt.
	# Gravity is shared by GPU and Compatibility particle buffers.
	for index in 24:
		var radial = Vector3.RIGHT.rotated(Vector3.UP, index * TAU / 24.0)
		var core = index < 8
		var velocity = radial * (.4 if core else 1.7) * force
		velocity.y = (8.0 if core else 4.8) * force + _random.randf_range(-.5, .5)
		_puff(
			"foam",
			point + radial * .2,
			velocity,
			Color(.85, .94, .97, .85),
			(.75 if core else .6) * force
		)
		if index % 3 == 0:
			_puff(
				"mist",
				point + radial * .5 + Vector3.UP * .3,
				radial * 1.7 * force + Vector3.DOWN * .12,
				Color(.8, .9, .94, .3),
				1.2 * force
			)


func rotor_downwash(unit):
	if foliage == null or not _can_show(unit) or not _camera_sees(unit.global_position):
		return
	var point: Vector3 = unit.global_position
	var ground = _ground_height(point)
	var height = maxf(0.0, point.y - ground)
	var strength = 1.0 - smoothstep(.8, 5.0, height)
	if strength <= 0.0:
		return
	point.y = ground
	foliage.impulse(point, 4.0 * strength)
	var color = dust_color(_dust_biome)
	color.a *= strength * 1.3
	var phase = _random.randf() * TAU
	for index in 5:
		var angle = phase + index * TAU / 5.0 + _random.randf_range(-.16, .16)
		var outward = Vector3(cos(angle), 0, sin(angle))
		var offset = outward * unit.radius * (.55 + height * .1)
		var origin = point + offset
		origin.y = _ground_height(origin) + .07
		_puff(
			"dust",
			origin,
			outward * _random.randf_range(1.2, 2.4) * strength + Vector3.UP * .16,
			color,
			unit.radius * _random.randf_range(.4, .6)
		)


# Fixed-wing flight presentation: jet exhaust trails, afterburner flames, wingtip
# vortex vapor on high-bank turns, takeoff runway dust and landing rollout touchdown smoke.
func aircraft_flight_effects(unit, flight):
	if not _can_show(unit) or not _camera_sees(unit.global_position):
		return
	var forward = -unit.global_basis.z
	var basis = unit.global_basis
	var faction = unit.player.faction if unit.player != null else "bastion"
	var flame_color = FACTION_FIRE.get(faction, FACTION_FIRE.bastion)
	var smoke_color = Color(0.55, 0.54, 0.52, 0.42)
	if faction == "helix":
		flame_color = Color(0.45, 0.88, 1.0, 0.95)
		smoke_color = Color(0.68, 0.82, 0.92, 0.35)
	elif faction == "frontier":
		flame_color = Color(1.0, 0.52, 0.16, 0.95)
		smoke_color = Color(0.42, 0.41, 0.40, 0.5)

	var is_airborne = flight.is_airborne()
	var is_takeoff = flight.phase == flight.Phase.TAKEOFF
	var is_rollout = flight.phase == flight.Phase.ROLLOUT

	if is_airborne or is_takeoff:
		var speed_ratio = clampf(flight.airspeed / maxf(flight.cruise_speed, 1.0), 0.5, 1.5)
		var tail_offset = basis * Vector3(0, 0.12, unit.radius * 0.75)
		var nozzle_center = unit.global_position + tail_offset
		_puff(
			"exhaust",
			nozzle_center,
			-forward * (2.8 * speed_ratio),
			flame_color,
			0.24 * speed_ratio
		)
		_puff(
			"trail_smoke",
			nozzle_center - forward * 0.18 + _jitter(0.03),
			-forward * (0.4 * speed_ratio) + Vector3.UP * 0.08 + _jitter(0.04),
			smoke_color,
			_random.randf_range(0.42, 0.56)
		)

		if is_airborne and absf(flight.bank) > 0.28:
			var bank_strength = clampf(
				(absf(flight.bank) - 0.28) / (flight.max_bank - 0.28), 0.2, 1.0
			)
			var wing_span = unit.radius * 1.05
			for side in [-1.0, 1.0]:
				var wingtip = unit.global_position + basis * Vector3(side * wing_span, 0.05, 0.1)
				_puff(
					"trail_smoke",
					wingtip,
					-forward * 0.3 + Vector3.UP * 0.05,
					Color(0.95, 0.97, 1.0, 0.28 * bank_strength),
					0.22 * bank_strength
				)

		if is_takeoff and flight.height_above_ground() < 1.0:
			var ground_point = unit.global_position + tail_offset
			ground_point.y = _ground_height(ground_point) + 0.06
			_puff(
				"dust",
				ground_point,
				-forward * 1.6 + Vector3.UP * 0.25 + _jitter(0.15),
				dust_color(_dust_biome),
				0.45
			)

	elif is_rollout:
		var ground_point = unit.global_position
		ground_point.y = _ground_height(ground_point) + 0.05
		_puff(
			"smoke",
			ground_point + _jitter(0.05),
			Vector3.UP * 0.4 + -forward * 0.3,
			Color(0.82, 0.82, 0.80, 0.55),
			0.38
		)


func _failure_part(wreck) -> Dictionary:
	var parts = wreck.find_children("*TrackPivot*", "Node3D", true, false)
	var track = not parts.is_empty()
	if parts.is_empty():
		parts = wreck.find_children("*KneePivot*", "Node3D", true, false)
	if parts.is_empty():
		return {}
	var node = parts[_random.randi_range(0, parts.size() - 1)]
	return {
		"node": node,
		"rest": node.transform,
		"track": track,
		"side": -1.0 if "Left" in node.name else 1.0
	}


func deployment_dust(unit):
	if not _can_show(unit):
		return
	for x in [-1, 1]:
		for z in [-1, 1]:
			var point = (
				unit.global_position
				+ unit.global_basis * Vector3(x * unit.radius * .65, 0, z * unit.radius * .55)
			)
			point.y = _ground_height(point) + .08
			_puff("dust", point, Vector3(x * .2, .1, z * .2), dust_color(_dust_biome), .35)
