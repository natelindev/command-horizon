extends SceneTree

const HEALTH_BAR_SCENE = preload("res://source/match/units/traits/HealthBar.tscn")
var errors = []
var options
var effects_script


class Side:
	extends Node3D
	var faction = "bastion"
	var color = Color("78c8ee")


class Subject:
	extends Node3D
	signal selected
	signal deselected
	signal hp_changed
	var hp = 100.0
	var hp_max = 100.0
	var attack_range = null
	var type = "Fighter"
	var aim_target = null
	var player:
		get:
			return get_parent()


class Ground:
	extends RefCounted

	func height_at(_point):
		return 0.0


class Stage:
	extends Node3D
	var map = Ground.new()
	var restoring = false
	var combat_audio = SilentAudio.new()


class SilentAudio:
	extends RefCounted

	func shot(_unit, _origin, _weapon):
		pass

	func _observed(_unit):
		return true


class TrackedHealthBar:
	extends "res://source/match/units/traits/HealthBar.gd"
	var uploads = 0

	func _upload_bar():
		uploads += 1
		super()


func _initialize():
	_run.call_deferred()


func _run():
	effects_script = load("res://source/match/effects/CombatEffects.gd")
	options = root.get_node("Globals").options
	var original_reduced = options.reduced_flashes
	options.reduced_flashes = false
	_health_chunks()
	_subpixel_health()
	_selection_designs()
	_effect_budgets()
	_beam_lifecycle()
	_impact_families()
	await _particle_material_lifetime()
	options.reduced_flashes = original_reduced
	for message in errors:
		push_error(message)
	print("Combat presentation: %d failures" % errors.size())
	await process_frame
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _check(ok, message):
	if not ok:
		errors.append(message)


func _particle_material_lifetime():
	for effect in ["SparklingAnimation", "ResourceDecayAnimation"]:
		await _particle_scene_lifetime(effect)


func _particle_scene_lifetime(effect):
	# Keep the scene loaded while its process material is fully released, so GPU
	# resource lifetime is governed by the runtime cache rather than script preloads.
	var scene = load("res://source/match/utils/%s.tscn" % effect)
	var first = scene.instantiate()
	var second = scene.instantiate()
	root.add_child(first)
	root.add_child(second)
	await physics_frame
	await process_frame
	var first_particles = first.get_node("GPUParticles3D")
	var second_particles = second.get_node("GPUParticles3D")
	_check(first_particles.emitting and second_particles.emitting, effect + " did not start")
	_check(
		first_particles.process_material == second_particles.process_material,
		effect + " allocated separate particle materials"
	)
	var material = weakref(first_particles.process_material)
	first.queue_free()
	second.queue_free()
	await process_frame
	await process_frame
	root.get_node("Globals").cache.erase("unit_particle_materials")
	_check(material.get_ref() == null, effect + " retained its retired GPU material")
	var restarted = scene.instantiate()
	root.add_child(restarted)
	await physics_frame
	await process_frame
	_check(
		restarted.get_node("GPUParticles3D").emitting,
		effect + " did not rebuild after runtime cache cleanup"
	)
	restarted.queue_free()
	await process_frame
	await process_frame
	root.get_node("Globals").cache.erase("unit_particle_materials")


func _subject(side):
	var unit = Subject.new()
	side.add_child(unit)
	var geometry = Node3D.new()
	geometry.name = "Geometry"
	unit.add_child(geometry)
	var hull = MeshInstance3D.new()
	hull.mesh = BoxMesh.new()
	hull.mesh.material = StandardMaterial3D.new()
	geometry.add_child(hull)
	return unit


func _health_chunks():
	var side = Side.new()
	root.add_child(side)
	var unit = _subject(side)
	var bar = HEALTH_BAR_SCENE.instantiate()
	unit.add_child(bar)
	_check(
		bar._damage_value == 1.0 and not bar.is_processing(), "Full health animates a false chunk"
	)
	unit.hp = 50.0
	unit.hp_changed.emit()
	_check(
		bar._value == .5 and bar._damage_value == 1.0,
		"Damage did not immediately separate HP and lost health"
	)
	_check(
		bar._image.get_pixel(152, 5).is_equal_approx(bar.DAMAGE_CHUNK),
		"Damage chunk was not drawn behind health"
	)
	bar._process(.12)
	_check(bar._damage_value == 1.0, "Damage chunk disappeared before its hold elapsed")
	bar._process(.42)
	_check(
		is_equal_approx(bar._damage_value, .75),
		"Damage chunk decay did not account for remaining hold"
	)
	unit.hp = 25.0
	unit.hp_changed.emit()
	_check(is_equal_approx(bar._damage_value, .75), "Repeated damage discarded the visible loss")
	bar._process(1.0)
	_check(
		bar._damage_value == .25 and not bar.is_processing(),
		"Damage chunk did not settle and stop processing"
	)
	unit.hp = 40.0
	unit.hp_changed.emit()
	_check(
		bar._damage_value == .4 and not bar.is_processing(), "Repair left a false damage segment"
	)
	unit.selected.emit()
	unit.hp = 35.0
	unit.hp_changed.emit()
	_check(
		bar.visible and bar._visibility_timer.is_stopped(),
		"Damage put a selected bar on a hiding timer"
	)
	unit.deselected.emit()
	unit.hp = 30.0
	unit.hp_changed.emit()
	bar._visibility_timer.start(.1)
	unit.hp = 20.0
	unit.hp_changed.emit()
	_check(bar._visibility_timer.time_left > 1.9, "Repeat damage did not refresh bar visibility")
	unit.hide()
	for frame in 60:
		bar._process(1.0 / 60.0)
	unit.show()
	_check(
		bar._image.get_pixel(52, 5).is_equal_approx(bar.MISSING),
		"Fog reveal resurrected an expired damage chunk"
	)
	side.free()


func _subpixel_health():
	var side = Side.new()
	root.add_child(side)
	var unit = _subject(side)
	var bar = HEALTH_BAR_SCENE.instantiate()
	bar.set_script(TrackedHealthBar)
	unit.add_child(bar)
	var initial = bar.uploads
	for hit in 10:
		unit.hp -= .01
		unit.hp_changed.emit()
	_check(bar.uploads == initial, "Subpixel damage uploaded identical health textures")
	_check(not bar.is_processing(), "Invisible subpixel damage started animation processing")
	unit.hp = 99.6
	unit.hp_changed.emit()
	_check(
		bar.uploads == initial + 1 and bar.is_processing(),
		"Pixel-boundary damage did not draw its chunk"
	)
	bar._process(1.0)
	_check(
		bar.uploads == initial + 2 and not bar.is_processing(),
		"Chunk pixel decay did not upload and settle"
	)
	unit.hp = 60.01
	unit.hp_changed.emit()
	bar._process(1.0)
	var before_color_change = bar.uploads
	unit.hp = 60.0
	unit.hp_changed.emit()
	_check(bar.uploads == before_color_change + 1, "Subpixel health color transition was skipped")
	unit.selected.emit()
	_check(
		bar.uploads == before_color_change + 1, "Selecting an unchanged bar uploaded its texture"
	)
	side.free()


func _selection_designs():
	for faction in ["bastion", "helix", "frontier"]:
		var side = Side.new()
		side.faction = faction
		root.add_child(side)
		var unit = _subject(side)
		var footprint = Node3D.new()
		footprint.name = "TeamFootprint"
		unit.add_child(footprint)
		var selection = load("res://source/match/units/traits/Selection.tscn").instantiate()
		unit.add_child(selection)
		selection.select()
		_check(not footprint.visible, "Selected marker overlaps the soft ownership halo")
		var material = selection._circle._plane.material_override
		_check(material.shader == selection.FACTION_SHADER, faction + " retained a plain circle")
		_check(
			material.get_shader_parameter("faction_style") == selection.FACTION_STYLES[faction],
			"Wrong faction selection silhouette"
		)
		_check(
			material.get_shader_parameter("color") == side.color,
			"Faction selection lost ownership color"
		)
		selection._process(.5)
		_check(
			material.get_shader_parameter("animation_time") > 0.0,
			"Selected faction marker is not animated"
		)
		options.reduced_flashes = true
		selection._process(.1)
		_check(
			material.get_shader_parameter("animation_time") == 0.0,
			"Reduced flashes did not steady the marker"
		)
		options.reduced_flashes = false
		selection.deselect()
		_check(footprint.visible, "Deselected unit lost its ownership footprint")
		_check(
			not selection._circle.visible and not selection.is_processing(),
			"Deselected marker kept processing"
		)
		side.free()


func _impact_families():
	var effects = effects_script
	var audio = load("res://source/match/audio/CombatAudio.gd")
	var fighter = Subject.new()
	for kind in ["bullet", "cannon"]:
		var weapon = {"kind": kind}
		_check(
			not audio.heavy_impact(fighter, weapon), "Fighter cannon retained heavy-impact audio"
		)
		_check(
			not effects.explosive_impact(fighter, weapon),
			"Fighter cannon retained explosive impact visuals"
		)
	for kind in ["rocket", "missile", "bomb", "warhead"]:
		var weapon = {"kind": kind}
		_check(
			audio.heavy_impact(fighter, weapon) and effects.explosive_impact(fighter, weapon),
			"Explosive weapon lost matching impact presentation"
		)
	for kind in ["shell", "rail"]:
		var weapon = {"kind": kind}
		_check(
			audio.heavy_impact(fighter, weapon) and not effects.explosive_impact(fighter, weapon),
			"Armor penetration became an explosive fireball"
		)
	fighter.free()


func _effect_budgets():
	var stage = Stage.new()
	root.add_child(stage)
	var effects = effects_script.new()
	stage.add_child(effects)
	effects.set_physics_process(false)
	var side = Side.new()
	stage.add_child(side)
	var first = _subject(side)
	var mesh = first.get_node("Geometry").get_child(0)
	var source_material = mesh.mesh.material
	effects._material_hit(first)
	var overlay = mesh.material_overlay
	_check(
		overlay is ShaderMaterial and mesh.mesh.material == source_material,
		"Hit emission mutated the shared material"
	)
	effects._advance_hit_flashes(.05)
	effects._material_hit(first)
	_check(
		effects._hit_flashes.size() == 1 and effects._hit_flashes[0].age == .05,
		"Automatic fire reset a pulse indefinitely"
	)
	var original_reference = first.get_node("Geometry").get_meta("hit_flash_surfaces")[0]
	effects._advance_hit_flashes(1.0)
	_check(effects._free_hit_flashes.size() == 1, "Expired material pulse was not recycled")
	effects._material_hit(first)
	_check(mesh.material_overlay == overlay, "Repeated damage allocated a fresh hit material")
	_check(
		first.get_node("Geometry").get_meta("hit_flash_surfaces")[0] == original_reference,
		"Repeated damage rebuilt unchanged geometry weak references"
	)
	first.hide()
	effects._advance_hit_flashes(.01)
	_check(
		mesh.material_overlay == null and effects._hit_flashes.is_empty(),
		"Fog-hidden unit retained a hit overlay"
	)
	effects._material_hit(first)
	_check(effects._hit_flashes.is_empty(), "Hidden damage allocated an invisible material pulse")
	first.show()
	# Geometry replacement invalidates stale weak candidates without retaining it.
	mesh.free()
	mesh = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	first.get_node("Geometry").add_child(mesh)
	effects._material_hit(first)
	_check(mesh.material_overlay == overlay, "Replaced geometry did not reuse a valid pooled pulse")
	for index in effects.MAX_HIT_FLASHES + 4:
		effects._material_hit(_subject(side))
	_check(
		effects._hit_flashes.size() == effects.MAX_HIT_FLASHES,
		"Hit emission exceeded its active budget"
	)
	_check(mesh.material_overlay == null, "Evicted hit pulse left a permanent overlay")
	options.reduced_flashes = true
	effects._advance_hit_flashes(.01)
	_check(effects._hit_flashes.is_empty(), "Reduced flashes did not cancel active hit emission")
	effects._material_hit(first)
	_check(effects._hit_flashes.is_empty(), "Reduced flashes spawned a hit emission")
	options.reduced_flashes = false
	effects._material_hit(first)
	first.free()
	effects._advance_hit_flashes(1.0)
	_check(effects._hit_flashes.is_empty(), "Destroyed target retained an active hit entry")
	_check(
		effects._free_hit_flashes.size() == effects.MAX_HIT_FLASHES,
		"Hit material pool grew beyond its active budget"
	)
	# Dummy renderer still exercises creation/expiry; the rendered preview validates pixels.
	effects._headless = false
	for index in effects.MAX_SHOCKWAVES + 3:
		effects._shockwave(Vector3.ZERO, 2.0)
	_check(
		effects._shockwaves.size() == effects.MAX_SHOCKWAVES,
		"Shockwaves exceeded the active budget"
	)
	effects._advance_hit_flashes(1.0)
	_check(effects._shockwaves.is_empty(), "Shockwave did not expire")
	for index in effects.MAX_WRECK_LIGHTS + 2:
		var wreck = Node3D.new()
		stage.add_child(wreck)
		var light = effects._wreck_light(wreck, 1.0)
		effects._wrecks.append(
			{
				"node": wreck,
				"light": light,
				"age": 8.0,
				"infantry": false,
				"fire_clock": 0.0,
				"size": 1.0
			}
		)
	var lights = effects._wrecks.filter(func(entry): return entry.light != null)
	_check(
		lights.size() == effects.MAX_WRECK_LIGHTS, "Persistent fire lights exceeded their budget"
	)
	var entry = effects._wrecks[0]
	effects._headless = true
	effects._advance_wreck_fire(entry, .25)
	_check(entry.light.light_energy > 0.0, "Wreck stopped burning before the persistent interval")
	entry.age = effects.WRECK_BURN_DURATION
	effects._advance_wreck_fire(entry, .25)
	_check(entry.light == null, "Burned-out wreck retained its light")
	options.reduced_flashes = true
	for active in effects._wrecks:
		effects._advance_wreck_fire(active, .01)
	_check(
		effects._wrecks.all(func(active): return active.light == null),
		"Reduced flashes retained wreck flicker"
	)
	options.reduced_flashes = false
	stage.free()


func _beam_lifecycle():
	var stage = Stage.new()
	root.add_child(stage)
	var effects = effects_script.new()
	stage.add_child(effects)
	effects.set_physics_process(false)
	effects.set_process(false)
	# Exercise the real shot path with dummy rendering and bounded GPU emitters.
	effects.aftermath = load("res://source/match/effects/BattleAftermath.gd").new()
	effects.add_child(effects.aftermath)
	for kind in ["flash", "spark", "smoke", "mote"]:
		effects._emitter(kind, 32, .3, Vector3.ZERO, 1.0, .2)
	effects._headless = false
	var side = Side.new()
	stage.add_child(side)
	var unit = _subject(side)
	unit.type = "AdvancedTank"
	var target = _subject(side)
	var origin = Vector3(2, 1, 3)
	var endpoint = Vector3(9, 2, -5)
	effects.shot(unit, origin, endpoint, .16, false, target, true, {"kind": "rail"})
	var rail = effects._tracers[0]
	var material = rail.node.material_override
	_check(rail.node.visible and rail.duration == .24, "Rail did not start a full-duration beam")
	_check(rail.node.mesh is ArrayMesh, "Rail retained box geometry")
	_check(
		(
			(rail.node.transform * Vector3(0, 0, .5)).is_equal_approx(origin)
			and (rail.node.transform * Vector3(0, 0, -.5)).is_equal_approx(endpoint)
		),
		"Rotated beam does not span its muzzle and impact"
	)
	_check(effects.aftermath.lights.size() == 2, "Rail did not flash at both endpoints")
	_check(not material.get_shader_parameter("is_prism"), "Bastion rail acquired Prism dispersion")
	effects._material_hit(target)
	target.position += Vector3(4, 0, 0)
	effects._physics_process(.1)
	_check(effects._tracers.size() == 1 and rail.node.visible, "Rail died at the old 0.075s cutoff")
	_check(
		rail.target == endpoint and rail.target_ref == null, "Instant beam followed a moving target"
	)
	_check(
		is_equal_approx(material.get_shader_parameter("progress"), .1 / .24),
		"Beam dissipation did not follow its age"
	)
	side.faction = "helix"
	effects.shot(unit, origin, endpoint, .16, false, target, true, {"kind": "rail"})
	var prism = effects._tracers[1]
	_check(
		(
			prism.node.material_override != material
			and prism.beam_material.get_shader_parameter("is_prism")
			and prism.width > rail.width
		),
		"Simultaneous Prism and rail beams share lifecycle or styling"
	)
	_check(
		prism.beam_material.get_shader_parameter("progress") == 0.0,
		"New Prism inherited another beam's age"
	)
	paused = true
	options.reduced_flashes = true
	effects._process(0.0)
	_check(material.get_shader_parameter("intensity") == .65, "Paused beam ignored reduced flashes")
	effects._physics_process(.1)
	_check(rail.age == .1 and prism.age == 0.0, "Beam advanced during tactical pause")
	paused = false
	effects._physics_process(.05)
	_check(effects._hit_flashes.is_empty(), "Beam activity prevented hit-flash cleanup")
	_check(
		material.get_shader_parameter("intensity") == .65, "Reduced flashes left a full-power beam"
	)
	options.reduced_flashes = false
	effects._advance_tracers(.2)
	_check(
		(
			effects._tracers.is_empty()
			and effects._free_tracers.size() == 2
			and not rail.node.visible
			and material.get_shader_parameter("progress") == 1.0
		),
		"Expired beams did not finish and return to the pool"
	)
	# Reverse iteration makes the original rail the next free entry.
	effects.shot(unit, origin, endpoint, .16, false, null, true, {"kind": "shell"})
	_check(
		(
			effects._tracers[0].node == rail.node
			and rail.node.mesh is BoxMesh
			and rail.node.material_override is StandardMaterial3D
		),
		"Beam reuse corrupted an ordinary tracer"
	)
	effects._advance_tracers(.2)
	effects.shot(unit, origin, origin + Vector3.UP * 4, .16, false, null, true, {"kind": "rail"})
	_check(
		(
			rail.node.material_override == material
			and material.get_shader_parameter("is_prism")
			and material.get_shader_parameter("progress") == 0.0
		),
		"Recycled beam allocated a material or retained its previous style/age"
	)
	_check(
		(rail.node.transform * Vector3(0, 0, -.5)).is_equal_approx(origin + Vector3.UP * 4),
		"Vertical beam produced an invalid transform"
	)
	for index in effects.MAX_TRACERS + 4:
		effects.shot(unit, origin, endpoint, .16, false, null, true, {"kind": "rail"})
	_check(effects._tracers.size() == effects.MAX_TRACERS, "Beam pool exceeded MAX_TRACERS")
	var nodes = effects.get_children().filter(func(node): return node is MeshInstance3D)
	_check(nodes.size() == effects.MAX_TRACERS, "Beam saturation leaked tracer nodes")
	effects._advance_tracers(1.0)
	_check(
		(
			effects._free_tracers.size() == effects.MAX_TRACERS
			and nodes.all(func(node): return not node.visible)
		),
		"Saturated beam pool did not retire cleanly"
	)
	effects.shot(unit, origin, origin, .16, false, null, true, {"kind": "rail"})
	_check(not effects._tracers[0].node.visible, "Zero-length beam drew invalid geometry")
	effects._advance_tracers(1.0)
	unit.aim_target = target
	target.hide()
	effects.shot(unit, origin, endpoint, .16, false, target, true, {"kind": "rail"})
	_check(effects._tracers.is_empty(), "Fog-hidden aim target spawned a beam")
	unit.aim_target = null
	var pooled_materials = effects._free_tracers.map(
		func(entry): return weakref(entry.beam_material)
	)
	var beam_mesh = weakref(effects._beam_mesh)
	rail = null
	prism = null
	material = null
	stage.free()
	_check(
		(
			pooled_materials.all(func(reference): return reference.get_ref() == null)
			and beam_mesh.get_ref() == null
		),
		"Destroyed combat effects retained pooled beam materials or geometry"
	)
