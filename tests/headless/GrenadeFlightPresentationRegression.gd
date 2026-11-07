extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("bastion")
	var effects = _game.combat_effects
	effects.set_physics_process(false)
	effects.set_process(false)
	effects._headless = false  # Exercise the bounded mesh presentation without GPU particles.
	_game.grenade_system.set_physics_process(false)
	var soldier = _spawn("Infantry", 0, Vector3(35, 0, 30))
	var target = Vector3(39, 0, 30)
	var fixture = load("res://tests/headless/GrenadeFixture.gd")
	var building = fixture.building(_game, target)
	var occupant = _spawn("Infantry", 1, target)
	_check(fixture.occupy(building, occupant), "Flight fixture garrison rejected")
	_game.battlefield.invalidate()
	_check(soldier.abilities.trigger("frag_grenade", target, building), "Normal throw rejected")
	target = _game.grenade_system.pending[0].point
	_check(effects._grenades.size() == 1, "Normal throw has missing or duplicate flight")
	soldier.queue_free()
	await _frames(1)
	effects._process(.25)
	_check(
		effects._grenades.size() == 1 and effects._grenades[0].node.visible,
		"Thrower death hid committed flight"
	)
	var expected = effects._grenades[0].node.position
	effects._grenades[0].node.queue_free()
	effects._grenades.clear()
	effects.grenade_flight(Vector3(35, 0, 30), target, .35, _players[0])
	_check(
		effects._grenades[0].node.position.is_equal_approx(expected),
		"Restore changed grenade trajectory age"
	)
	paused = true
	effects._process(.5)
	effects._physics_process(.5)
	_check(
		(
			effects._grenades[0].node.visible
			and effects._grenades[0].node.position.is_equal_approx(expected)
		),
		"Paused restore hid or advanced grenade"
	)
	paused = false
	var origin = Vector3(35, .9, 30)
	_check(
		effects.grenade_position(origin, target, 0.0).is_equal_approx(origin),
		"Ballistic grenade did not start at the hand"
	)
	_check(
		effects.grenade_position(origin, target, 1.0).is_equal_approx(target),
		"Ballistic grenade did not reach the authoritative impact point"
	)
	var samples = []
	for time in [.1, .2, .3, .4]:
		samples.append(effects.grenade_position(origin, target, time))
	var first_acceleration = samples[2] - samples[1] * 2.0 + samples[0]
	var second_acceleration = samples[3] - samples[2] * 2.0 + samples[1]
	_check(
		first_acceleration.is_equal_approx(second_acceleration) and first_acceleration.y < 0,
		"Grenade arc does not have constant downward acceleration"
	)
	effects._process(.001)
	_check(
		not effects._grenades[0].node.position.is_equal_approx(expected),
		"Grenade presentation waited for a physics tick"
	)
	var age = effects._grenades[0].age
	effects._physics_process(.1)
	_check(effects._grenades[0].age == age, "Grenade age advanced twice")
	effects._process(.36)
	_check(effects._grenades.is_empty(), "Finished grenade retained its warning mesh")
	_check(_game.grenade_system.pending.size() == 1, "Presentation consumed authoritative fuse")
	effects._headless = true
	await _close()
	for message in _errors:
		push_error(message)
	print("Grenade flight presentation regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
