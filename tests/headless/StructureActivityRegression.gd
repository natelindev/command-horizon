extends "res://tests/headless/SaveRestoreEdges.gd"

var factions
var human
var departure_type


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	departure_type = load("res://source/match/effects/ProductionDeparture.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions.IDS:
		await _fixture(faction)
		await _construction()
		await _research()
		for pair in [
			["Barracks", "Infantry"],
			["CommandCenter", "Worker"],
			["VehicleFactory", "Tank"],
			["AircraftFactory", "Helicopter"]
		]:
			await _departure(pair[0], pair[1])
		await _blocked_exit()
		await _archive_and_pause()
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Structure activity and departures: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fixture(faction):
	await _skirmish(faction)
	human = game._get_human_player()
	human.resource_a = 10000
	human.resource_b = 10000
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.repair_service.set_physics_process(false)


func _spawn(role, point, foundation = false):
	var unit = load(factions.Bastion.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), human, foundation)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _construction():
	for role in factions.Bastion.STRUCTURES:
		var building = _spawn(role, Vector3(40, 0, 12), true)
		await _frames(2)
		var activity = building.get_node("StructureActivity")
		activity.refresh(.1)
		_check(
			activity.state == "construction" and building.has_node("ConstructionVisual"),
			"Missing construction state: " + role
		)
		_check(
			activity.find_children("*", "Label3D", true, false).is_empty(),
			"Activity adds floating text"
		)
		var rest = building.get_node("Geometry").transform
		building.construct(.4)
		activity.refresh(.1)
		_check(is_equal_approx(activity.progress, .4), "Construction progress differs")
		building.construct(1.0)
		activity.refresh(.1)
		await _frames(1)
		_check(
			activity.state == "idle" and not building.has_node("ConstructionVisual"),
			"Completed scaffold persists"
		)
		_check(
			building.get_node("Geometry").transform == rest, "Activity moves structure foundation"
		)
		building.queue_free()
		await _frames(3)


func _research():
	var lab = _units(human, "CommandLab")[0]
	var activity = lab.get_node("StructureActivity")
	_check(human.technology.start("weapons_1", lab), "Research did not start")
	activity.refresh(.1)
	_check(activity.state == "research", "Lab lacks researching state")
	human.technology._physics_process(2.0)
	activity.refresh(.1)
	_check(activity.progress > 0, "Research progress is frozen")
	_check(activity._sensor != null, "Lab lacks an animated sensor")
	if activity._sensor != null:
		var rotation = activity._sensor.rotation
		activity.refresh(.2)
		_check(activity._sensor.rotation != rotation, "Research sensor does not turn")
	_check(activity._lamps.any(func(lamp): return lamp.visible), "Research lights stay dark")
	activity.refresh(1.0)
	var brightness = activity._glow.emission_energy_multiplier
	for frame in range(120):
		activity.refresh(1.0 / 60.0)
		_check(
			is_equal_approx(activity._glow.emission_energy_multiplier, brightness),
			"Steady research light pulses"
		)
		_check(activity._lamps.all(func(lamp): return lamp.visible), "Task light blinks away")
	human.technology.cancel()
	activity.refresh(.1)
	_check(activity.state == "idle", "Cancelled research still animates")
	_check(
		(
			activity._glow.emission_energy_multiplier > 0
			and activity._glow.emission_energy_multiplier < brightness
		),
		"Task lighting switches off abruptly"
	)
	activity.refresh(1.0)
	_check(activity._glow.emission_energy_multiplier == 0, "Idle task lighting stays lit")
	human.coordination_unlocked = false
	human.coordination_left = 15.0
	activity.refresh(.1)
	_check(
		activity.state == "research" and is_equal_approx(activity.progress, .5),
		"Coordination lacks research state"
	)
	human.coordination_unlocked = true
	human.coordination_left = -1.0


func _departure(producer_role, role):
	var building = _spawn(producer_role, Vector3(40, 0, 12))
	await _frames(30)
	var queue = building.production_queue
	var before = _units(human, role)
	var element = queue.produce(load(factions.Bastion.scene_path(role)))
	_check(element != null, "Could not enqueue " + role)
	if element == null:
		building.queue_free()
		return
	var seconds = departure_type.seconds(element)
	queue._process((element.time_total - seconds * .8) / human.production_factor())
	_check(is_instance_valid(queue.departure), "Missing departure model: " + role)
	_check(not queue.exit_blocked, "Clear test exit reported blocked: " + role)
	if not is_instance_valid(queue.departure) or queue.exit_blocked:
		queue.cancel_all()
		building.queue_free()
		await _frames(4)
		return
	var start = queue.departure.global_position
	var endpoint = queue.departure.endpoint
	_check(
		_units(human, role).size() == before.size(), "Live unit appeared before departure finished"
	)
	queue._process(seconds * .3 / human.production_factor())
	_check(start.distance_to(queue.departure.global_position) > .05, "Departure does not move")
	building.get_node("StructureActivity").refresh(.3)
	_check(
		building.get_node("StructureActivity").state == "production", "Producer lacks active state"
	)
	queue._process(100)
	var produced = _units(human, role).filter(func(unit): return unit not in before)
	_check(produced.size() == 1 and queue.size() == 0, "Completion duplicates or loses unit")
	if produced.size() == 1:
		produced[0].process_mode = Node.PROCESS_MODE_DISABLED
		_check(
			produced[0].global_position.distance_to(endpoint) < .05,
			"Unit teleports at departure handoff"
		)
		produced[0].queue_free()
	building.queue_free()
	await _frames(4)


func _blocked_exit():
	var building = _spawn("VehicleFactory", Vector3(40, 0, 12))
	await _frames(30)
	var queue = building.production_queue
	var element = queue.produce(load(factions.Bastion.scene_path("Tank")))
	var seconds = departure_type.seconds(element)
	queue._process((element.time_total - seconds * .95) / human.production_factor())
	_check(not queue.exit_blocked, "Blocking fixture starts obstructed")
	if queue.exit_blocked:
		building.queue_free()
		return
	var obstruction = _spawn("Tank", queue.departure.endpoint)
	await _frames(3)
	obstruction.global_position = queue.departure.endpoint
	var left = element.time_left
	queue._process(1.0)
	_check(queue.exit_blocked and element.time_left == left, "Blocked exit consumes paid job")
	building.get_node("StructureActivity").refresh(.1)
	_check(
		building.get_node("StructureActivity").state == "blocked",
		"Blocked exit has no visible state"
	)
	obstruction.queue_free()
	await _frames(3)
	queue._process(.1)
	_check(not queue.exit_blocked and element.time_left < left, "Cleared exit does not resume")
	var funds = Vector2i(human.resource_a, human.resource_b)
	var cost = element.paid_cost
	queue.cancel(element)
	_check(
		(
			human.resource_a == funds.x + cost.resource_a
			and human.resource_b == funds.y + cost.resource_b
		),
		"Departure cancellation loses refund"
	)
	_check(queue.departure == null, "Cancelled departure model persists")
	building.queue_free()
	await _frames(4)


func _archive_and_pause():
	var building = _spawn("Barracks", Vector3(40, 0, 12))
	await _frames(30)
	var queue = building.production_queue
	var job = queue.produce(load(factions.Bastion.scene_path("Infantry")))
	queue._process((job.time_total - departure_type.seconds(job) * .5) / human.production_factor())
	if queue.exit_blocked:
		_check(false, "Archive fixture exit blocked")
		building.queue_free()
		return
	var obstruction = _spawn("Tank", queue.departure.endpoint)
	await _frames(3)
	obstruction.global_position = queue.departure.endpoint
	queue._process(.1)
	_check(queue.exit_blocked, "Archive obstruction did not block exit")
	var point = queue.departure.global_position
	var left = job.time_left
	var funds = Vector2i(human.resource_a, human.resource_b)
	building.get_node("RallyPoint").position = Vector3(0, 0, -7)
	paused = true
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var id = builder._reference(building)
	var obstruction_id = builder._reference(obstruction)
	var legacy = data.duplicate(true)
	legacy.snapshot_version = 11
	legacy.erase("rounds")
	for legacy_unit in legacy.units:
		legacy_unit.projectiles = []
		legacy_unit.erase("air")
	for stance_unit in legacy.units:
		stance_unit.erase("stance")
	for saved in legacy.neutral_buildings:
		saved.erase("owner")
	for saved in legacy.units:
		for old_job in saved.production.get("jobs", []):
			old_job.erase("departure_endpoint")
	_check(
		load("res://source/match/saves/SnapshotSchema.gd").new().validate(legacy),
		"Legacy queue rejected"
	)
	var restore = Restore.new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Mid-departure restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		paused = false
		return
	game = loaded.game
	human = game._get_human_player()
	building = restore.entities[id]
	queue = building.production_queue
	job = queue.get_elements()[0]
	_check(is_instance_valid(queue.departure), "Paused load loses departure visual")
	_check(queue.exit_blocked, "Blocked departure resumed during load")
	_check(queue.departure.global_position.distance_to(point) < .05, "Paused load moves departure")
	_check(
		building.get_node("StructureActivity")._door_open == 1.0, "Paused load closes exit doors"
	)
	var restored_point = queue.departure.global_position
	await _frames(12)
	_check(
		job.time_left == left and queue.departure.global_position == restored_point,
		"Pause advances departure"
	)
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Restore recharges paid job")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	restore.entities[obstruction_id].queue_free()
	for power in _units(human, "PowerPlant") + _units(human, "CommandCenter"):
		power.queue_free()
	await _frames(3)
	_check(human.production_factor() == .35, "Low-power fixture still powered")
	queue._process(.2)
	_check(is_equal_approx(left - job.time_left, .07), "Low power departure has wrong speed")
	var before = _units(human, "Infantry")
	queue._process(100)
	var produced = _units(human, "Infantry").filter(func(unit): return unit not in before)
	_check(produced.size() == 1, "Restored departure lost unit")
	if produced.size() == 1:
		_check(produced[0].action != null, "Departure lost rally order")
		produced[0].process_mode = Node.PROCESS_MODE_DISABLED
	var next = queue.produce(load(factions.Bastion.scene_path("Infantry")))
	queue._process((next.time_total - .8) / human.production_factor())
	var proxy = weakref(queue.departure)
	building.queue_free()
	await _frames(3)
	_check(proxy.get_ref() == null, "Destroyed producer leaves departure model")
	paused = false
