extends "res://tests/headless/NativeUnitStateRegression.gd"

var _native_queries
var _positive := 0


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_rules = load("res://source/match/combat/CombatRules.gd")
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		var field = _game.battlefield
		_native_queries = field._native_visibility
		if (
			_native_queries == null
			or _game.unit_state_store == null
			or not field.native_combat_queries
		):
			_check(false, "Requires native visibility, unit state and combat queries")
			await _close()
			break
		_actors = []
		for side in 2:
			for role in MOBILE_ROLES + ["Fighter", "Bomber", "AircraftFactory", "AntiAirTurret"]:
				_actors.append(_spawn(role, side, Vector3(20 + _actors.size(), 0, 25)))
		await _frames(3)
		var rng := RandomNumberGenerator.new()
		rng.seed = 918325
		var centres = [
			Vector2(54, 20),
			Vector2(65, 110),
			Vector2(110, 65),
			Vector2(48, 44),
			Vector2(96, 80),
			Vector2(30, 30)
		]
		for step in 1200:
			var source = _actors[step % 16]
			var target = _actors[16 + (step / 16) % 16]
			_mutate(source, step)
			_mutate(target, step + 17)
			var centre: Vector2 = centres[step % centres.size()]
			var point := centre + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			var end := point + Vector2(rng.randf_range(-16, 16), rng.randf_range(-16, 16))
			source.global_position = _game.map.ground_point(point)
			target.global_position = _game.map.ground_point(end)
			source.rotation.y = rng.randf_range(-PI, PI)
			target.rotation.y = rng.randf_range(-PI, PI)
			_players[0].team = 0 if step % 13 == 0 else -1
			_players[1].team = 0 if step % 13 == 0 else 1
			for actor in [source, target]:
				if actor.get("_flight") != null:
					actor._flight.phase = step % 6
				if step % 7 == 0:
					actor.global_position.y += 8
			_compare_fire(source, target, "%s random %d" % [faction, step])
			# Same-tick mutation: a successful witness may not preserve a stale answer.
			target.global_position += Vector3(2.75, 0, -1.25)
			source.sight_range = 3.0 if step % 2 == 0 else 40.0
			_compare_fire(source, target, "%s changed %d" % [faction, step])
		_boundary_cases(faction)
		_air_range_cases(faction)
		var statistics: Array = _native_queries.combat_statistics()
		_check(
			statistics.size() == 3 and statistics[1] > 2400, "Native firing queries did not execute"
		)
		var generic := Node3D.new()
		_game.add_child(generic)
		_check(
			_native_queries.can_fire(generic, _actors[0], {}, 0.0, 0.0) == -1,
			"Generic source lost fallback"
		)
		generic.queue_free()
		await _close()
	_check(_positive > 40, "Oracle did not exercise enough successful shots")
	for message in _errors:
		push_error(message)
	print(
		(
			"Native combat query: %d failures across %d comparisons (%d positive)"
			% [_errors.size(), _comparisons, _positive]
		)
	)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _compare_fire(source, target, label: String):
	var field = _game.battlefield
	var resident: bool = field.native_battlefield_index
	field.native_battlefield_index = false
	field.native_combat_queries = false
	field._native_visibility = null
	field._native_index = false
	field.invalidate()
	var expected = _oracle([source, target], func(): return field.can_fire(source, target))
	field._native_visibility = _native_queries
	field.native_battlefield_index = resident
	field._native_index = true
	field.native_combat_queries = true
	field.invalidate()
	var actual = field.can_fire(source, target)
	_comparisons += 1
	_positive += int(expected)
	if expected != actual and _errors.size() < 30:
		_check(
			false,
			(
				"Firing differs %s %s -> %s: expected %s actual %s"
				% [label, source.type, target.type, expected, actual]
			)
		)


func _boundary_cases(faction: String):
	var source = _actors[6]  # Tank
	var target = _actors[22]
	for actor in [source, target]:
		actor.reparent(_players[0] if actor == source else _players[1])
		actor.hp = 100.0
		actor.attack_range = 10.0
		actor.attack_domains = [0, 1, 2]
		actor.get_node("Movement").domain = 1
		actor.remove_meta("garrison_host")
		actor.remove_meta("breach_pending")
		actor.sight_range = 50.0
		var siege = actor.abilities.get_ability("siege_anchor")
		if siege != null:
			siege.is_active = false
	_players[0].team = -1
	_players[1].team = 1
	for height in [-1.50001, -1.5, -1.49999, 0.0, 1.49999, 1.5, 1.50001]:
		source.global_position = Vector3(25, 3 + maxf(0, height), 15)
		target.global_position = Vector3(25, 3 + maxf(0, -height), 15)
		var reach: float = _rules.range_for(source, target)
		for epsilon in [-.00001, 0.0, .00001]:
			target.global_position.x = 25 + reach + epsilon
			_compare_fire(source, target, "%s boundary %s %s" % [faction, height, epsilon])


func _air_range_cases(faction: String):
	var target = _actors[27]  # Helicopter: reset the randomized movement domain.
	target.reparent(_players[1])
	target.hp = 100.0
	target.get_node("Movement").domain = 0
	target.remove_meta("garrison_host")
	for index in [1, 9]:  # Rocket infantry and CombatRobot have distinct AA ranges.
		var source = _actors[index]
		source.reparent(_players[0])
		source.hp = 100.0
		source.attack_range = 12.0
		source.attack_domains = [0, 1, 2]
		source.sight_range = 50.0
		source.get_node("Movement").domain = 1
		source.remove_meta("breach_pending")
		for garrison in [false, true]:
			if garrison:
				source.set_meta("garrison_host", _actors[14])
			else:
				source.remove_meta("garrison_host")
			source.global_position = Vector3(25, 3, 15)
			target.global_position = Vector3(25, 6, 15)
			var reach: float = _rules.range_for(source, target)
			for epsilon in [-.00001, 0.0, .00001]:
				target.global_position.x = 25 + reach + epsilon
				_compare_fire(
					source, target, "%s AA boundary %s %s %s" % [faction, index, garrison, epsilon]
				)
		source.remove_meta("garrison_host")


func _fixture(faction, map_name = "battlefields/TerrainTestMap"):
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.map_path = "res://source/match/maps/%s.tscn" % map_name
	for side in 2:
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if side == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = faction
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	await _frames(30)
	_players = get_nodes_in_group("players")
	for player in _players:
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)
	await _frames(2)
