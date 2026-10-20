extends "res://tests/headless/Skirmish.gd"

const MAP_NAMES = ["ExpandedDesertFrontier", "ExpandedAlpineRelay", "ExpandedCoastalFoundry"]
var harvest_script


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest_script = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var selected_factions = ["bastion"] if "--smoke" in OS.get_cmdline_user_args() else factions.IDS
	for faction in factions.IDS:
		if ("--" + faction) in OS.get_cmdline_user_args():
			selected_factions = [faction]
			break
	var selected_maps = (
		MAP_NAMES.slice(0, 1) if "--smoke" in OS.get_cmdline_user_args() else MAP_NAMES
	)
	if "--alpine" in OS.get_cmdline_user_args():
		selected_maps = ["ExpandedAlpineRelay"]
	var starts = [true] if "--advanced" in OS.get_cmdline_user_args() else [false, true]
	for faction in selected_factions:
		for map_name in selected_maps:
			for advanced in starts:
				if (
					"--frozen-only" not in OS.get_cmdline_user_args()
					and "--enemy-only" not in OS.get_cmdline_user_args()
				):
					await _idle_roster(map_name, faction, advanced)
				await _frozen_roster(
					map_name, faction, advanced, "--enemy-only" in OS.get_cmdline_user_args()
				)
	for message in _errors:
		push_error(message)
	print("HQ delivery: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _create_map(map_name, faction, advanced, mirror_faction = false):
	var opponent = faction if mirror_faction else ("helix" if faction != "helix" else "bastion")
	var settings = _settings(faction, opponent, advanced)
	settings.map_path = "res://source/match/maps/%s.tscn" % map_name
	var game = await _start(settings)
	var human = game._get_human_player()
	get_nodes_in_group("players").filter(func(side): return side != human)[0].process_mode = (
		Node.PROCESS_MODE_DISABLED
	)
	return game


func _idle_roster(map_name, faction, advanced):
	var game = await _create_map(map_name, faction, advanced)
	var human = game._get_human_player()
	var worker = _unit(human, "Worker")
	for kind in ["resource_a", "resource_b"]:
		var deposits = get_nodes_in_group("resource_units").filter(func(unit): return kind in unit)
		deposits.sort_custom(
			func(a, b):
				return (
					worker.position.distance_squared_to(a.position)
					< worker.position.distance_squared_to(b.position)
				)
		)
		var funds = human.get(kind)
		worker.issue_manual_order(harvest_script.new(deposits[0]))
		var first_cargo = false
		var maximum_step = 0.0
		for frame in 3600:
			var before = worker.position
			await physics_frame
			maximum_step = maxf(maximum_step, before.distance_to(worker.position))
			first_cargo = first_cargo or worker.get(kind) > 0
			if human.get(kind) >= funds + 4:
				break
		var label = (
			"%s %s %s %s" % [map_name, faction, "advanced" if advanced else "standard", kind]
		)
		_check(
			first_cargo and human.get(kind) >= funds + 4,
			"Idle starting roster blocked income: " + label
		)
		_check(
			maximum_step <= worker.movement_speed / Engine.physics_ticks_per_second + .002,
			"Delivery bypassed movement speed: " + label
		)
		worker.issue_manual_order(null)
		print("DELIVERY idle ", label, " time=", game.simulation_time, " cargo=", worker.get(kind))
	game.queue_free()
	await _frames(3)


func _frozen_roster(map_name, faction, advanced, enemy = false):
	var game = await _create_map(map_name, faction, advanced, enemy)
	var human = game._get_human_player()
	if enemy:
		human = get_nodes_in_group("players").filter(func(side): return side != human)[0]
		human.process_mode = Node.PROCESS_MODE_INHERIT
		human.set_process(false)
	var hq = _unit(human, "CommandCenter")
	for unit in human.get_children():
		if unit.is_in_group("units") and unit.movement_speed > 0:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	var workers = []
	for index in 2:
		var worker = load(Catalog.scene_path("Worker")).instantiate()
		game._setup_and_spawn_unit(
			worker, Transform3D(Basis(), hq.position + Vector3(-2 + index * 4, 0, -5)), human, false
		)
		workers.append(worker)
	await _frames(45)
	var balance = Vector2(human.resource_a, human.resource_b)
	for index in 2:
		var kind = "resource_a" if index == 0 else "resource_b"
		var deposits = get_nodes_in_group("resource_units").filter(func(unit): return kind in unit)
		deposits.sort_custom(
			func(a, b):
				return (
					hq.position.distance_squared_to(a.position)
					< hq.position.distance_squared_to(b.position)
				)
		)
		workers[index].issue_manual_order(harvest_script.new(deposits[0]))
	for frame in 4800:
		await physics_frame
		if human.resource_a >= balance.x + 4 and human.resource_b >= balance.y + 4:
			break
	var label = (
		"%s %s %s %s"
		% [map_name, faction, "advanced" if advanced else "standard", "enemy" if enemy else "human"]
	)
	_check(
		human.resource_a >= balance.x + 4 and human.resource_b >= balance.y + 4,
		"Frozen starting bodies blocked both deliveries: " + label
	)
	print(
		"DELIVERY frozen ",
		label,
		" time=",
		game.simulation_time,
		" workers=",
		workers.map(func(unit): return unit.position)
	)
	game.queue_free()
	await _frames(3)
