extends "res://tests/headless/PointOfInterestRegression.gd"

var _production
var _composition
var _site_orders
var _difficulty


func _run():
	_difficulty = load("res://source/match/players/skirmish-ai/SkirmishDifficulty.gd")
	_site_orders = load("res://source/match/players/skirmish-ai/SkirmishSites.gd")
	_composition = load("res://source/match/players/skirmish-ai/SkirmishComposition.gd")
	_production = load("res://source/match/players/skirmish-ai/SkirmishProduction.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _open_sites(faction)
		_enemy.difficulty = _difficulty.EASY
		_game.simulation_time = 900
		_enemy.resource_a = 5000
		_enemy.resource_b = 5000
		for unit in _enemy._units():
			if unit.get_node_or_null("ProductionQueue") != null:
				unit.production_queue.cancel_all()
		var cap = _difficulty.army_cap(_enemy.difficulty, _game.simulation_time)
		var hq = _enemy._units().filter(func(unit): return unit.type == "CommandCenter")[0]
		while _production.army_size(_composition.inventory(_enemy._units())) < cap - 1:
			var tank = _spawn("Tank", _enemy, hq.position + Vector3(8, 0, 8))
			tank.process_mode = Node.PROCESS_MODE_DISABLED
		var camps = _game.map.points_of_interest.filter(func(site): return site.kind == "mercenary")
		for camp in camps:
			camp.captured_by = _enemy
		_check(camps[0].hire(_enemy, "RocketInfantry"), "Cap fixture failed to queue mercenary")
		var requests = _production.requests(_game, _enemy, _enemy._units())
		_check(
			requests.all(func(job): return job.role == "Worker"),
			faction + ": factory production ignored a reserved mercenary slot"
		)
		_site_orders.recruit(_game, _enemy, _enemy._units(), "")
		_check(camps[1].jobs.is_empty(), faction + ": second camp exceeded Easy army cap")
		camps[0].cancel_hire(_enemy)
		requests = _production.requests(_game, _enemy, _enemy._units())
		_check(
			requests.any(func(job): return job.role != "Worker"),
			faction + ": cancelled hire did not release army capacity"
		)
		_game.queue_free()
		await _frames(5)
	for message in _errors:
		push_error(message)
	print("Skirmish army cap: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
