extends "res://tests/headless/SkirmishBudgetRegression.gd"


func _run():
	catalog = load("res://source/match/BastionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", false)
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		paused = true
		var human = game._get_human_player()
		_check(human.power_totals() == Vector2i(8, 0), "HQ should only bootstrap the opening")
		_spawn("Barracks", human, Vector3(30, 0, 20))
		_spawn("VehicleFactory", human, Vector3(30, 0, 30))
		_check(human.production_factor() == 0.35, "Opening factory no longer needs a generator")
		_spawn("PowerPlant", human, Vector3(18, 0, 20))
		_spawn("CommandLab", human, Vector3(30, 0, 40))
		_check(human.production_factor() == 1.0, "One plant cannot support early ground tech")
		_spawn("AircraftFactory", human, Vector3(40, 0, 20))
		_spawn("RepairDepot", human, Vector3(40, 0, 30))
		_spawn("AntiGroundTurret", human, Vector3(40, 0, 40))
		_spawn("AntiAirTurret", human, Vector3(40, 0, 50))
		_check(human.power_totals() == Vector2i(20, 29), "Full base should outgrow one plant")
		_check(human.production_factor() == 0.35, "Full base ignored insufficient power")
		var queue = _units(human, "VehicleFactory")[0].production_queue
		var job = queue.produce(load(catalog.scene_path("Tank")))
		_check(job != null, "Power fixture could not pay for a tank")
		var time_before = job.time_left
		queue._process(1.0)
		_check(
			is_equal_approx(time_before - job.time_left, 0.35),
			"Low power did not slow real production"
		)
		var second = _spawn("PowerPlant", human, Vector3(18, 0, 30))
		second._construction_progress = 0.0
		_check(human.production_factor() == 0.35, "Unfinished generator supplied power")
		second._construction_progress = 1.0
		_check(human.production_factor() == 1.0, "Second generator did not restore full speed")
		time_before = job.time_left
		queue._process(1.0)
		_check(
			is_equal_approx(time_before - job.time_left, 1.0),
			"Restored power did not resume production"
		)
		queue.cancel_all()
		_spawn("VehicleFactory", human, Vector3(50, 0, 20))
		_spawn("AircraftFactory", human, Vector3(50, 0, 30))
		_check(human.power_totals() == Vector2i(32, 43), "Expanded production demand is wrong")
		_check(human.production_factor() == 0.35, "Expanded base did not require a third plant")
		var third = _spawn("PowerPlant", human, Vector3(18, 0, 40))
		_check(human.production_factor() == 1.0, "Third generator did not support expansion")
		third.queue_free()
		_check(human.production_factor() == 0.35, "Destroyed generator still supplies power")
		await _frames(2)
		await _ai_power()
		print("POWER ", faction, " opening / full base / expansion / generator loss verified")
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Power balance: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _ai_power():
	var human = game._get_human_player()
	var opponent = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	_spawn("Barracks", opponent, Vector3(100, 0, 60))
	_spawn("VehicleFactory", opponent, Vector3(100, 0, 70))
	_spawn("CommandLab", opponent, Vector3(100, 0, 80))
	_spawn("PowerPlant", opponent, Vector3(110, 0, 60))
	game.simulation_time = 160
	_check(opponent.power_totals() == Vector2i(20, 14), "AI expansion fixture has wrong power")
	_check(
		opponent._next_building(opponent._units()) == "PowerPlant",
		"AI did not reserve power before adding its air factory"
	)
	_spawn("PowerPlant", opponent, Vector3(110, 0, 70))
	_check(
		opponent._next_building(opponent._units()) == "AircraftFactory",
		"AI kept building generators after funding its next expansion"
	)
