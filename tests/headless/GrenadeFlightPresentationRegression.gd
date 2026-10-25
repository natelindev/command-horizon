extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("bastion")
	var effects = _game.combat_effects
	effects.set_physics_process(false)
	effects._headless = false  # Exercise the bounded mesh presentation without GPU particles.
	_game.grenade_system.set_physics_process(false)
	var soldier = _spawn("Infantry", 0, Vector3(35, 0, 30))
	var target = Vector3(39, 0, 30)
	_check(soldier.abilities.trigger("frag_grenade", target), "Normal throw rejected")
	_check(effects._grenades.size() == 1, "Normal throw has missing or duplicate flight")
	soldier.queue_free()
	await _frames(1)
	effects._advance_abilities(.25)
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
	effects._advance_abilities(.36)
	_check(effects._grenades.is_empty(), "Finished grenade retained its warning mesh")
	_check(_game.grenade_system.pending.size() == 1, "Presentation consumed authoritative fuse")
	effects._headless = true
	await _close()
	for message in _errors:
		push_error(message)
	print("Grenade flight presentation regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
