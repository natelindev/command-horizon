extends "res://tests/headless/FrontierRegression.gd"

const INDUSTRIAL = "res://source/match/maps/IndustrialCrossroads.tscn"


func _initialize():
	# The two-faction suite now includes timed captures and construction as well as travel.
	create_timer(1200).timeout.connect(
		func():
			push_error("Industrial regression timed out")
			quit(1)
	)
	_run.call_deferred()


func _run():
	moving = load("res://source/match/units/actions/Moving.gd")
	if "--economy-only" in OS.get_cmdline_user_args():
		for faction in ["bastion", "helix"]:
			_check(await _industrial_economy(faction) == true, "Economy aborted")
		print("Industrial economy: %d failures" % errors.size())
		quit(0 if errors.is_empty() else 1)
		return
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, INDUSTRIAL)
		_enemy().set_process(false)
		_check(await _industrial_routes() == true, "Industrial route suite aborted")
		_check(await _infantry_access() == true, "Infantry access aborted")
		_check(
			await _relay_and_restore(game._get_human_player(), _enemy()) == true,
			"Industrial relay archive suite aborted"
		)
		paused = false
		game.queue_free()
		await _frames(5)
		_check(await _industrial_economy(faction) == true, "Industrial economy suite aborted")
	print("Industrial Crossroads: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _industrial_routes():
	var human = game._get_human_player()
	var ground = root.get_node("Constants").Match.Navigation.Domain.TERRAIN
	await _frames(100)
	var manifest = JSON.parse_string(
		FileAccess.get_file_as_string("res://art/environment/industrial-manifest.json")
	)
	for asset in manifest.values():
		_check(
			asset.radius <= asset.radius_limit and asset.height <= asset.height_limit,
			"Industrial art exceeds obstacle"
		)
	# District buildings only; story landmarks add their own flight clearance.
	_check(
		(
			(
				game
				. map
				. flight_obstacles
				. filter(func(body): return body.has_meta("neutral_asset"))
				. size()
			)
			== 6
		),
		"Wrong district obstacle count"
	)
	for z in [22, 52, 82]:
		var route = _route(ground, Vector3(34, 0, z), Vector3(94, 0, z))
		_check(route.size() >= 2 and _length(route) < 65, "Street approach blocked")
	for x in [40, 64, 88]:
		var route = _route(ground, Vector3(x, 0, 22), Vector3(x, 0, 82))
		_check(route.size() >= 2 and _length(route) < 65, "Junction spine blocked")
	var seconds = _length(_route(ground, Vector3(14, 0, 50), Vector3(114, 0, 54))) / 2.6
	var expansion = _length(_route(ground, Vector3(14, 0, 50), Vector3(32, 0, 90))) / 2.6
	_check(seconds >= 35 and seconds <= 55, "Base traversal outside 35–55 seconds")
	_check(expansion >= 15 and expansion <= 25, "First expansion outside 15–25 seconds")
	print("Industrial paths: base %.1fs, expansion %.1fs" % [seconds, expansion])
	var placement = load("res://source/match/utils/UnitPlacementUtils.gd")
	var nav = game.navigation.get_navigation_map_rid_by_domain(ground)
	for point in game.map.BLOCKS:
		_check(
			(
				placement.validate_agent_placement_position(
					Vector3(point.x, 0, point.y), 2.0, [], nav
				)
				== placement.NOT_NAVIGABLE
			),
			"Building accepts construction"
		)
	_check(
		(
			placement.validate_agent_placement_position(Vector3(64, 0, 52), 2.0, [], nav)
			== placement.VALID
		),
		"Open junction rejects construction"
	)
	_check(
		not game.battlefield.line_clear(Vector3(41, .8, 37), Vector3(63, .8, 37)),
		"Warehouse leaks ground sight/fire"
	)
	_check(
		game.battlefield.line_clear(Vector3(41, .8, 52), Vector3(87, .8, 52)),
		"Central street blocks sight/fire"
	)
	var army = []
	for z in [22, 52, 82]:
		for index in 16:
			army.append(
				_spawn_alpine(
					"Tank", human, Vector3(35 - (index / 4) * 2.5, 0, z - 3 + (index % 4) * 2)
				)
			)
	await _frames(10)
	for index in army.size():
		var row = index % 16
		army[index].issue_manual_order(
			moving.new(
				Vector3(90 + (row / 4) * 2.5, 0, [22, 52, 82][index / 16] - 3 + (row % 4) * 2)
			)
		)
	await _frames(600)
	paused = true
	var capture = Snapshot.new()
	var data = capture.capture(game)
	_check(data != null, "Industrial capture failed: " + capture.error)
	if data == null:
		return false
	var ids = army.map(func(unit): return capture._reference(unit))
	var file = FileStore.new()
	var archive = "user://industrial-%d.json" % OS.get_process_id()
	_check(file.write_file(archive, data), "Industrial disk write failed")
	var restore = Restore.new()
	var result = await restore.restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(result.ok, "Industrial restore failed: " + result.get("error", ""))
	if not result.ok:
		return false
	game = result.game
	human = game._get_human_player()
	_enemy().set_process(false)
	army = ids.map(func(id): return restore.entities[id])
	_check(capture.capture(game).ambient == data.ambient, "District archive moved civilians")
	_check(
		game.settings.map_path == INDUSTRIAL and game.map.relays.size() == 2,
		"Archive changed district"
	)
	# Four authored fields of seven deposits and two salvage caches of three.
	_check(
		get_nodes_in_group("resource_units").size() == 34, "District archive duplicated deposits"
	)
	game.hud._toggle_pause()
	await _frames(1800)
	_check(army.all(func(unit): return unit.position.x > 87), "Industrial 16-tank approach stuck")
	for index in army.size():
		var row = index % 16
		army[index].issue_manual_order(
			moving.new(
				Vector3(35 - (row / 4) * 2.5, 0, [22, 52, 82][index / 16] - 3 + (row % 4) * 2)
			)
		)
	await _frames(2300)
	_check(army.all(func(unit): return unit.position.x < 40), "Industrial retreat stuck")
	for unit in army:
		unit.queue_free()
	await _frames(5)
	_check(await _industrial_flight(human) == true, "Industrial flight aborted")
	print(
		(
			"PASS: %s three 16-tank lanes and retreat, moving archive, junctions, sight/placement, aircraft"
			% human.faction
		)
	)
	return true


func _industrial_flight(human):
	for unit in get_nodes_in_group("units"):
		if unit.player != human:
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	for role in ["Drone", "Helicopter"]:
		var aircraft = _spawn_alpine(role, human, Vector3(34, 0, 37))
		await _frames(5)
		aircraft.issue_manual_order(moving.new(Vector3(94, 1.5, 37)))
		var start = game.simulation_time
		var crossed = false
		while game.simulation_time - start < 25:
			await physics_frame
			for body in game.map.flight_obstacles:
				if (
					(
						Vector2(
							aircraft.position.x - body.position.x,
							aircraft.position.z - body.position.z
						)
						. length()
					)
					< body.get_node("MovementObstacle").radius + .5
				):
					crossed = true
					_check(
						aircraft.position.y >= body.get_node("MovementObstacle").sight_height + 1.0,
						"Aircraft clips industrial roof"
					)
			if aircraft.position.x > 93:
				break
		_check(crossed and aircraft.position.x > 93, role + " failed district crossing")
		aircraft.queue_free()
	await _frames(5)
	return true


func _industrial_economy(faction):
	await _skirmish(faction, INDUSTRIAL, false)
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
			"Industrial home cargo not delivered: " + side.faction
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
					and unit.resource_b == 1200
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
			"Industrial expansion cargo not delivered: " + [human, _enemy()][index].faction
		)
	for side in [human, _enemy()]:
		_report_workers(side, "expansion")
	for worker in _units(human, "Worker"):
		worker.issue_manual_order(null)
	_units(human, "Worker")[0].get_node("Selection").select()
	var handler = human.get_node("StructurePlacementHandler")
	handler._on_structure_placement_request(load("res://source/match/units/PowerPlant.tscn"))
	handler._active_blueprint_node.position = Vector3(25, 0, 42)
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


func _infantry_access():
	var human = game._get_human_player()
	var walkers = []
	for index in 2:
		var unit = _spawn_alpine("Infantry", human, Vector3(34, 0, 22 if index == 0 else 82))
		walkers.append(unit)
	await _frames(5)
	for index in 2:
		walkers[index].issue_manual_order(
			moving.new(game.map.relays[index].position + Vector3(-2, 0, 0))
		)
	await _frames(2100)
	_check(
		game.map.relays.all(func(relay): return relay.captured_by == human),
		"Infantry could not walk to and capture both relays"
	)
	for unit in walkers:
		unit.queue_free()
	for relay in game.map.relays:
		relay.captured_by = null
		relay.candidate = null
		relay.progress = 0.0
		relay._update_presentation()
	game.battlefield.invalidate()
	await _frames(5)
	return true


func _report_workers(side, label):
	print(
		"Industrial economy ",
		label,
		" ",
		side.faction,
		" balance=",
		side.resource_a,
		"/",
		side.resource_b
	)
	for worker in _units(side, "Worker"):
		var movement = worker.get_node("Movement")
		print(
			"  worker pos=",
			worker.position,
			" cargo=",
			worker.resource_a,
			"/",
			worker.resource_b,
			" action=",
			worker.action,
			" destination=",
			movement.target_position,
			" active=",
			movement._has_destination,
			" synced=",
			movement._synchronized
		)
