extends "res://tests/headless/SaveRestoreEdges.gd"

const ARCHIVE = "res://docs/playtests/2026-10-03/skirmish-stationary-battle.json"
const JAM_POINT = Vector3(108.9, 0, 67.14993)
var harvest_action


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	harvest_action = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for repetition in 3:
		await _archived_traffic(repetition)
	for faction in ["bastion", "helix"]:
		await _paired_harvesting(faction)
	for error in errors:
		push_error(error)
	print("Crowd boundary regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _archived_traffic(repetition):
	var file = FileStore.new()
	var loaded = await Restore.new().restore(self, file.read_file(ARCHIVE))
	_check(loaded.ok, "Could not restore crowd archive")
	if not loaded.ok:
		return
	game = loaded.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var workers = get_nodes_in_group("units").filter(func(unit): return unit.type == "Worker")
	workers.sort_custom(
		func(a, b): return a.position.distance_to(JAM_POINT) < b.position.distance_to(JAM_POINT)
	)
	var worker = workers[0]
	var start = worker.position
	var clock = game.simulation_time
	await _frames(30)
	_check(game.simulation_time == clock and worker.position == start, "Paused traffic moved")
	await _review_traffic(worker, "archive-before")
	paused = false
	var observed_cargo = false
	var maximum_step = 0.0
	var previous = start
	var travel_at_ten = 0.0
	for frame in Engine.physics_ticks_per_second * 15:
		await physics_frame
		if not is_instance_valid(worker):
			_check(false, "Archived engineer died before its travel check")
			break
		maximum_step = maxf(maximum_step, worker.position.distance_to(previous))
		previous = worker.position
		observed_cargo = observed_cargo or worker.resource_b > 0
		# Measure departure, not displacement after a worker has returned cargo.
		if frame < Engine.physics_ticks_per_second * 10:
			travel_at_ten = maxf(travel_at_ten, worker.position.distance_to(start))
	if is_instance_valid(worker):
		var travel = travel_at_ten
		print("ARCHIVED TRAFFIC ", repetition, " travel=", travel, " cargo=", observed_cargo)
		_check(travel > 8, "Archived engineer remained stuck at the base boundary")
		_check(observed_cargo, "Archived engineer did not reach electronics within fifteen seconds")
		_check(
			maximum_step < worker.movement_speed / Engine.physics_ticks_per_second + .002,
			"Recovery teleported engineer"
		)
		await _review_traffic(worker, "archive-after")
	paused = false
	game.queue_free()
	await _frames(5)
	game = null


func _paired_harvesting(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", false)
	var human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	paused = true
	for unit in get_nodes_in_group("units"):
		unit.queue_free()
	await _frames(10)
	var enemy = get_nodes_in_group("players").filter(func(player): return player != human)[0]
	_traffic_unit("CommandCenter", enemy, Vector3(18, 0, 27))
	for item in [
		["CommandCenter", Vector3(110, 0, 70)],
		["VehicleFactory", Vector3(104.4567, 0, 67.7039)],
		["RepairDepot", Vector3(110, 0, 64)]
	]:
		_traffic_unit(item[0], human, item[1])
	paused = false
	await _frames(90)
	var outward = _traffic_unit("Worker", human, JAM_POINT)
	var returning = _traffic_unit("Worker", human, Vector3(108.174, 0, 66.15162))
	await _frames(5)
	var deposits = get_nodes_in_group("resource_units")
	var electronics = deposits.filter(func(unit): return "resource_b" in unit)
	var materials = deposits.filter(func(unit): return "resource_a" in unit)
	electronics.sort_custom(
		func(a, b):
			return (
				a.position.distance_to(Vector3(108, 0, 52))
				< b.position.distance_to(Vector3(108, 0, 52))
			)
	)
	materials.sort_custom(
		func(a, b): return a.position.distance_to(JAM_POINT) < b.position.distance_to(JAM_POINT)
	)
	returning.resource_a = 4
	outward.issue_manual_order(harvest_action.new(electronics[0]))
	returning.issue_manual_order(harvest_action.new(materials[0]))
	var funds = Vector2(human.resource_a, human.resource_b)
	await _review_traffic(outward, faction + "-before")
	await _frames(1800)
	paused = true
	var snapshotter = Snapshot.new()
	var snapshot = snapshotter.capture(game)
	_check(snapshot != null, "Paired traffic snapshot failed")
	if snapshot == null:
		quit(1)
		return
	var worker_id = snapshotter._reference(outward)
	var point = outward.position
	var cargo = Vector2(outward.resource_a, outward.resource_b)
	var file = FileStore.new()
	var archive = "user://crowd-boundary-%d.json" % OS.get_process_id()
	_check(file.write_file(archive, snapshot), "Paired traffic archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(loaded.ok, "Paired traffic restore failed")
	if not loaded.ok:
		quit(1)
		return
	game = loaded.game
	human = game._get_human_player()
	outward = restore.entities[worker_id]
	await _frames(30)
	_check(
		(
			outward.position.is_equal_approx(point)
			and Vector2(outward.resource_a, outward.resource_b) == cargo
		),
		"Paused traffic restoration changed position or cargo"
	)
	_check(
		is_instance_of(outward.action, harvest_action), "Restored engineer lost its harvest order"
	)
	paused = false
	await _frames(1800)
	var income = Vector2(human.resource_a, human.resource_b) - funds
	print("PAIRED TRAFFIC ", faction, " income=", income)
	_check(
		income.x >= 8 and income.y >= 8, "Opposing engineer traffic did not deliver both resources"
	)
	await _review_traffic(outward, faction + "-after")
	game.queue_free()
	await _frames(5)
	game = null


func _traffic_unit(role, player, point):
	var catalog = load("res://source/match/BastionCatalog.gd")
	var unit = load(catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _review_traffic(_worker, _label):
	return true
