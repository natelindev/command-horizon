extends "res://tests/headless/HQTrafficRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _fresh(faction)
	for message in errors:
		push_error(message)
	print("HQ faction traffic: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fresh(faction):
	await _skirmish(faction, "res://source/match/maps/IndustrialCrossroads.tscn", false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.queue_free()
	await _frames(5)
	var player = game._get_human_player()
	for item in [
		["Barracks", Vector3(14, 0, 57)],
		["VehicleFactory", Vector3(9.050253, 0, 54.94975)],
		["CommandLab", Vector3(9.050253, 0, 45.05025)],
		["RepairDepot", Vector3(7, 0, 50)]
	]:
		_actor(item[0], player, item[1])
	await _frames(90)
	var points = [Vector3(13.676306, 0, 53.100002), Vector3(13.59892, 0, 54.37766)]
	var actors = points.map(func(point): return _actor("Worker", player, point))
	await _frames(10)
	var move_script = load("res://source/match/units/actions/Moving.gd")
	var targets = [Vector3(9.519184, 0, 48.143986), Vector3(26, 0, 64)]
	for index in actors.size():
		actors[index].position = points[index]
		actors[index].issue_manual_order(move_script.new(targets[index]))
	var completed = [false, false]
	maximum_off_mesh = 0
	minimum_clearance = INF
	for frame in 1200:
		await _frames(1)
		for index in actors.size():
			var unit = actors[index]
			_measure_clearance(unit)
			if (
				not unit.get_node("Movement")._has_destination
				and unit.position.distance_to(targets[index]) < .5
			):
				completed[index] = true
		if completed.all(func(done): return done):
			break
	_check(
		completed.all(func(done): return done),
		faction + ": opposing engineers failed to clear HQ corridor"
	)
	_check(
		minimum_clearance >= -.05 and maximum_off_mesh <= .16,
		"Fresh traffic violated body/terrain boundaries"
	)
	print(
		"HQ FACTION TRAFFIC ", faction, " completed=", completed, " clearance=", minimum_clearance
	)
	game.queue_free()
	await _frames(5)


func _actor(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit
