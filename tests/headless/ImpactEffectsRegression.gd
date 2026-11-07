extends SceneTree

var errors = []
var effects
var stage
var options


class Ground:
	extends RefCounted

	func height_at(_point):
		return 0.0


class Audio:
	extends RefCounted
	var impacts = 0

	func point_observed(_point, _owner):
		return true

	func point_impact(_point, _owner):
		impacts += 1


class Stage:
	extends Node3D
	var map = Ground.new()
	var restoring = false
	var combat_audio = Audio.new()


class Particles:
	extends Node3D
	var speed_scale = 1.0
	var emissions = []

	func emit_particle(pose, velocity, color, _custom, _flags):
		emissions.append(
			{
				"point": pose.origin,
				"velocity": velocity,
				"color": color,
				"size": pose.basis.x.length()
			}
		)


func _initialize():
	_run.call_deferred()


func _run():
	options = root.get_node("Globals").options
	var reduced = options.reduced_flashes
	options.reduced_flashes = false
	stage = Stage.new()
	root.add_child(stage)
	effects = load("res://source/match/effects/CombatEffects.gd").new()
	stage.add_child(effects)
	effects.set_process(false)
	effects.set_physics_process(false)
	effects.aftermath = load("res://source/match/effects/BattleAftermath.gd").new()
	effects.add_child(effects.aftermath)
	for kind in ["flash", "spark", "fire", "smoke", "dust", "debris", "clod"]:
		var buffer = Particles.new()
		effects.add_child(buffer)
		effects._emitters[kind] = buffer
	effects._headless = false
	_blast_stages()
	_fragmentation()
	_airburst()
	_limits_and_settings()
	options.reduced_flashes = reduced
	stage.free()
	await process_frame
	for error in errors:
		push_error(error)
	print("Impact effects regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _clear():
	for buffer in effects._emitters.values():
		buffer.emissions.clear()
	effects._blast_tails.clear()
	effects._advance_hit_flashes(1.0)
	effects.aftermath.advance(3.0)


func _blast_stages():
	effects._explosion(Vector3.UP, 1.65, true, true)
	_check(effects._emitters.flash.emissions.size() == 1, "Blast lost ignition flash")
	_check(not effects._emitters.fire.emissions.is_empty(), "Blast lost its hot phase")
	_check(effects._emitters.smoke.emissions.is_empty(), "Smoke obscures the initial flash")
	_check(effects._blast_tails.size() == 1, "Blast has no bounded smoke tail")
	effects._process(.05)
	_check(effects._emitters.smoke.emissions.is_empty(), "Smoke arrived before ignition cleared")
	var age = effects._blast_tails[0].age
	paused = true
	effects._process(.5)
	_check(effects._blast_tails[0].age == age, "Pause advanced staged smoke")
	paused = false
	effects._process(.05)
	_check(effects._emitters.smoke.emissions.size() == 2, "First plume stage was lost/repeated")
	effects._process(.15)
	_check(
		effects._emitters.smoke.emissions.size() == 4 and effects._blast_tails.is_empty(),
		"Cooling plume failed to finish exactly once"
	)
	_check(
		effects._emitters.smoke.emissions.all(func(puff): return puff.velocity.y > .4),
		"Blast smoke does not rise"
	)
	_check(
		effects._emitters.smoke.emissions[2].size > effects._emitters.smoke.emissions[0].size,
		"Cooling plume did not broaden after ignition"
	)
	_clear()
	effects._explosion(Vector3.UP, .8, false)
	effects._process(.3)
	_check(
		effects._emitters.smoke.emissions.size() == 2,
		"A slow frame skipped/duplicated smoke stages"
	)
	_clear()


func _fragmentation():
	effects.grenade_impact(Vector3.ZERO, 2.5, null)
	_check(
		effects._emitters.fire.emissions.is_empty() and effects._blast_tails.is_empty(),
		"Fragmentation still uses a fuel fireball"
	)
	_check(
		(
			effects._emitters.spark.emissions.size() == 12
			and effects._emitters.dust.emissions.size() == 6
		),
		"Fragmentation lost its radial dirt/sparks"
	)
	_check(effects._shockwaves.size() == 1, "Grenade duplicated its pressure wave")
	_check(stage.combat_audio.impacts == 1, "Grenade replayed its impact sound")
	_check(effects.aftermath.debris.is_empty(), "Grenade spawned vehicle-wreck debris")
	_clear()


func _airburst():
	effects.airburst(Vector3(0, 3, 0), 1.2, Color.WHITE)
	_check(effects._emitters.smoke.emissions.size() == 3, "Airburst lost separated smoke wisps")
	_check(
		effects._emitters.dust.emissions.is_empty() and effects._shockwaves.is_empty(),
		"Airburst produced a ground splash"
	)
	_clear()


func _limits_and_settings():
	for index in effects.MAX_BLAST_TAILS + 8:
		effects._explosion(Vector3.UP, .8, false)
	_check(effects._blast_tails.size() == effects.MAX_BLAST_TAILS, "Smoke-tail budget exceeded")
	effects._process(.7)
	_check(
		effects._blast_tails.is_empty() and effects._emitters.smoke.emissions.is_empty(),
		"Long suspended frame replayed expired plumes"
	)
	_clear()
	stage.restoring = true
	effects._explosion(Vector3.UP, 1.0, false)
	_check(effects._blast_tails.is_empty(), "Restoration scheduled cosmetic smoke")
	stage.restoring = false
	options.reduced_flashes = true
	effects._explosion(Vector3.UP, 1.65, true, true)
	effects.grenade_impact(Vector3.ZERO, 2.5, null)
	effects._process(.3)
	_check(
		(
			effects._emitters.flash.emissions.is_empty()
			and effects._emitters.fire.emissions.is_empty()
			and effects._emitters.spark.emissions.is_empty()
			and effects._shockwaves.is_empty()
		),
		"Reduced flashes retained hot effects"
	)
	_check(
		(
			not effects._emitters.smoke.emissions.is_empty()
			and not effects._emitters.dust.emissions.is_empty()
		),
		"Reduced flashes lost impact readability"
	)


func _check(condition, message):
	if not condition:
		errors.append(message)
