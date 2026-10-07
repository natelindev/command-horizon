extends "res://tests/headless/BattlePlanRegression.gd"

var human
var factions
var catalog
var barracks
var spent = Vector2i.ZERO


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	for faction in factions.IDS:
		await _paid_fixture(faction)
		await _queue_guidance()
		if not "--original-only" in OS.get_cmdline_user_args():
			await _paid_progression()
		print("PAID OPENING VERIFIED ", faction, " time=", game.simulation_time, " spent=", spent)
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Opening infantry: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _paid_fixture(faction):
	await _skirmish(faction, "res://source/match/maps/CoastalFoundry.tscn", false)
	human = game._get_human_player()
	spent = Vector2i.ZERO
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var workers = _units(human, "Worker")
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for index in 3:
		var kind = "resource_b" if index == 2 else "resource_a"
		var deposits = get_nodes_in_group("resource_units").filter(func(node): return kind in node)
		deposits.sort_custom(
			func(a, b):
				return (
					workers[index].position.distance_to(a.position)
					< workers[index].position.distance_to(b.position)
				)
		)
		workers[index].issue_manual_order(harvest.new(deposits[index if index < 2 else 0]))
	await _place_paid("Barracks", workers[3])
	await _until(
		func(): return human.has_completed_structure("Barracks"), 120, "Paid Barracks construction"
	)
	barracks = _units(human, "Barracks")[0]
	game.hud._toggle_pause()
	_check(
		plan_rules.next_step(human).id == "defense", "Paid opening did not reach infantry advice"
	)


func _queue_guidance():
	var scene = load(catalog.scene_path("Infantry"))
	var cost = factions.cost(human, "Infantry")
	var funds = Vector2i(human.resource_a, human.resource_b)
	var first = barracks.production_queue.produce(scene)
	_check(first != null, "First paid infantry job failed")
	_check(
		"1 more" in plan_rules.next_step(human).description,
		"One paid infantry did not reduce recommendation"
	)
	var second = barracks.production_queue.produce(scene)
	_check(second != null, "Second paid infantry job failed")
	_check(
		plan_rules.next_step(human).id == "defense_pending",
		"Two paid infantry still invite duplicate purchases"
	)
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - 2 * Vector2i(cost.resource_a, cost.resource_b)
		),
		"Infantry production charged the wrong amount"
	)
	var time = game.simulation_time
	var left = first.time_left
	var paid_funds = Vector2i(human.resource_a, human.resource_b)
	var selected = get_nodes_in_group("selected_units").duplicate()
	for index in 5:
		plan_rules.next_step(human)
	await _frames(12)
	_check(
		game.simulation_time == time and first.time_left == left,
		"Advice advanced paused production"
	)
	_check(
		(
			Vector2i(human.resource_a, human.resource_b) == paid_funds
			and barracks.production_queue.size() == 2
		),
		"Advice changed funds or paid jobs"
	)
	_check(get_nodes_in_group("selected_units") == selected, "Advice changed player selection")
	barracks.production_queue.cancel(first)
	_check(
		"1 more" in plan_rules.next_step(human).description,
		"Cancelled infantry still counted as paid"
	)
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - Vector2i(cost.resource_a, cost.resource_b)
		),
		"Cancellation refund mismatch"
	)
	barracks.production_queue.cancel(second)
	var original = Vector2i(human.resource_a, human.resource_b)
	human.resource_a = cost.resource_a - 1
	human.resource_b = cost.resource_b
	_check(
		"Short: 1 M / 0 E" in plan_rules.next_step(human).description, "Infantry shortage hidden"
	)
	human.resource_a = original.x
	human.resource_b = original.y
	barracks.production_queue.produce(scene)
	barracks.production_queue.produce(scene)
	spent += 2 * Vector2i(cost.resource_a, cost.resource_b)


func _paid_progression():
	game.hud._toggle_pause()
	await _frames(120)
	game.hud._toggle_pause()
	var left = barracks.production_queue.get_elements()[0].time_left
	var time = game.simulation_time
	var capture = Snapshot.new()
	var saved = capture.capture(game)
	var file = "user://opening-infantry-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, saved), "Paid infantry archive write failed")
	var restored = await Restore.new().restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(restored.ok, "Paid infantry archive restore failed")
	game = restored.game
	human = game._get_human_player()
	barracks = _units(human, "Barracks")[0]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	_check(
		plan_rules.next_step(human).id == "defense_pending",
		"Restored paid infantry lost pending advice"
	)
	_check(
		(
			is_equal_approx(barracks.production_queue.get_elements()[0].time_left, left)
			and is_equal_approx(game.simulation_time, time)
		),
		"Archive changed partial paid training"
	)
	game.hud._toggle_pause()
	await _until(func(): return _units(human, "Infantry").size() == 4, 60, "Two paid infantry")
	_check(
		plan_rules.next_step(human).id == "VehicleFactory",
		"Completed infantry did not advance to armor production"
	)
	var builder = _units(human, "Worker")[3]
	await _place_paid("VehicleFactory", builder)
	await _until(
		func(): return human.has_completed_structure("VehicleFactory"), 120, "Paid factory"
	)
	var factory = _units(human, "VehicleFactory")[0]
	var cost = factions.cost(human, "Tank")
	await _until(func(): return human.has_resources(cost), 120, "Harvest for armor")
	_check(plan_rules.next_step(human).id == "armor", "Paid opening skipped conventional armor")
	var job = factory.production_queue.produce(load(catalog.scene_path("Tank")))
	_check(job != null and not job.fitted_chip, "First tank required an unpaid lab or chip")
	spent += Vector2i(cost.resource_a, cost.resource_b)
	_check(
		plan_rules.next_step(human).id == "armor_pending",
		"Paid first tank still invites duplicate spending"
	)
	await _until(func(): return not _units(human, "Tank").is_empty(), 90, "Paid first tank")
	_check(
		plan_rules.next_step(human).id in ["CommandLab", "fund_CommandLab"],
		"Completed tank did not advance to lab: " + plan_rules.next_step(human).id
	)
	await _place_paid("CommandLab", builder)
	await _until(func(): return human.has_completed_structure("CommandLab"), 120, "Paid lab")
	var tank = _units(human, "Tank")[0]
	var fee = factions.chip_cost(human.faction)
	await _until(func(): return human.resource_b >= fee, 90, "Harvest for retrofit")
	_check(plan_rules.next_step(human).id == "retrofit", "Paid lab omitted conventional retrofit")
	_check(tank.program.install_at(_units(human, "CommandCenter")[0]), "Paid retrofit failed")
	spent.y += fee
	await _until(func(): return tank.program.ready_to_run(), 90, "Paid chip installation")
	_check(
		plan_rules.next_step(human).id == "programs", "Installed opening tank omitted program setup"
	)
	tank.program.configure(load("res://source/match/programs/ProgramLibrary.gd").defaults("guard"))
	tank.program.anchor = tank.position
	tank.program.safe_point = tank.position
	_check(tank.program.run(), "Opening guard program rejected")
	await _frames(90)
	_check(tank.program.mode in ["Running", "Waiting"], "Paid opening program never ran")
	_check(_units(human, "Infantry").size() == 4, "Opening overproduced infantry")
	game.hud._toggle_pause()
	print("PAID PATH ", human.faction, " infantry=4 tank=1 chip=true program=", tank.program.mode)
	await _adverse_cases()


func _adverse_cases():
	var opening = load("res://source/match/SkirmishOpening.gd")
	var units = plan_rules.owned_units(human)
	var defenders = _units(human, "Infantry").slice(0, 2)
	var other = _spawn_for_plan("Barracks", human, barracks.position + Vector3(0, 0, 9))
	var scene = load(catalog.scene_path("Infantry"))
	barracks.production_queue.produce(scene)
	other.production_queue.produce(scene)
	units = plan_rules.owned_units(human)
	var advice = opening.infantry(human, units, defenders)
	_check(
		advice.id == "defense_pending" and advice.units.size() == 2,
		"Split paid queues were not combined"
	)
	other.queue_free()
	await _frames(2)
	units = plan_rules.owned_units(human)
	_check(
		"1 more" in opening.infantry(human, units, defenders).description,
		"Destroyed producer still counted"
	)
	_check(
		"2 more" in opening.infantry(human, units, defenders.slice(0, 1)).description,
		"Casualty did not increase demand"
	)
	barracks.production_queue.cancel_all()
	var fillers = []
	while human.population(true) < 100:
		fillers.append(_spawn_for_plan("Worker", human, Vector3(40, 0, 45)))
	units = plan_rules.owned_units(human)
	_check(
		"Unit limit reached" in opening.infantry(human, units, defenders).description,
		"Population limit hidden"
	)
	for unit in fillers:
		unit.queue_free()
	await _frames(2)


func _until(predicate, seconds, label):
	var start = game.simulation_time
	while not predicate.call() and game.simulation_time - start < seconds:
		await _frames(1)
	_check(predicate.call(), label + " did not complete within the simulation deadline")


func _place_paid(role, builder):
	var handler = human.get_node("StructurePlacementHandler")
	var origin = _units(human, "CommandCenter")[0].position
	var cost = factions.cost(human, role, true)
	await _until(func(): return human.has_resources(cost), 180, "Harvest for " + role)
	handler._start_structure_placement(load(catalog.scene_path(role)))
	for radius in [7.0, 11.0, 15.0, 19.0]:
		for index in 16:
			var angle = index * TAU / 16
			handler._active_blueprint_node.global_position = (
				origin + Vector3(cos(angle), 0, sin(angle)) * radius
			)
			if (
				handler._calculate_blueprint_position_validity()
				!= handler.BlueprintPositionValidity.VALID
			):
				continue
			root.get_node("MatchSignals").deselect_all_units.emit()
			builder.get_node("Selection").select()
			var funds = Vector2i(human.resource_a, human.resource_b)
			handler._finish_structure_placement()
			spent += Vector2i(cost.resource_a, cost.resource_b)
			_check(
				(
					Vector2i(human.resource_a, human.resource_b)
					== funds - Vector2i(cost.resource_a, cost.resource_b)
				),
				"Construction charge mismatch"
			)
			return
	handler._cancel_structure_placement()
	_check(false, "No legal paid placement for " + role)
