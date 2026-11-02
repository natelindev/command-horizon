extends "res://tests/headless/CombatRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in 2:
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.faction = "helix" if index == 0 else "bastion"
		player.controller = (
			constants.PlayerType.HUMAN if index == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(player): return player != _human)[0]
	_enemy.set_process(false)
	await _frames(60)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)
	_game.projectile_system.set_physics_process(false)
	await _overdrive()
	await _clear()
	await _kite()
	await _clear()
	await _scrap_expiry()
	await _clear()
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	print("Helix support and scrap expiry: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _overdrive():
	var generator = _spawn("PowerPlant", _human, Vector3(40, 0, 8))
	var second = _spawn("PowerPlant", _human, Vector3(43, 0, 8))
	var target = _spawn("Tank", _human, Vector3(46, 0, 8))
	await _frames(3)
	_check(target.shields_max > 0.0, "Helix lost innate shields")
	target.shields = 0.0
	target.last_shield_damage_time = _game.simulation_time
	var power = _human.power_totals()
	_check(generator.abilities.trigger("power_overdrive"), "Legal Overdrive activation rejected")
	_check(_human.power_totals().y == power.y + 3, "Overdrive did not add 3 demand")
	_check(target.shields == 0.0, "Overdrive refilled shields immediately")
	target._physics_process(1.0)
	_check(target.shields == 0.0, "Overdrive bypassed 5s shield damage delay")
	_game.simulation_time += 5.0
	target._physics_process(1.0)
	_check(target.shields == 16.0, "Overdrive did not recharge at 16HP/s")
	_check(
		second.abilities.trigger("power_overdrive"), "Second Overdrive rejected with spare power"
	)
	_check(_game.helix_support.shield_factor(target) == 2.0, "Overlapping Overdrive stacked")
	var hp = target.hp
	target.global_position = Vector3(60, 0, 8)
	_game.battlefield.invalidate()
	_check(_game.helix_support.shield_factor(target) == 1.0, "Overdrive persisted outside coverage")
	target.global_position = Vector3(46, 0, 8)
	_game.battlefield.invalidate()
	var factories = []
	for index in 8:
		factories.append(_spawn("VehicleFactory", _human, Vector3(70 + index, 0, 25)))
	await _frames(3)
	_check(_human.power_totals().x < _human.power_totals().y, "Power-shortage fixture failed")
	_check(_game.helix_support.shield_factor(target) == .5, "Low power did not halve recharge")
	_check(
		generator.abilities.is_active("power_overdrive"), "Low power discarded Overdrive request"
	)
	_check(target.hp == hp, "Overdrive changed hull HP")
	_check(generator.abilities.trigger("power_overdrive"), "Cannot switch suspended Overdrive off")
	_check(
		not generator.abilities.trigger("power_overdrive"),
		"Overdrive activated without projected supply"
	)
	for factory in factories:
		factory.queue_free()
	await _frames(3)
	_check(
		_game.helix_support.shield_factor(target) == 2.0,
		"Restored power did not resume requested field"
	)
	var saved = second.abilities.capture()
	second.abilities.restore(saved)
	_check(
		_game.helix_support.shield_factor(target) == 2.0, "Restored Overdrive request lost coverage"
	)


func _kite():
	var drone = _spawn("Drone", _human, Vector3(40, 0, 8))
	var target = _spawn("Tank", _human, Vector3(44, 0, 8))
	var enemy = _spawn("Tank", _enemy, Vector3(48, 0, 8))
	await _frames(3)
	var rules = load("res://source/match/combat/CombatRules.gd")
	_check(not drone.armed() and not rules.can_target(drone, enemy), "Helix Kite remains armed")
	drone.issue_manual_order(load("res://source/match/units/actions/DroneDive.gd").new(enemy))
	_check(drone.action == null, "Helix Kite accepted a direct dive action")
	_check(not drone.abilities.trigger("drone_chaff"), "Chaff bypassed Signal lab prerequisite")
	_spawn("CommandLab", _human, Vector3(65, 0, 40))
	await _frames(3)
	_check(drone.abilities.trigger("drone_chaff"), "Chaff did not activate")
	_check(drone.abilities.get_ability("drone_chaff").cooldown_left == 30.0, "Chaff cooldown wrong")
	_check(_game.helix_support.missile_jammed(_enemy, target), "Chaff omitted allied ground target")
	_check(
		not _game.helix_support.missile_jammed(_human, enemy), "Chaff jammed friendly fire at enemy"
	)
	var system = _game.projectile_system
	var weapon = load("res://source/match/combat/WeaponCatalog.gd").GUIDED_SALVO
	var round = system.launch(enemy, target, weapon)
	round.position = Vector3(38, 3, 8)
	round.velocity = Vector3(24, 0, 0)
	target.global_position = Vector3(44, 0, 13)
	_game.battlefield.invalidate()
	system._integrate(round, 0.1)
	_check(
		round.velocity.is_equal_approx(Vector3(24, 0, 0)),
		"Chaff changed missile velocity or guided anyway"
	)
	_check(system._rounds.has(round), "Chaff deleted in-flight missile")
	drone.abilities._physics_process(8.0)
	system._integrate(round, 0.1)
	_check(not round.velocity.is_equal_approx(Vector3(24, 0, 0)), "Missile guidance did not resume")
	system._remove(round)
	drone.abilities.get_ability("drone_chaff").cooldown_left = 0.0
	drone.abilities.trigger("drone_chaff")
	for kind in ["bullet", "shell", "rocket", "bomb"]:
		var unguided_weapon = weapon.duplicate()
		unguided_weapon.kind = kind
		unguided_weapon.gravity = 0.0
		unguided_weapon.thrust = 0.0
		var unguided = system.launch(enemy, target, unguided_weapon)
		unguided.position = Vector3(38, 3, 8)
		unguided.velocity = Vector3(24, 0, 0)
		system._integrate(unguided, 0.1)
		_check(
			unguided.velocity.is_equal_approx(Vector3(24, 0, 0)),
			"Chaff altered non-missile flight: " + kind
		)
		system._remove(unguided)
	var second = _spawn("Drone", _human, Vector3(42, 0, 10))
	await _frames(3)
	_check(second.abilities.trigger("drone_chaff"), "Overlapping chaff could not activate")
	drone.hp = 0.0
	_check(
		_game.helix_support.missile_jammed(_enemy, target),
		"One lost emitter erased overlapping chaff"
	)
	second.hp = 0.0
	_check(not _game.helix_support.missile_jammed(_enemy, target), "Dead Kite kept its chaff field")
	var other = _spawn("Drone", _enemy, Vector3(50, 0, 15))
	await _frames(3)
	_check(other.armed() and rules.can_target(other, target), "Other faction drone lost its weapon")


func _scrap_expiry():
	_human.faction = "frontier"
	var ironback = _spawn("AdvancedTank", _human, Vector3(40, 0, 8))
	await _frames(3)
	ironback.permanent_scrap_rank = 2
	ironback.scrap_hardened_tiers = 2
	ironback.scrap_hardened_left = 0.2
	ironback._physics_process(0.2)
	_check(
		ironback.scrap_hardened_tiers == 0 and ironback.scrap_hardened_left == 0.0,
		"AdvancedTank override did not expire timed salvage buffs"
	)
	_check(
		ironback.permanent_scrap_rank == 2, "Timed buff expiry removed permanent scrap protection"
	)
	var enemy = _spawn("Infantry", _enemy, Vector3(45, 0, 8))
	await _frames(3)
	var before = ironback.hp
	ironback.receive_damage(enemy, 20.0, null, {"kind": "bullet"})
	_check(
		is_equal_approx(ironback.hp, before - 18.0),
		"Permanent scrap reduction not exactly 10% once"
	)
