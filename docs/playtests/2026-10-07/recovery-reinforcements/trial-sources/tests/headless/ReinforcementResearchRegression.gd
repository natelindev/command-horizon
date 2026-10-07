extends "res://tests/playtest/ReinforcementFirstMatches.gd"


func _process(_delta):
	return false


func _load_policy():
	plan_rules = load("res://source/match/SkirmishPlan.gd")
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	composition = load("res://source/match/players/skirmish-ai/SkirmishComposition.gd")
	production_policy = load("res://source/match/players/skirmish-ai/SkirmishProduction.gd")
	economy_policy = load("res://source/match/players/skirmish-ai/SkirmishEconomy.gd")
	tech_catalog = load("res://source/match/research/TechnologyCatalog.gd")
	research_policy = "combined"
	army_policy = "screened-air"
	root.get_node("SaveManager").autosaves_enabled = false


func _run():
	_load_policy()
	for faction in factions.IDS:
		await _budget_fixture(faction)
		if is_instance_valid(game):
			paused = false
			game.queue_free()
			await _frames(5)
	for message in _errors:
		push_error(message)
	print("Reinforcement research: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _spawn_fixture(role, index):
	var unit = load(Catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(
		unit, Transform3D(Basis(), Vector3(26 + index * 2, 0, 50)), human, false
	)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _budget_fixture(faction):
	game = await _start(_settings(faction, "helix" if faction != "helix" else "bastion", true))
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	paused = true
	metrics = {}
	vehicle_sequence = 0
	for role in ["Worker", "Infantry"]:
		while plan_rules.owned_units(human).filter(func(unit): return unit.type == role).size() < 6:
			_spawn_fixture(role, human.get_child_count())
	for role in ["AircraftFactory", "Helicopter", "Helicopter", "Drone"]:
		_spawn_fixture(role, human.get_child_count())
	human.coordination_unlocked = true
	human.coordination_left = -1.0
	human.technology.cancel()
	var factory = _unit(human, "VehicleFactory")
	for unit in plan_rules.owned_units(human):
		if unit.get_node_or_null("ProductionQueue") != null:
			unit.production_queue.cancel_all()
	_check(_policy_army().size() == 8, "Expected six infantry and two ground vehicles")
	var request = _reference_requests().filter(func(job): return job.producer == factory)[0]
	var funds = Vector2i(request.cost.resource_a, request.cost.resource_b)
	human.resource_a = funds.x
	human.resource_b = funds.y
	prioritize_reinforcements = false
	_check(
		_reference_research().get("id") == "weapons_1", "Control did not select optional research"
	)
	_produce()
	_check(factory.production_queue.size() == 0, "Control failed to reserve optional research")
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Control spent unfunded research")
	prioritize_reinforcements = true
	_check(_reference_research().is_empty(), "Optional research retained below-assault reserve")
	_produce()
	_check(
		factory.production_queue.size() == 1,
		"Reinforcement policy did not buy affordable ninth unit"
	)
	_check(
		human.resource_a == 0 and human.resource_b == 0, "Reinforcement payment differs from price"
	)
	var snapshot = _research_snapshot()[0]
	_check(
		snapshot.queues.any(
			func(row): return row.producer == "VehicleFactory" and row.jobs.size() == 1
		),
		"Telemetry omitted paid queue"
	)
	factory.production_queue.cancel_all()
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Reinforcement refund differs")
	var ninth = _spawn_fixture("Infantry", human.get_child_count())
	_check(
		_reference_research().get("id") == "weapons_1",
		"Ready army did not restore optional research"
	)
	relay_protected = [ninth]
	_check(_reference_research().is_empty(), "Expedition member counted toward assault reserve")
	relay_protected.clear()
	ninth.queue_free()
	await _frames(2)
	human.coordination_unlocked = false
	_check(
		_reference_research().get("id") == "coordination",
		"Reinforcement policy blocked Coordination"
	)
	human.coordination_unlocked = true
	# Restart the isolated exact-price purchase after the cancellation check;
	# the ordinary sequence intentionally advances when the first job is paid.
	vehicle_sequence = 0
	_produce()
	_check(factory.production_queue.size() == 1, "Missing paid archive fixture")
	if factory.production_queue.size() != 1:
		return
	var builder = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = builder.capture(game)
	var id = builder._reference(factory)
	var left = factory.production_queue.get_elements()[0].time_left
	var path = "user://reinforcement-%d.json" % OS.get_process_id()
	var files = load("res://source/match/saves/SaveFile.gd").new()
	_check(files.write_file(path, data), "Paid reinforcement archive failed")
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await restore.restore(self, files.read_file(path))
	DirAccess.remove_absolute(path)
	_check(result.ok, "Paid reinforcement reload failed")
	game = result.game
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	factory = restore.entities[id]
	await _frames(60)
	_check(
		factory.production_queue.get_elements()[0].time_left == left,
		"Paused reload advanced production"
	)
	_check(human.resource_a == 0 and human.resource_b == 0, "Paused reload duplicated paid funds")
	var before = plan_rules.owned_units(human)
	var started = game.simulation_time
	var completed = -1.0
	paused = false
	for frame in 1800:
		await physics_frame
		if plan_rules.owned_units(human).any(
			func(unit): return unit.type == "Tank" and unit not in before
		):
			completed = game.simulation_time - started
			break
	_check(completed > 0, "Paid ninth unit never completed")
	print("REINFORCEMENT ", faction, " paid=", funds, " delivered=", completed)
	game.queue_free()
	await _frames(5)
