extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("helix")
	var player = _players[0]
	var first = _spawn("PowerPlant", 0, Vector3(26, 0, 20))
	var second = _spawn("PowerPlant", 0, Vector3(35, 0, 20))
	var factory = _spawn("VehicleFactory", 0, Vector3(30, 0, 20))
	_spawn("CommandLab", 0, Vector3(40, 0, 20))
	var mobiles := []
	for index in 200:
		mobiles.append(_spawn("Tank", 0, Vector3(30, 0, 20)))
	var target = mobiles[0]
	await _frames(3)
	if "--native-unit-state" in OS.get_cmdline_user_args():
		_check(target._native_state != null, "Power support silently used script state")
	var generators: Array = player.structure_candidates("PowerPlant")
	_check(generators.size() == 2, "Power support included mobile units")
	var before: Vector2i = player.power_totals()
	var ability = first.abilities.get_ability("power_overdrive")
	ability.is_active = true
	_check(player.power_totals() == before + Vector2i(0, 3), "Same-tick Overdrive demand stale")
	_check(_game.helix_support.shield_factor(target) == 2.0, "Overdrive coverage missing")
	_check(_game.helix_support.production_factor(factory) == 1.5, "Factory coverage missing")
	target.shields = 0.0
	target.last_shield_damage_time = _game.simulation_time
	_game.simulation_time += target.shield_component.recharge_delay - .001
	target._physics_process(.25)
	_check(target.shields == 0.0, "Recharge started before the damage delay")
	_game.simulation_time += .002
	target._physics_process(.25)
	_check(is_equal_approx(target.shields, 4.0), "Recharge did not resume at 16 HP/s")
	second.abilities.get_ability("power_overdrive").is_active = true
	_check(_game.helix_support.shield_factor(target) == 2.0, "Overlapping generators stacked")
	target.position.x = 60
	_check(_game.helix_support.shield_factor(target) == 1.0, "Moved unit retained coverage")
	target.position.x = 30
	second.abilities.get_ability("power_overdrive").is_active = false
	first._construction_progress = .5
	_check(_game.helix_support.shield_factor(target) == 1.0, "Incomplete generator supplied field")
	first._construction_progress = 1.0
	_check(_game.helix_support.shield_factor(target) == 2.0, "Completion was cached stale")
	first.reparent(_players[1])
	_check(_game.helix_support.shield_factor(target) == 1.0, "Captured generator retained field")
	_check(player.structure_candidates("PowerPlant").size() == 1, "Capture left stale membership")
	second.queue_free()
	_check(_game.helix_support.shield_factor(target) == .5, "Lost power did not halve recharge")
	_check(_game.helix_support.production_factor(factory) == 1.0, "Brownout retained local boost")
	await _close()
	for message in _errors:
		push_error(message)
	print("Power support scaling regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
