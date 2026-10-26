extends "res://tests/headless/SaveRestoreEdges.gd"

var economy
var rules


func _run():
	economy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	rules = load("res://source/match/combat/CombatRules.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion", "res://source/match/maps/DesertFrontier.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	paused = true
	var owner = game._get_human_player()
	var opponent = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
	var worker = _units(owner, "Worker")[0]
	var hq = _units(owner, "CommandCenter")[0]
	var contacts = [
		_spawn("Tank", opponent, Vector3(60, 0, 60)),
		_spawn("Infantry", opponent, Vector3(65, 0, 60))
	]
	for index in 16:
		contacts.append(
			_spawn(
				["Tank", "AdvancedTank", "Helicopter", "Drone", "RocketInfantry"][index % 5],
				opponent,
				Vector3(30 + index * 4, 0, 50)
			)
		)
	var resources = get_nodes_in_group("resource_units")
	var random = RandomNumberGenerator.new()
	random.seed = 1824
	for index in 24:
		contacts[0].position = resources[index % resources.size()].position + Vector3(2, 0, 0)
		contacts[1].position = Vector3(random.randf_range(5, 125), 0, random.randf_range(5, 125))
		for extra in range(2, contacts.size()):
			var point = Vector3(random.randf_range(-16, 144), 0, random.randf_range(-16, 144))
			contacts[extra].position = (
				point.snapped(Vector3(16, 1, 16)) if extra % 3 == 0 else point
			)
		if index % 4 == 0:
			contacts[0].set_meta("garrison_host", _units(opponent, "CommandCenter")[0])
		elif contacts[0].has_meta("garrison_host"):
			contacts[0].remove_meta("garrison_host")
		for cached in [false, true]:
			if cached:
				owner.set_meta("decision_approaches", {})
			for kind in [1, 2]:
				var actual = economy.deposit(game, worker, hq, kind, contacts)
				var best_score = INF
				var property = "resource_a" if kind == 1 else "resource_b"
				for resource in resources:
					if (
						resource.can_harvest(worker)
						and property in resource
						and resource.get(property) > 0
						and _safe(resource, worker, hq, contacts)
					):
						best_score = minf(best_score, economy._deposit_score(resource, hq))
				_check(
					(actual == null) == (not is_finite(best_score)),
					"Deposit search lost all safe fields"
				)
				if actual != null:
					_check(
						_safe(actual, worker, hq, contacts), "Deposit search chose an unsafe field"
					)
					_check(
						is_equal_approx(economy._deposit_score(actual, hq), best_score),
						"Deposit search missed the nearest safe field"
					)
			if cached:
				owner.remove_meta("decision_approaches")
	# Standalone calls must see changed enemy positions and ranges immediately.
	contacts[0].remove_meta("garrison_host")
	for contact in contacts:
		contact.position = Vector3(1000, 0, 1000)
	contacts[0].position = worker.position
	_check(
		economy.danger(worker.global_position_yless, worker, contacts),
		"Live threat was cached across decisions"
	)
	contacts[0].position = Vector3(1000, 0, 1000)
	contacts[1].position = Vector3(1000, 0, 1000)
	_check(
		not economy.danger(worker.global_position_yless, worker, contacts),
		"Moved threat remained in a standalone query"
	)
	game.queue_free()
	paused = false
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Skirmish deposit selection: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _spawn(role, owner, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis.IDENTITY, point), owner)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _safe(resource, worker, hq, observed):
	var point = resource.global_position_yless
	for enemy in observed:
		if not rules.can_target(enemy, worker):
			continue
		var range = rules.range_for(enemy, worker)
		if point.distance_to(enemy.global_position_yless) <= range + 6.0:
			return false
		var closest = Geometry3D.get_closest_point_to_segment(
			enemy.global_position_yless, hq.global_position_yless, point
		)
		if closest.distance_to(enemy.global_position_yless) <= range + 4.0:
			return false
	return true
