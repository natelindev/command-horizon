extends "res://tests/headless/SaveRestoreEdges.gd"

var human
var factions
var catalog
var barracks
var spent = Vector2i.ZERO


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	factions = load("res://source/match/FactionCatalog.gd")
	catalog = load("res://source/match/BastionCatalog.gd")
	for faction in factions.IDS:
		await _paid_fixture(faction)
		await _paid_queue()
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
	_check(paused, "Paid opening did not pause after the barracks completed")


func _paid_queue():
	var scene = load(catalog.scene_path("Infantry"))
	var cost = factions.cost(human, "Infantry")
	var funds = Vector2i(human.resource_a, human.resource_b)
	var first = barracks.production_queue.produce(scene)
	_check(first != null, "First paid infantry job failed")
	var second = barracks.production_queue.produce(scene)
	_check(second != null, "Second paid infantry job failed")
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
	await _frames(12)
	_check(
		game.simulation_time == time and first.time_left == left,
		"Pause advanced paid production"
	)
	_check(
		(
			Vector2i(human.resource_a, human.resource_b) == paid_funds
			and barracks.production_queue.size() == 2
		),
		"Pause changed funds or paid jobs"
	)
	_check(get_nodes_in_group("selected_units") == selected, "Pause changed player selection")
	barracks.production_queue.cancel(first)
	_check(barracks.production_queue.size() == 1, "Cancelled infantry remained queued")
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
	_check(barracks.production_queue.produce(scene) == null, "Unaffordable infantry was queued")
	_check(
		human.resource_a == cost.resource_a - 1 and human.resource_b == cost.resource_b,
		"Refused infantry changed funds"
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
	_check(barracks.production_queue.size() == 2, "Restored barracks lost paid infantry")
	_check(
		(
			is_equal_approx(barracks.production_queue.get_elements()[0].time_left, left)
			and is_equal_approx(game.simulation_time, time)
		),
		"Archive changed partial paid training"
	)
	game.hud._toggle_pause()
	await _until(func(): return _units(human, "Infantry").size() == 4, 60, "Two paid infantry")
	var builder = _units(human, "Worker")[3]
	await _place_paid("VehicleFactory", builder)
	await _until(
		func(): return human.has_completed_structure("VehicleFactory"), 120, "Paid factory"
	)
	var factory = _units(human, "VehicleFactory")[0]
	var cost = factions.cost(human, "Tank")
	await _until(func(): return human.has_resources(cost), 120, "Harvest for armor")
	var funds = Vector2i(human.resource_a, human.resource_b)
	var job = factory.production_queue.produce(load(catalog.scene_path("Tank")))
	_check(job != null, "First tank required an unpaid lab")
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds - Vector2i(cost.resource_a, cost.resource_b)
		),
		"First tank charged the wrong price"
	)
	spent += Vector2i(cost.resource_a, cost.resource_b)
	await _until(func(): return not _units(human, "Tank").is_empty(), 90, "Paid first tank")
	await _place_paid("CommandLab", builder)
	await _until(func(): return human.has_completed_structure("CommandLab"), 120, "Paid lab")
	_check(human.lab_research_unlocked(), "Paid factory and lab did not unlock lab research")
	_check(_units(human, "Infantry").size() == 4, "Opening overproduced infantry")
	game.hud._toggle_pause()
	print("PAID PATH ", human.faction, " infantry=4 tank=1 lab=true")


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
