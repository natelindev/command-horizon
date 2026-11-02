extends "res://tests/headless/Skirmish.gd"

## Two material harvesters per node occupy the home's optimal gathering cohort.
## Two electronics harvesters per node operate alongside them. No upgrades, powers,
## forward refineries, AI, production or resource grants alter the measurement.
const MAPS = ["DesertFrontier", "Emberworks", "AlpineRelay"]
const LIMIT_SECONDS = 900.0
var _records = []
var _harvest


func _run():
	Engine.physics_ticks_per_second = 60
	seed(1817)
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	_harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var maps = MAPS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pacing-map="):
			maps = argument.trim_prefix("--pacing-map=").split(",")
	for map_name in maps:
		for faction in _cohort_factions():
			await _cohort(map_name, faction)
	_save_report()
	for error in _errors:
		push_error(error)
	print("Home field pacing: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _cohort_factions():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pacing-faction="):
			return argument.trim_prefix("--pacing-faction=").split(",")
	return ["bastion", "helix", "frontier"]


func _save_report():
	var report = {
		"physics_hz": Engine.physics_ticks_per_second,
		"workers_per_node": 2,
		"native": "--enable-native-kernels" in OS.get_cmdline_user_args(),
		"records": _records,
		"failures": _errors
	}
	DirAccess.make_dir_recursive_absolute("res://art/economy")
	var report_path = "res://art/economy/home-field-pacing.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pacing-report="):
			report_path = argument.trim_prefix("--pacing-report=")
	var output = FileAccess.open(report_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()


func _cohort(map_name, faction):
	var settings = _settings(faction, "bastion", false)
	settings.map_path = (
		"res://source/match/maps/%s.tscn" % map_name.trim_prefix("legacy:")
		if map_name.begins_with("legacy:")
		else "res://source/match/maps/battlefields/%sMap.tscn" % map_name
	)
	settings.battlefield_events = false
	var game = await _start(settings)
	var player = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var hq = _unit(player, "CommandCenter")
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
		else:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(5)
	var deposits = _home_deposits(hq)
	var materials = deposits.filter(func(deposit): return "resource_a" in deposit)
	var electronics = deposits.filter(func(deposit): return "resource_b" in deposit)
	_check(not materials.is_empty() and not electronics.is_empty(), map_name + " home field empty")
	var origin = Vector3.ZERO
	for deposit in materials:
		origin += deposit.global_position
	origin /= materials.size()
	var material_workers = materials.size() * 2
	var electronics_workers = electronics.size() * 2
	var initial = _remaining(materials, "resource_a")
	var cohort = []
	var toward = (origin - hq.global_position).normalized()
	for index in material_workers + electronics_workers:
		var worker = load(Catalog.scene_path("Worker")).instantiate()
		var point = hq.global_position + toward.rotated(Vector3.UP, (index - 6.5) * .16) * 5.0
		point = game.navigation.terrain.closest_point(point)
		game._setup_and_spawn_unit(worker, Transform3D(Basis(), point), player, false)
		cohort.append(worker)
	await _frames(90)
	if "--enable-native-kernels" in OS.get_cmdline_user_args():
		_check(
			(
				cohort[0]._native_state != null
				and cohort[0].get_node("Movement")._native_runtime != null
			),
			"Pacing cohort failed to bind native movement"
		)
	var before = player.resource_a
	var before_e = player.resource_b
	var start = game.simulation_time
	for index in cohort.size():
		var targets = materials if index < material_workers else electronics
		cohort[index].issue_manual_order(_harvest.new(targets[index % targets.size()]))
	var expansion_at = -1.0
	var exhausted_at = -1.0
	var samples = []
	var next_sample = 60.0
	var previous_remaining = initial
	var progress_at = 0.0
	var longest_stall = 0.0
	var previous_states = {}
	var phase_deliveries = 0
	var state_seconds = {}
	var phase_arrivals = []
	var previous_elapsed = 0.0
	for frame in int(LIMIT_SECONDS * 60):
		await physics_frame
		var elapsed = game.simulation_time - start
		var dt = elapsed - previous_elapsed
		previous_elapsed = elapsed
		var remaining = _remaining(materials, "resource_a")
		if remaining < previous_remaining:
			progress_at = elapsed
		previous_remaining = remaining
		longest_stall = maxf(longest_stall, elapsed - progress_at)
		for worker in cohort.slice(0, material_workers):
			var state = worker.action._state
			var key = _harvest.State.keys()[state]
			state_seconds[key] = state_seconds.get(key, 0.0) + dt
			if (
				previous_states.get(worker, -1) == _harvest.State.PHASE_RETURN
				and state != _harvest.State.PHASE_RETURN
				and phase_arrivals.size() < 20
			):
				phase_arrivals.append(
					{
						"position": [worker.global_position.x, worker.global_position.z],
						"hq_distance":
						worker.global_position_yless.distance_to(hq.global_position_yless),
						"deposit_distance":
						(
							worker.global_position_yless.distance_to(
								worker.action._resource_unit.global_position_yless
							)
							if is_instance_valid(worker.action._resource_unit)
							else -1.0
						),
						"speed": worker.get_node("Movement").speed
					}
				)
			if state == _harvest.State.PHASE_RETURN and previous_states.get(worker, -1) != state:
				phase_deliveries += 1
			previous_states[worker] = state
		if expansion_at < 0 and remaining <= initial * .4:
			expansion_at = elapsed
		if elapsed >= next_sample:
			var nodes = materials.map(
				func(deposit): return deposit.resource_a if is_instance_valid(deposit) else 0
			)
			samples.append({"seconds": elapsed, "materials_left": remaining, "nodes": nodes})
			print(
				"PACING ", map_name, " ", faction, " t=", snappedf(elapsed, .1), " left=", remaining
			)
			next_sample += 60
		if remaining == 0:
			exhausted_at = elapsed
			break
	var record = {
		"map": map_name,
		"faction": faction,
		"initial_materials": initial,
		"harvester_speed": cohort[0].movement_speed,
		"material_workers": material_workers,
		"electronics_workers": electronics_workers,
		"expansion_seconds": expansion_at,
		"depletion_seconds": exhausted_at,
		"delivered_materials": player.resource_a - before,
		"delivered_electronics": player.resource_b - before_e,
		"longest_gather_stall_seconds": longest_stall,
		"material_phase_deliveries": phase_deliveries,
		"worker_state_seconds": state_seconds,
		"first_phase_arrivals": phase_arrivals,
		"samples": samples
	}
	_records.append(record)
	print("PACING RESULT ", JSON.stringify(record))
	_check(
		exhausted_at >= 420 and exhausted_at <= 540,
		(
			"%s %s home material field depleted in %.1fs, expected 420–540s"
			% [map_name, faction, exhausted_at]
		)
	)
	_check(player.resource_b > before_e, faction + " electronics cohort failed to gather")
	_check(longest_stall < 15.0, faction + " home cohort stalled instead of gathering")
	_save_report()
	game.queue_free()
	await _frames(6)


func _home_deposits(hq) -> Array:
	var all = get_nodes_in_group("resource_units")
	var materials = all.filter(func(deposit): return "resource_a" in deposit)
	materials.sort_custom(
		func(a, b):
			return (
				a.global_position.distance_squared_to(hq.global_position)
				< b.global_position.distance_squared_to(hq.global_position)
			)
	)
	var nearest = materials[0]
	if nearest.harvest_origin.is_finite():
		return all.filter(
			func(deposit): return deposit.harvest_origin.is_equal_approx(nearest.harvest_origin)
		)
	var centre = Vector3.ZERO
	var home = materials.filter(
		func(deposit): return deposit.global_position.distance_to(nearest.global_position) < 10.0
	)
	for deposit in home:
		centre += deposit.global_position
	centre /= home.size()
	return all.filter(func(deposit): return deposit.global_position.distance_to(centre) < 12.0)


func _remaining(deposits, property) -> int:
	var amount = 0
	for deposit in deposits:
		if is_instance_valid(deposit) and not deposit.is_queued_for_deletion():
			amount += deposit.get(property)
	return amount
