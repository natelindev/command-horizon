extends "res://tests/headless/AmbientLifeRegression.gd"


func _run():
	path = "user://industrial-environment-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	for map_name in ["IndustrialCrossroads", "BrokenFoundryMap"]:
		await _create(map_name)
		_check(await _roof_clearance() == true, "Roof clearance aborted: " + map_name)
		await _close()
	DirAccess.remove_absolute(path)
	print("Industrial environment: %d failures" % errors.size())
	for message in errors:
		push_error(message)
	quit(0 if errors.is_empty() else 1)


func _roof_clearance():
	var human = game._get_human_player()
	var aircraft = []
	for role in ["Drone", "Helicopter"]:
		var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
		game._setup_and_spawn_unit(unit, Transform3D(Basis(), Vector3(30, 1.5, 35)), human, false)
		aircraft.append(unit)
	await _frames(8)
	for unit in aircraft:
		for body in game.map.flight_obstacles:
			unit.position = body.position + Vector3(-18, 1.5, 0)
			unit.get_node("Movement")._align_unit_position_to_navigation()
			var destination = body.position + Vector3(18, 1.5, 0)
			unit.issue_manual_order(moving.new(destination))
			var start = game.simulation_time
			var crossed = false
			while game.simulation_time - start < 16:
				await physics_frame
				var distance = (
					Vector2(unit.position.x - body.position.x, unit.position.z - body.position.z)
					. length()
				)
				var obstacle = body.get_node("MovementObstacle")
				if distance < obstacle.radius + .5:
					crossed = true
					_check(
						unit.position.y >= obstacle.sight_height + 1.0,
						"Aircraft clipped " + str(body.name)
					)
				if (
					(
						Vector2(unit.position.x - destination.x, unit.position.z - destination.z)
						. length()
					)
					< 1
				):
					break
			_check(
				crossed and unit.position.x > destination.x - 1,
				"Flight stalled across " + str(body.name)
			)
			print(
				"Industrial flight ",
				game.settings.map_path.get_file(),
				" ",
				unit.type,
				" ",
				body.name,
				" ",
				game.simulation_time - start
			)
		unit.issue_manual_order(null)
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	# Actual root height must survive archive reconstruction, not just a visual model offset.
	var body = game.map.flight_obstacles[0]
	aircraft[0].position = body.position + Vector3.UP * 8.0
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = capture.capture(game)
	_check(data != null, "Roof archive capture failed: " + capture.error)
	if data == null:
		return false
	var saved_id = capture._reference(aircraft[0])
	var before = aircraft[0].position
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await restore.restore(self, data)
	_check(result.ok, "Roof archive restore failed: " + result.get("error", ""))
	if not result.ok:
		return false
	game = result.game
	if "progress_path" in game:
		game.progress_path = path
	_check(restore.entities[saved_id].position == before, "Roof archive changed actual altitude")
	paused = false
	return true
