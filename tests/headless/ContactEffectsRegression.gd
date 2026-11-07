extends "res://tests/headless/ImpactEffectsRegression.gd"


class ObservedAudio:
	extends RefCounted
	var observed = true

	func _observed(_unit):
		return observed


class Subject:
	extends Node3D
	var hp = 100.0
	var radius = .9


class Foliage:
	extends Node3D
	var impulses = []

	func impulse(point, strength):
		impulses.append({"point": point, "strength": strength})


func _run():
	options = root.get_node("Globals").options
	var reduced = options.reduced_flashes
	options.reduced_flashes = false
	stage = Stage.new()
	stage.combat_audio = ObservedAudio.new()
	root.add_child(stage)
	effects = load("res://source/match/effects/CombatEffects.gd").new()
	stage.add_child(effects)
	effects.set_process(false)
	effects.set_physics_process(false)
	effects.foliage = Foliage.new()
	effects.add_child(effects.foliage)
	for kind in ["flash", "exhaust", "dust"]:
		var buffer = Particles.new()
		effects.add_child(buffer)
		effects._emitters[kind] = buffer
	effects._headless = false
	_shield_contact()
	_muzzle_gas()
	_downwash()
	options.reduced_flashes = reduced
	stage.free()
	await process_frame
	for error in errors:
		push_error(error)
	print("Contact effects regression: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _unit():
	var unit = Subject.new()
	unit.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	stage.add_child(unit)
	var collider = CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.position.y = .7
	collider.shape = CylinderShape3D.new()
	collider.shape.radius = .9
	collider.shape.height = 1.4
	unit.add_child(collider)
	return unit


func _shield_contact():
	var unit = _unit()
	effects.shield_impact(unit, Vector3(.9, .7, 0))
	_check(effects._shield_ripples.size() == 1, "Shield has no localized contact wave")
	var wave = effects._shield_ripples[0]
	_check(
		wave.material_override.get_shader_parameter("hit_direction").is_equal_approx(Vector3.RIGHT),
		"Contact wave did not originate on the struck side"
	)
	_check(effects._hit_flashes.is_empty(), "Shield still flashes the whole hull")
	var local_pose = unit.global_transform.affine_inverse() * wave.global_transform
	unit.position = Vector3(3, 2, 1)
	unit.rotation.y = .7
	effects._process(.005)
	_check(
		wave.global_transform.is_equal_approx(unit.global_transform * local_pose),
		"Moving shield detached its contact wave"
	)
	_check(wave.age > 0.0, "Shield contact waits for a physics tick")
	var age = wave.age
	paused = true
	effects._process(.5)
	_check(wave.age == age, "Pause advanced shield contact")
	options.reduced_flashes = true
	effects._process(.5)
	_check(
		effects._shield_ripples.is_empty() and not wave.visible, "Paused settings retained shield"
	)
	paused = false
	options.reduced_flashes = false
	for index in effects.MAX_SHIELD_RIPPLES + 5:
		effects.shield_impact(unit, unit.position + Vector3.RIGHT)
	_check(effects._shield_ripples.size() == effects.MAX_SHIELD_RIPPLES, "Shield budget exceeded")
	effects._process(.5)
	_check(effects._shield_ripples.is_empty(), "Expired shield contacts remain")
	effects.shield_impact(unit, unit.position)
	stage.combat_audio.observed = false
	effects._process(.01)
	_check(effects._shield_ripples.is_empty(), "Hidden target retained shield contact")
	effects.shield_impact(unit, unit.position)
	_check(effects._shield_ripples.is_empty(), "Hidden target emitted shield contact")
	stage.combat_audio.observed = true
	effects.shield_impact(unit, unit.position)
	unit.free()
	effects._process(.01)
	_check(effects._shield_ripples.is_empty(), "Deleted target retained shield contact")
	unit = _unit()
	stage.restoring = true
	effects.shield_impact(unit, Vector3.RIGHT)
	_check(effects._shield_ripples.is_empty(), "Restore emitted shield contact")
	stage.restoring = false
	unit.free()


func _muzzle_gas():
	var buffer = effects._emitters.exhaust
	var direction = Vector3(1, .3, -1).normalized()
	var point = Vector3(2, 3, 4)
	effects._cannon_gas(point, direction, Color.WHITE)
	_check(buffer.emissions.size() == 3, "Cannon lacks tapered gas jets")
	for puff in buffer.emissions:
		_check(puff.velocity.normalized().dot(direction) > .999, "Gas ignores barrel direction")
		_check((puff.point - point).dot(direction) > 0, "Gas jet originated behind the muzzle")
	_check(buffer.emissions[0].size > buffer.emissions[-1].size, "Gas jet does not taper")
	effects._muzzle_shockwave(point, direction)
	_check(effects._shockwaves.size() == 1, "Muzzle pressure wave missing")
	var wave = effects._shockwaves[0]
	_check(wave.duration < .2, "Muzzle pressure lingers like an explosion")
	_check(
		(-wave.node.basis.z).is_equal_approx(direction), "Pressure wave ignores barrel direction"
	)
	effects._process(.05)
	var progress = wave.node.material_override.get_shader_parameter("progress")
	_check(progress > 0.0, "Pressure wave did not animate")
	paused = true
	effects._process(.5)
	_check(
		wave.node.material_override.get_shader_parameter("progress") == progress,
		"Pause advanced muzzle pressure"
	)
	paused = false
	options.reduced_flashes = true
	effects._process(.0)
	buffer.emissions.clear()
	effects._cannon_gas(point, direction, Color.WHITE)
	effects._muzzle_shockwave(point, direction)
	_check(
		buffer.emissions.is_empty() and effects._shockwaves.is_empty(),
		"Reduced flashes retained muzzle gas or pressure"
	)
	options.reduced_flashes = false


func _downwash():
	var unit = _unit()
	unit.position.y = 1.0
	var buffer = effects._emitters.dust
	effects.rotor_downwash(unit)
	_check(buffer.emissions.size() == 5, "Rotor lacks an outward dust fan")
	var directions = Vector3.ZERO
	for puff in buffer.emissions:
		var radial = puff.point * Vector3(1, 0, 1)
		_check(radial.dot(puff.velocity) > 0.0, "Rotor dust does not travel outward")
		_check(is_equal_approx(puff.point.y, .07), "Rotor dust floats above the ground")
		directions += radial.normalized()
	_check(directions.length() < 1.0, "Rotor dust still favors one side")
	var low_alpha = buffer.emissions[0].color.a
	var low_force = effects.foliage.impulses[-1].strength
	buffer.emissions.clear()
	unit.position.y = 4.5
	effects.rotor_downwash(unit)
	_check(buffer.emissions[0].color.a < low_alpha * .1, "High rotor wash did not soften")
	_check(effects.foliage.impulses[-1].strength < low_force * .1, "High rotor flattens foliage")
	buffer.emissions.clear()
	unit.position.y = 5.0
	effects.rotor_downwash(unit)
	_check(buffer.emissions.is_empty(), "High aircraft leaves ground dust")
	unit.position.y = 1.0
	paused = true
	effects.rotor_downwash(unit)
	_check(buffer.emissions.is_empty(), "Paused rotor emits dust")
	paused = false
	options.reduced_flashes = true
	effects.rotor_downwash(unit)
	_check(buffer.emissions.size() == 5, "Reduced flashes removed non-flashing rotor dust")
	options.reduced_flashes = false
	unit.free()
