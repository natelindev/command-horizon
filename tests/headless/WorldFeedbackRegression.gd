extends "res://tests/headless/ContactEffectsRegression.gd"


class Observer:
	extends RefCounted
	var observed = true
	var cutoff = INF
	var backfires = 0
	var completions = 0

	func _observed(_unit):
		return observed

	func point_observed(point, _owner = null):
		return observed and point.x < cutoff

	func vehicle_backfire(_unit, _point):
		backfires += 1

	func construction_completed(_unit):
		completions += 1


class WetField:
	extends RefCounted

	func sample(point):
		return Color(0, 0, 1, 1 if point.x > 20 else 0)

	func level_at(_point):
		return .4


class WetGround:
	extends RefCounted
	var size = Vector2(128, 128)
	var water_flow = WetField.new()

	func height_at(_point):
		return 0.0


class Side:
	extends RefCounted
	var faction = "helix"


class Vehicle:
	extends Node3D
	var hp = 100.0
	var radius = .9
	var type = "Tank"
	var player = Side.new()
	var shield_component


func _run():
	var logger = load("res://tests/headless/FactionAsymmetryRegression.gd").RuntimeErrorLog.new()
	OS.add_logger(logger)
	options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{"reduced_flashes": false, "battlefield_wear": true, "graphics_ground_detail": true}
	)
	stage = Stage.new()
	stage.map = WetGround.new()
	stage.combat_audio = Observer.new()
	root.add_child(stage)
	effects = load("res://source/match/effects/CombatEffects.gd").new()
	stage.add_child(effects)
	effects.set_process(false)
	effects.set_physics_process(false)
	effects.aftermath = load("res://source/match/effects/BattleAftermath.gd").new()
	effects.add_child(effects.aftermath)
	effects.foliage = Foliage.new()
	effects.add_child(effects.foliage)
	for kind in [
		"flash", "spark", "smoke", "dust", "fire", "mote", "debris", "clod", "foam", "mist"
	]:
		var buffer = Particles.new()
		effects.add_child(buffer)
		effects._emitters[kind] = buffer
	effects._headless = false
	_lifecycle()
	_phase_endpoints()
	_water_and_locomotion()
	_wear_and_backfire()
	_completion()
	stage.free()
	await process_frame
	options.restore(original)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("World feedback regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _vehicle():
	var unit = Vehicle.new()
	unit.shield_component = load("res://source/match/units/traits/ShieldComponent.gd").new()
	stage.add_child(unit)
	return unit


func _lifecycle():
	var unit = _vehicle()
	effects.watch_unit(unit)
	effects.watch_unit(unit)
	unit.shield_component.set_capacity(20)
	unit.shield_component.absorb(20, 0)
	_check(effects._shield_ripples.size() == 1, "Break signal missing or connected twice")
	_check(
		effects._shield_ripples[0].mode == effects.ShieldImpactVisual.Mode.BREAK,
		"Break uses contact ripple"
	)
	_check(effects._emitters.spark.emissions.size() == 12, "Break lost its discharge sparks")
	effects._advance_shield_ripples(1)
	unit.shield_component.tick(.1, 6)
	_check(effects._shield_ripples.size() == 1, "Recharge start has no shell")
	var wave = effects._shield_ripples[0]
	paused = true
	effects._process(.4)
	_check(wave.age == 0.0, "Pause advanced shield recharge sweep")
	paused = false
	unit.shield_component.absorb(.1, 6.1)
	effects._advance_shield_ripples(0)
	_check(effects._shield_ripples.is_empty(), "Interrupted recharge kept its contour")
	unit.shield_component.tick(10, 20)
	effects._advance_shield_ripples(0)
	_check(
		(
			effects._shield_ripples.size() == 1
			and effects._shield_ripples[0].mode == effects.ShieldImpactVisual.Mode.RESTORED
		),
		"Full restoration lost its confirmation pulse"
	)
	unit.hide()
	effects._advance_shield_ripples(0)
	_check(effects._shield_ripples.is_empty(), "Shield lifecycle exposed a hidden unit")
	unit.show()
	options.reduced_flashes = true
	unit.shield_component.absorb(20, 21)
	_check(effects._shield_ripples.is_empty(), "Reduced flashes emitted a shatter shell")
	options.reduced_flashes = false
	unit.free()
	_clear()


func _phase_endpoints():
	stage.combat_audio.cutoff = 10
	effects.phase_shift(Vector3(5, 0, 5), Vector3(12, 0, 5))
	_check(effects._phase_remnants.size() == 1, "Blink revealed its unseen destination")
	_check(effects.foliage.impulses.is_empty(), "Hidden landing disturbed visible foliage")
	stage.combat_audio.cutoff = INF
	paused = true
	effects._process(.5)
	_check(effects._phase_remnants[0].age == 0.0, "Paused blink aged")
	paused = false
	effects._advance_phase_remnants(1)
	for index in 12:
		effects.phase_shift(Vector3(5, 0, 5), Vector3(12, 0, 5))
	_check(
		effects._phase_remnants.size() == effects.MAX_PHASE_REMNANTS,
		"Blink pool exceeded its budget"
	)
	stage.restoring = true
	effects._process(.1)
	_check(effects._phase_remnants.is_empty(), "Restoration retained activation remnants")
	effects.phase_shift(Vector3.ZERO, Vector3.RIGHT)
	_check(effects._phase_remnants.is_empty(), "Restoration replayed a blink")
	stage.restoring = false
	_clear()


func _water_and_locomotion():
	effects._explosion(Vector3(25, .4, 10), 2.0, false, true)
	_check(effects._emitters.foam.emissions.size() == 24, "Heavy water hit lost its geyser")
	_check(effects._emitters.mist.emissions.size() == 8, "Water hit lost its mist skirt")
	_check(
		effects._emitters.foam.emissions.slice(0, 8).all(func(p): return p.velocity.y > 10),
		"Geyser core lacks vertical weight"
	)
	_check(
		(
			effects._emitters.fire.emissions.is_empty()
			and effects._emitters.dust.emissions.is_empty()
			and effects._blast_tails.is_empty()
			and effects.aftermath.debris.is_empty()
		),
		"Water hit emitted fire, soil or wreckage"
	)
	_clear()
	options.reduced_flashes = true
	effects._explosion(Vector3(25, .4, 10), 2, true, true)
	_check(
		effects._emitters.foam.emissions.size() == 24, "Reduced flashes removed nonflashing spray"
	)
	options.reduced_flashes = false
	_clear()
	_check(
		not is_finite(effects._water_surface(Vector3(25, 4, 10))),
		"Elevated airburst classified as water"
	)
	stage.combat_audio.observed = false
	effects._explosion(Vector3(25, .4, 10), 2, true, true)
	_check(effects._emitters.foam.emissions.is_empty(), "Hidden water impact emitted a plume")
	stage.combat_audio.observed = true
	var unit = _vehicle()
	unit.position = Vector3(5, 0, 5)
	effects._dust_biome = "temperate"
	effects.movement_dust(unit)
	_check(
		effects._emitters.dust.emissions.size() == 8, "Helix skimmer still emits two tread trails"
	)
	_check(effects._emitters.clod.emissions.is_empty(), "Repulsors threw solid tread clods")
	var velocity = Vector3.ZERO
	for emission in effects._emitters.dust.emissions:
		velocity += emission.velocity
	_check(absf(velocity.x) < .01 and velocity.y > 0, "Repulsor wash is not radial and lifting")
	_clear()
	unit.player.faction = "frontier"
	effects.movement_dust(unit)
	_check(effects._emitters.dust.emissions.size() == 2, "Wheels lost paired contact dust")
	_clear()
	unit.position.x = 25
	effects.movement_dust(unit)
	_check(effects._emitters.dust.emissions.is_empty(), "Vehicle blew dry dust across water")
	unit.free()


func _wear_and_backfire():
	var wear = load("res://source/match/effects/BattlefieldWear.gd").new()
	stage.add_child(wear)
	wear.set_process(false)
	var unit = _vehicle()
	unit.player.faction = "frontier"
	for role in [
		"Worker", "SupplyTruck", "DemolitionBuggy", "FlakHalftrack", "SAMTechnical", "BattleRig"
	]:
		unit.type = role
		unit.position = Vector3(5, 0, 5)
		wear.restore([])
		wear.sample_vehicle(unit)
		unit.position.z += .6
		wear.sample_vehicle(unit)
		_check(wear.marks.size() == 1, role + " left no tire contact")
		unit.position.z += 10
		wear.sample_vehicle(unit)
		_check(wear.marks.size() == 1, "Tire marks bridged a teleport")
	unit.player.faction = "helix"
	for role in ["Worker", "Tank", "AdvancedTank", "AntiAirVehicle"]:
		unit.type = role
		wear.restore([])
		wear.sample_vehicle(unit)
		unit.position.x += 1
		wear.sample_vehicle(unit)
		_check(wear.marks.is_empty(), role + " left hover tire marks")
	var profile = load("res://source/match/units/traits/VehicleDamageProfile.gd")
	_check(
		profile.backfire_stress("frontier", 1, 2, 2),
		"Damaged accelerating Frontier engine has no stress cue"
	)
	_check(
		not profile.backfire_stress("frontier", 1, 2, -2), "Braking triggers acceleration backfire"
	)
	_check(
		(
			not profile.backfire_stress("bastion", 2, 2, 2)
			and not profile.backfire_stress("frontier", 0, 2, 2)
		),
		"Backfire ignores faction/damage identity"
	)
	unit.player.faction = "frontier"
	effects.vehicle_backfire(unit, unit.position)
	_check(
		stage.combat_audio.backfires == 1 and effects._emitters.spark.emissions.size() == 3,
		"Backfire audio and particles diverged"
	)
	unit.free()
	_clear()


func _completion():
	var unit = _vehicle()
	for faction in ["bastion", "helix", "frontier"]:
		unit.player.faction = faction
		effects.construction_completed(unit)
		_check(
			effects._emitters.smoke.emissions.size() == (0 if faction == "helix" else 8),
			"Completion lost faction steam identity"
		)
		_check(
			effects._emitters.mote.emissions.size() == (8 if faction == "helix" else 0),
			"Completion phase motes crossed factions"
		)
		_clear()
	_check(stage.combat_audio.completions == 3, "Faction completion cues missing")
	unit.hide()
	effects.construction_completed(unit)
	_check(stage.combat_audio.completions == 3, "Hidden construction emitted a celebration")
	unit.free()
