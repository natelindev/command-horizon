extends "res://tests/headless/MacroEconomyRegression.gd"


func _run():
	Engine.physics_ticks_per_second = 60
	TranslationServer.set_locale("en")
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	var settings = _settings("helix", "bastion", false)
	settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	game = await _start(settings)
	human = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	human.resource_a = 1000
	human.resource_b = 1000
	var hq = _unit(human, "CommandCenter")
	var factory = _facility("VehicleFactory", Vector3(20, 0, 23))
	var first = _facility("CommandLab", Vector3(26, 0, 23))
	var second = _facility("CommandLab", Vector3(33, 0, 23))
	var generator = _facility("PowerPlant", Vector3(26, 0, 31))
	await _frames(5)
	hq.energy = 100
	_cast(hq, second)
	_check(
		is_equal_approx(human.production_factor(first), 1.0), "Unboosted primary lab accelerated"
	)
	_check(
		is_equal_approx(human.research_factor(), 1.5), "Secondary lab cannot accelerate research"
	)
	_check(human.start_coordination(first), "Could not start paid Coordination at primary lab")
	var before = human.coordination_left
	human._physics_process(1.0)
	_check(
		is_equal_approx(before - human.coordination_left, 1.5), "Coordination ignored secondary lab"
	)
	human.cancel_coordination()
	human.coordination_unlocked = true
	_check(
		human.technology.start("plasma_shields", first), "Could not start paid primary-lab research"
	)
	before = human.technology.left
	human.technology._physics_process(1.0)
	_check(
		is_equal_approx(before - human.technology.left, 1.5),
		"Actual research ignored secondary lab"
	)
	_cast(hq, first)
	_check(
		is_equal_approx(human.research_factor(), 1.5), "Multiple Flux labs stacked multiplicatively"
	)
	human.production_boosts = human.production_boosts.filter(
		func(boost): return boost.target.get_ref() != first
	)
	_cast(hq, factory)
	var job = factory.production_queue.produce(load(factions.scene_path("helix", "Tank")))
	_check(job != null, "Could not pay for Flux production fixture")
	generator.hp = 0
	_check(human.is_brownout(), "Brownout fixture still has sufficient power")
	_check(
		is_equal_approx(human.production_factor(factory), .375),
		"Factory Flux did not compose with brownout"
	)
	_check(is_equal_approx(human.research_factor(), .375), "Lab Flux did not compose with brownout")
	if job != null:
		before = job.time_left
		factory.production_queue._process(1.0)
		_check(
			is_equal_approx(before - job.time_left, .375), "Actual brownout production ignored Flux"
		)
		factory.production_queue.cancel_all()
	before = human.technology.left
	human.technology._physics_process(1.0)
	_check(
		is_equal_approx(before - human.technology.left, .375),
		"Actual brownout research ignored Flux"
	)
	paused = true
	before = human.technology.left
	var left = human.production_boosts.map(func(boost): return boost.left)
	await _frames(15)
	_check(
		(
			human.technology.left == before
			and human.production_boosts.map(func(boost): return boost.left) == left
		),
		"Paused Flux research or boost timer advanced"
	)
	var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new()
	var saved = snapshot.capture(game)
	_check(saved != null, "Flux research snapshot failed: " + snapshot.error)
	if saved != null:
		var first_id = snapshot._reference(first)
		var second_id = snapshot._reference(second)
		var factory_id = snapshot._reference(factory)
		var restore = load("res://source/match/saves/MatchRestore.gd").new()
		var result = await restore.restore(self, saved)
		_check(result.ok, "Flux research restore failed: " + result.get("error", ""))
		if result.ok:
			game = result.game
			human = game._get_human_player()
			first = restore.entities[first_id]
			second = restore.entities[second_id]
			factory = restore.entities[factory_id]
			_check(
				paused and human.technology.left == before, "Paused restore changed research clock"
			)
			_check(
				human.production_boosts.map(func(boost): return boost.left) == left,
				"Restore changed Flux lifetime"
			)
			_check(
				(
					is_equal_approx(human.research_factor(), .375)
					and is_equal_approx(human.production_factor(factory), .375)
				),
				"Restore lost secondary-lab/brownout work composition"
			)
			root.get_node("MatchSignals").deselect_all_units.emit()
			first.get_node("Selection").select()
			await _frames(5)
			var panel = game.find_child("UnitMenus")._research_panel
			panel.refresh()
			var seconds = ceili(human.technology.left / .375)
			_check(
				panel._branches.plasma_shields.button.tooltip_text.contains(
					"Researching · %d s remaining" % seconds
				),
				"Primary lab research tooltip ignores boosted secondary lab"
			)
			game.hud.research_status.refresh()
			_check(
				game.hud.research_status._button.text.contains("%d s" % seconds),
				"Global research ETA ignores Flux"
			)
			paused = false
			before = human.technology.left
			human.technology._physics_process(1.0)
			_check(
				is_equal_approx(before - human.technology.left, .375),
				"Restored research lost composed rate"
			)
			second.hp = 0
			_check(
				is_equal_approx(human.research_factor(), .25),
				"Destroyed boosted lab continued accelerating research"
			)
	paused = false
	game.queue_free()
	await _frames(6)
	for error in _errors:
		push_error(error)
	print("Flux research: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _facility(role, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), human, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _cast(hq, target):
	hq.abilities.get_ability("flux_resonance").cooldown_left = 0
	_check(
		hq.abilities.trigger("flux_resonance", Vector3.INF, target),
		"Flux cast failed: " + target.type
	)
