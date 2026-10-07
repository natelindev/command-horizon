extends "res://tests/headless/SaveRestoreEdges.gd"

var factions
var catalog


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _roster(faction)
		await _archive_roster(faction)
	for message in errors:
		push_error(message)
	print("Roster information: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _roster(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	var player = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.hud._toggle_pause()
	var factory = _units(player, "VehicleFactory")[0]
	var menus = _select(factory)
	var tank = _entry(menus, "Tank")
	var heavy = _entry(menus, "AdvancedTank")
	_check(heavy.button.disabled, "Unresearched heavy unit can be ordered")
	_check(
		heavy.button.tooltip_text.contains(factions.title(faction, "AdvancedTank")),
		faction + ": locked unit lost its identity"
	)
	_check(
		heavy.button.tooltip_text.contains(factions.description(faction, "AdvancedTank")),
		faction + ": locked unit lost its role description"
	)
	_check(heavy.button.tooltip_text.contains("Coordination"), "Missing research requirement")
	for role in catalog.NAMES:
		_check(
			not factions.description(faction, role).contains("Helix specialist"),
			"Generic role description: " + role
		)
	player.resource_a = 5
	player.resource_b = 1
	factory.production_queue.fit_chips = true
	menus._refresh_buttons()
	var price = factions.cost(player, "Tank")
	price.resource_b += 4
	_check(tank.button.disabled, "Unaffordable fitted armor is enabled")
	_check(
		tank.button.accessibility_description == tank.button.tooltip_text,
		"Accessible roster details are stale"
	)
	_check(
		tank.button.tooltip_text.contains(factions.description(faction, "Tank")),
		faction + ": unaffordable unit lost its role description"
	)
	_check(
		tank.button.tooltip_text.contains(
			"Short: %d M / %d E" % [price.resource_a - 5, price.resource_b - 1]
		),
		faction + ": missing resources are not distinguished from total price"
	)
	await _review_roster(player, "shortage")
	var time = game.simulation_time
	var actions = _units(player, "Worker").map(func(unit): return unit.action)
	var funds = Vector2i(player.resource_a, player.resource_b)
	for index in 10:
		menus._refresh_buttons()
	_check(Vector2i(player.resource_a, player.resource_b) == funds, "Inspection spent funds")
	_check(factory.production_queue.size() == 0, "Inspection queued a purchase")
	_check(game.simulation_time == time, "Inspection advanced tactical pause")
	_check(
		_units(player, "Worker").map(func(unit): return unit.action) == actions,
		"Inspection issued orders"
	)
	player.resource_a = 1000
	player.resource_b = 1000
	menus._refresh_buttons()
	_check(not tank.button.disabled, "Affordable fitted armor remains disabled")
	var before = Vector2i(player.resource_a, player.resource_b)
	menus._activate("Tank", false)
	var jobs = factory.production_queue.get_elements()
	_check(jobs.size() == 1, "Available roster choice did not buy one job")
	if not jobs.is_empty():
		var job = jobs[0]
		_check(job.paid_cost == price, "Displayed fitted price differs from paid price")
		_check(
			(
				Vector2i(player.resource_a, player.resource_b)
				== before - Vector2i(price.resource_a, price.resource_b)
			),
			"Purchase charged the wrong resources"
		)
		_check(
			tank.button.tooltip_text.contains(
				"%d s" % ceili(job.time_total / player.production_factor())
			),
			"Displayed production time differs from actual job"
		)
		factory.production_queue.cancel(job)
		_check(
			Vector2i(player.resource_a, player.resource_b) == before,
			"Refund changed the paid price"
		)
	await _review_roster(player, "available")
	await _blocked_roster(player, menus, factory)
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _blocked_roster(player, menus, factory):
	var airfield = load(catalog.scene_path("AircraftFactory")).instantiate()
	game._setup_and_spawn_unit(airfield, Transform3D(Basis(), Vector3(38, 0, 20)), player, false)
	var power = _units(player, "PowerPlant")[0]
	power.queue_free()
	await _frames(3)
	_check(player.production_factor() < 1.0, "Low-power fixture still has enough supply")
	menus._refresh_buttons()
	var tank = _entry(menus, "Tank")
	var job = factory.production_queue.produce(load(catalog.scene_path("Tank")))
	_check(job != null, "Low power prevented paid production")
	if job != null:
		_check(
			tank.button.tooltip_text.contains(
				"%d s" % ceili(job.time_total / player.production_factor())
			),
			"Low-power time is not reflected in roster information"
		)
		factory.production_queue.cancel(job)
	await _review_roster(player, "low-power")
	for index in 5:
		factory.production_queue.produce(load(catalog.scene_path("Tank")))
	menus._refresh_buttons()
	_check(tank.button.disabled, "Full production queue remains enabled")
	_check(tank.button.tooltip_text.contains("Queue full"), "Queue-cap reason missing")
	_check(
		tank.button.tooltip_text.contains(factions.description(player.faction, "Tank")),
		"Full queue hides role information"
	)
	factory.production_queue.cancel_all()
	var lab = _units(player, "CommandLab")[0]
	lab.queue_free()
	await _frames(3)
	menus._refresh_buttons()
	_check(tank.button.disabled, "Fitted production ignores missing lab")
	_check(
		tank.button.tooltip_text.contains(factions.title(player.faction, "CommandLab")),
		"Missing lab is not named"
	)
	factory.production_queue.fit_chips = false
	menus._refresh_buttons()
	_check(not tank.button.disabled, "Conventional tank incorrectly requires a lab")
	await _review_roster(player, "missing-lab")
	var worker = _units(player, "Worker")[0]
	menus = _select(worker)
	var generator = _entry(menus, "PowerPlant")
	_check(generator.button.tooltip_text.contains("25 power"), "Generator purpose is missing")
	_check(generator.button.tooltip_text.contains("20 s"), "Construction time missing")
	await _review_roster(player, "construction")
	await _limits(player, menus, factory)


func _limits(player, menus, factory):
	var extra = []
	while player.structure_count() < catalog.STRUCTURE_LIMIT:
		var unit = load(catalog.scene_path("PowerPlant")).instantiate()
		game._setup_and_spawn_unit(unit, Transform3D(Basis(), Vector3(60, 0, 40)), player, false)
		extra.append(unit)
	menus._refresh_buttons()
	var generator = _entry(menus, "PowerPlant")
	_check(generator.button.disabled, "Structure cap is ignored by roster availability")
	_check(
		generator.button.tooltip_text.contains("Structure limit reached (40)"),
		"Structure cap reason missing"
	)
	for unit in extra:
		unit.queue_free()
	extra.clear()
	await _frames(3)
	menus = _select(factory)
	while player.population(true) < catalog.POPULATION_LIMIT:
		var unit = load(catalog.scene_path("Drone")).instantiate()
		game._setup_and_spawn_unit(unit, Transform3D(Basis(), Vector3(60, 2, 40)), player, false)
		extra.append(unit)
	menus._refresh_buttons()
	var tank = _entry(menus, "Tank")
	_check(tank.button.disabled, "Population cap is ignored by roster availability")
	_check(
		tank.button.tooltip_text.contains("Unit limit reached (100"),
		"Population cap reason missing"
	)
	var funds = Vector2i(player.resource_a, player.resource_b)
	_check(
		factory.production_queue.produce(load(catalog.scene_path("Tank"))) == null,
		"Production accepted a job beyond the displayed cap"
	)
	_check(
		Vector2i(player.resource_a, player.resource_b) == funds, "Refused production spent funds"
	)
	for unit in extra:
		unit.queue_free()
	await _frames(3)
	menus._refresh_buttons()
	_check(not tank.button.disabled, "Population release did not restore availability")


func _archive_roster(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	var player = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.hud._toggle_pause()
	var factory = _units(player, "VehicleFactory")[0]
	factory.production_queue.fit_chips = true
	var job = factory.production_queue.produce(load(catalog.scene_path("Tank")))
	_check(job != null, "Roster archive could not pay for its job")
	player.resource_a = 5
	player.resource_b = 1
	var menus = _select(factory)
	var expected = _entry(menus, "Tank").button.tooltip_text
	var time = game.simulation_time
	var capture = Snapshot.new()
	var snapshot = capture.capture(game)
	_check(snapshot != null, "Roster archive capture failed: " + capture.error)
	if snapshot != null:
		var file = FileStore.new()
		var archive = "user://roster-info-%d.json" % OS.get_process_id()
		_check(file.write_file(archive, snapshot), "Roster archive write failed")
		var loaded = await Restore.new().restore(self, file.read_file(archive))
		DirAccess.remove_absolute(archive)
		_check(loaded.ok, "Roster archive restoration failed")
		if loaded.ok:
			game = loaded.game
			player = game._get_human_player()
			factory = _units(player, "VehicleFactory")[0]
			menus = _select(factory)
			_check(
				_entry(menus, "Tank").button.tooltip_text == expected,
				"Archive changed displayed costs or shortages"
			)
			_check(
				_entry(menus, "Tank").button.disabled, "Archive enabled an unaffordable purchase"
			)
			_check(
				(
					factory.production_queue.size() == 1
					and factory.production_queue.get_elements()[0].fitted_chip
				),
				"Archive lost the actual paid fitted job"
			)
			_check(paused and game.simulation_time == time, "Roster archive advanced time")
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _select(unit):
	root.get_node("MatchSignals").deselect_all_units.emit()
	unit.get_node("Selection").select()
	var menus = game.find_child("UnitMenus")
	menus._refresh_buttons()
	return menus


func _entry(menus, role):
	return menus._buttons.filter(func(entry): return entry.type == role)[0]


func _review_roster(_player, _label):
	return true
