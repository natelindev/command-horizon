extends "res://tests/headless/CoastalRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	moving = load("res://source/match/units/actions/Moving.gd")
	await _skirmish("bastion", COASTAL)
	_enemy().set_process(false)
	await _frames(100)
	_check_water_navigation("Initial bake")
	var terrain = game.navigation.terrain
	root.get_node("MatchSignals").schedule_navigation_rebake.emit(terrain.DOMAIN)
	while not terrain.is_synchronized():
		await physics_frame
	_check_water_navigation("Rebake")
	await _cross_harbor()
	game.queue_free()
	await _frames(5)
	print("Coastal water regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check_water_navigation(stage):
	var ground = game.navigation.terrain.navigation_map_rid
	var air = game.navigation.air.navigation_map_rid
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	for point in [Vector3(64, 0, 30), Vector3(64, 0, 52), Vector3(16, 0, 5)]:
		_check(
			NavigationServer3D.map_get_closest_point(ground, point).distance_to(point) > 3,
			stage + ": water is walkable"
		)
		_check(
			(
				placement.validate_agent_placement_position(point, 2.0, [], ground)
				== placement.NOT_NAVIGABLE
			),
			stage + ": water accepts ground construction"
		)
		var airborne = point + Vector3.UP * 1.5
		_check(
			(
				(
					(
						(NavigationServer3D.map_get_closest_point(air, airborne) - airborne)
						* Vector3(1, 0, 1)
					)
					. length()
				)
				< .5
			),
			stage + ": water blocks aircraft"
		)


func _cross_harbor():
	var human = game._get_human_player()
	var ground = []
	var aircraft = []
	for role in ["Worker", "Infantry", "Tank", "Drone", "Helicopter"]:
		var unit = _spawn_alpine(role, human, Vector3(40, 0, 40 + ground.size() * 3))
		unit.sight_range = 0
		if role in ["Drone", "Helicopter"]:
			aircraft.append(unit)
		else:
			ground.append(unit)
	await _frames(10)
	for unit in ground + aircraft:
		unit.issue_manual_order(moving.new(Vector3(88, unit.position.y, unit.position.z)))
	var water_entries = {}
	var air_crossings = {}
	for frame in 4200:
		await physics_frame
		for unit in ground:
			if not game.map.is_land(unit.position):
				water_entries[unit.type] = true
		for unit in aircraft:
			if not game.map.is_land(unit.position):
				air_crossings[unit.type] = true
	_check(water_entries.is_empty(), "Ground units crossed water: " + str(water_entries.keys()))
	_check(ground.all(func(unit): return unit.position.x > 85), "Ground detour did not arrive")
	_check(air_crossings.size() == 2, "Both aircraft must fly over the harbor")
	_check(
		aircraft.all(func(unit): return unit.position.x > 85), "Aircraft crossing did not arrive"
	)
	for unit in ground:
		unit.issue_manual_order(moving.new(Vector3(64, 0, 40)))
	for frame in 1500:
		await physics_frame
		for unit in ground:
			if not game.map.is_land(unit.position):
				water_entries[unit.type] = true
	_check(water_entries.is_empty(), "Water destination let a ground unit leave the shore")
