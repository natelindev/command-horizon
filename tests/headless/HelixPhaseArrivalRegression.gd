extends "res://tests/headless/MacroEconomyRegression.gd"


func _run():
	Engine.physics_ticks_per_second = 60
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var settings = _settings("helix", "bastion", false)
	settings.map_path = "res://source/match/maps/CoastalFoundry.tscn"
	game = await _start(settings)
	game.set_physics_process(false)
	human = game._get_human_player()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var worker = _unit(human, "Worker")
	worker.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(90)
	if "--native-crowd-runtime" in OS.get_cmdline_user_args():
		_check(
			worker.get_node("Movement")._native_handle >= 0,
			"Phase arrival probe disabled native binding"
		)
	var hq = _unit(human, "CommandCenter")
	var origin = game.map.get_meta("home_field_plans")[0].origin
	var materials = get_nodes_in_group("resource_units").filter(
		func(node):
			return (
				"resource_a" in node
				and Vector2(node.harvest_origin.x, node.harvest_origin.z).distance_to(origin) < .01
			)
	)
	_check(materials.size() == 5, "Phase arrival probe lost original coastal home")
	for deposit in materials:
		worker.issue_manual_order(null)
		var point = deposit.global_position + Vector3(0, 0, 1.5)
		worker.get_node("Movement").relocate(point)
		worker.resource_a = 4
		worker.issue_manual_order(harvest.new(hq))
		await _frames(1)
		var arrival = worker.action._phase_arrival_point()
		_check(arrival.is_finite(), "A clear coastal HQ has no phase arrival")
		if arrival.is_finite():
			var forward = (worker.global_position_yless - hq.global_position_yless).normalized()
			var radial = (arrival * Vector3(1, 0, 1) - hq.global_position_yless).normalized()
			_check(
				radial.dot(forward) > .75,
				"Phase chose far-side inner ring over clear field-facing outer ring"
			)
			_check(
				arrival.distance_to(point) < point.distance_to(hq.global_position),
				"Phase return lengthens the next field leg"
			)
		worker.issue_manual_order(null)
	worker.resource_a = 0
	game.queue_free()
	await _frames(6)
	for error in _errors:
		push_error(error)
	print("Helix field-facing phase arrival: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
