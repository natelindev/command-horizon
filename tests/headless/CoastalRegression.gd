extends "res://tests/headless/IndustrialRegression.gd"

const COASTAL = "res://source/match/maps/CoastalFoundry.tscn"


func _run():
	moving = load("res://source/match/units/actions/Moving.gd")
	for faction in ["bastion", "helix"]:
		if not "--economy-only" in OS.get_cmdline_user_args():
			await _skirmish(faction, COASTAL)
			_enemy().set_process(false)
			_check(await _coastal_routes() == true, "Coastal routes aborted")
			paused = false
			game.queue_free()
			await _frames(5)
		_check(await _coastal_economy(faction) == true, "Coastal economy aborted")
	for message in errors:
		push_error(message)
	print("Coastal Foundry: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _coastal_routes():
	var human = game._get_human_player()
	await _frames(100)
	var ground = root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	var air = root.get_node("Constants").Match.Navigation.Domain.AIR
	var nav = game.navigation.get_navigation_map_rid_by_domain(ground)
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	_check(game.map.flight_obstacles.size() == 11, "Coastal obstacle count changed")
	var manifest = JSON.parse_string(
		FileAccess.get_file_as_string("res://art/environment/coastal-manifest.json")
	)
	for asset in manifest.values():
		_check(
			asset.radius <= asset.radius_limit and asset.height <= asset.height_limit,
			"Coastal model exceeds clearance"
		)
	for point in [Vector3(64, 0, 30), Vector3(64, 0, 52), Vector3(16, 0, 5)]:
		_check(
			(
				placement.validate_agent_placement_position(point, 2.0, [], nav)
				== placement.NOT_NAVIGABLE
			),
			"Water accepted ground construction"
		)
		_check(
			NavigationServer3D.map_get_closest_point(nav, point).distance_to(point) > 3,
			"Water is walkable"
		)
	_check(
		(
			placement.validate_agent_placement_position(Vector3(30, 0, 76), 2.0, [], nav)
			== placement.VALID
		),
		"Land rejects construction"
	)
	var crossing = _route(ground, Vector3(16, 0, 34), Vector3(112, 0, 34))
	var flight = _route(air, Vector3(16, 1.5, 34), Vector3(112, 1.5, 34))
	var seconds = _length(crossing) / 2.6
	var expansion = _length(_route(ground, Vector3(16, 0, 34), Vector3(24, 0, 81))) / 2.6
	print(
		(
			"Coastal paths: base %.1fs, expansion %.1fs; ground %.1fm / air %.1fm"
			% [seconds, expansion, _length(crossing), _length(flight)]
		)
	)
	_check(seconds >= 35 and seconds <= 55, "Coastal base pacing outside 35–55s")
	_check(expansion >= 15 and expansion <= 25, "Coastal expansion pacing outside 15–25s")
	_check(_length(crossing) > _length(flight) + 15, "Water affords no aircraft shortcut")
	for index in range(1, crossing.size()):
		for step in 20:
			_check(
				game.map.is_land(crossing[index - 1].lerp(crossing[index], step / 20.0)),
				"Ground route crosses water"
			)
	for z in [64, 94]:
		_check(
			_length(_route(ground, Vector3(30, 0, z), Vector3(98, 0, z))) < 72,
			"Coastal lane obstructed"
		)
	var army = []
	for z in [64, 94]:
		for index in 16:
			army.append(
				_spawn_alpine(
					"Tank", human, Vector3(32 - (index / 4) * 2.5, 0, z - 3 + (index % 4) * 2)
				)
			)
	await _frames(10)
	for index in army.size():
		var row = index % 16
		army[index].issue_manual_order(
			moving.new(Vector3(96 + (row / 4) * 2.5, 0, [64, 94][index / 16] - 3 + (row % 4) * 2))
		)
	await _frames(600)
	var saved_aircraft = _spawn_alpine("Helicopter", human, Vector3(42, 0, 30))
	await _frames(5)
	var air_position = saved_aircraft.position
	_check(air_position.y >= 9.2, "Aircraft failed crane altitude before archive")
	paused = true
	var capture = Snapshot.new()
	var data = capture.capture(game)
	_check(data != null, "Coastal snapshot failed: " + capture.error)
	if data == null:
		return false
	var ids = army.map(func(unit): return capture._reference(unit))
	var air_id = capture._reference(saved_aircraft)
	var positions = army.map(func(unit): return unit.position)
	var water_time = game.map.water_material.get_shader_parameter("simulation_time")
	for frame in 5:
		await process_frame
	_check(
		game.map.water_material.get_shader_parameter("simulation_time") == water_time,
		"Paused water moved"
	)
	var file = FileStore.new()
	var archive = "user://coastal-%d.json" % OS.get_process_id()
	_check(file.write_file(archive, data), "Coastal archive write failed")
	var restore = Restore.new()
	var result = await restore.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(result.ok, "Coastal restore failed: " + result.get("error", ""))
	if not result.ok:
		return false
	game = result.game
	human = game._get_human_player()
	_enemy().set_process(false)
	army = ids.map(func(id): return restore.entities[id])
	saved_aircraft = restore.entities[air_id]
	_check(
		saved_aircraft.position.distance_to(air_position) < .02, "Archive displaced raised aircraft"
	)
	_check(capture.capture(game).ambient == data.ambient, "Coastal archive changed neutral poses")
	_check(
		is_equal_approx(
			game.map.water_material.get_shader_parameter("simulation_time"), game.simulation_time
		),
		"Loaded water clock differs"
	)
	_check(get_nodes_in_group("resource_units").size() == 16, "Restore duplicated deposits")
	for index in army.size():
		_check(
			army[index].position.distance_to(positions[index]) < .02,
			"Restore displaced coastal unit"
		)
	game.hud._toggle_pause()
	saved_aircraft.issue_manual_order(moving.new(Vector3(86, 1.5, 30)))
	await _frames(2400)
	_check(saved_aircraft.position.x > 85, "Restored aircraft failed actual water crossing")
	saved_aircraft.queue_free()
	_check(army.all(func(unit): return unit.position.x > 93), "Coastal 16-tank advance stuck")
	for index in army.size():
		var row = index % 16
		army[index].issue_manual_order(
			moving.new(Vector3(32 - (row / 4) * 2.5, 0, [64, 94][index / 16] - 3 + (row % 4) * 2))
		)
	await _frames(2600)
	_check(army.all(func(unit): return unit.position.x < 37), "Coastal 16-tank retreat stuck")
	for unit in army:
		unit.queue_free()
	await _frames(5)
	_check(await _coastal_flight(human) == true, "Coastal flight aborted")
	print(
		(
			"PASS %s: two 16-tank routes/retreat, water boundaries, moving archive, aircraft clearance"
			% human.faction
		)
	)
	return true


func _coastal_flight(human):
	for unit in get_nodes_in_group("units"):
		if unit.player != human:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	for role in ["Drone", "Helicopter"]:
		for body in game.map.flight_obstacles:
			var radius = body.get_meta("clearance_radius")
			var left = maxf(2, body.position.x - radius - 6)
			var right = minf(126, body.position.x + radius + 6)
			var aircraft = _spawn_alpine(role, human, Vector3(left, 0, body.position.z))
			await _frames(5)
			aircraft.issue_manual_order(moving.new(Vector3(right, 1.5, body.position.z)))
			var start = game.simulation_time
			var crossed = false
			while game.simulation_time - start < 20:
				await physics_frame
				var distance = (
					Vector2(
						aircraft.position.x - body.position.x, aircraft.position.z - body.position.z
					)
					. length()
				)
				if distance < radius + .5:
					crossed = true
					_check(
						aircraft.position.y >= body.get_meta("clearance_height") + 1,
						"Aircraft clips " + body.name
					)
				if aircraft.position.x > right - 1:
					break
			_check(
				crossed and aircraft.position.x > right - 1, role + " failed crossing " + body.name
			)
			aircraft.queue_free()
			await _frames(3)
	return true


func _coastal_economy(faction):
	await _skirmish(faction, COASTAL, false)
	_enemy().set_process(false)
	var human = game._get_human_player()
	var failures_before = errors.size()
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var balances = []
	var deposits = get_nodes_in_group("resource_units")
	for index in deposits.size():
		for other in deposits.slice(index + 1):
			_check(
				deposits[index].position.distance_to(other.position) >= 3.1,
				"Resource spacing leaves no largest-agent clearance"
			)
	for side in [human, _enemy()]:
		var workers = _units(side, "Worker")
		var home_deposits = deposits.duplicate()
		var hq = _units(side, "CommandCenter")[0]
		home_deposits.sort_custom(
			func(a, b):
				return (
					a.position.distance_squared_to(hq.position)
					< b.position.distance_squared_to(hq.position)
				)
		)
		for deposit in home_deposits.slice(0, 4):
			var observed = false
			for unit in side.get_children():
				if unit.is_in_group("units") and game.battlefield.can_observe(unit, deposit):
					observed = true
			_check(observed, "Home salvage not visible at Standard start")
		_check(
			workers.size() == 4 and _units(side, "Tank").is_empty(),
			"Standard district army incorrect"
		)
		for index in 2:
			var kind = "resource_a" if index == 0 else "resource_b"
			var choices = get_nodes_in_group("resource_units").filter(
				func(unit): return kind in unit
			)
			choices.sort_custom(
				func(a, b):
					return (
						a.position.distance_squared_to(workers[index].position)
						< b.position.distance_squared_to(workers[index].position)
					)
			)
			workers[index].issue_manual_order(harvest.new(choices[0]))
		balances.append(Vector2(side.resource_a, side.resource_b))
	await _frames(3000)
	for index in 2:
		var side = [human, _enemy()][index]
		_check(
			side.resource_a > balances[index].x and side.resource_b > balances[index].y,
			"Coastal home cargo not delivered: " + side.faction
		)
		_report_workers(side, "home")
		for worker in _units(side, "Worker"):
			worker.issue_manual_order(null)
	balances.clear()
	for index in 2:
		var side = [human, _enemy()][index]
		var outer_fields = get_nodes_in_group("resource_units").filter(
			func(unit):
				return (
					"resource_b" in unit
					and unit.resource_b == 600
					and ((unit.position.x < 64) == (index == 0))
				)
		)
		var outer = outer_fields[0]
		_units(side, "Worker")[2].issue_manual_order(harvest.new(outer))
		balances.append(side.resource_b)
	await _frames(5000)
	for index in 2:
		_check(
			[human, _enemy()][index].resource_b > balances[index],
			"Coastal expansion cargo not delivered: " + [human, _enemy()][index].faction
		)
	for side in [human, _enemy()]:
		_report_workers(side, "expansion")
	for worker in _units(human, "Worker"):
		worker.issue_manual_order(null)
	_units(human, "Worker")[0].get_node("Selection").select()
	var handler = human.get_node("StructurePlacementHandler")
	handler._on_structure_placement_request(load("res://source/match/units/PowerPlant.tscn"))
	handler._active_blueprint_node.position = Vector3(30, 0, 44)
	_check(
		handler._calculate_blueprint_position_validity() == handler.BlueprintPositionValidity.VALID,
		"Home build space rejects power plant"
	)
	var before = human.resource_a
	handler._finish_structure_placement()
	_check(human.resource_a < before, "District construction did not charge materials")
	await _frames(2400)
	_check(
		human.has_completed_structure("PowerPlant"), "Engineer could not finish home construction"
	)
	if errors.size() == failures_before:
		print(
			(
				"PASS: %s both home fields, both expansions, paid construction and resource transit"
				% faction
			)
		)
	game.queue_free()
	await _frames(5)
	return true
