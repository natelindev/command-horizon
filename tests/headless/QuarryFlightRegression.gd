extends "res://tests/headless/AirEnvironmentRegression.gd"


func _run():
	path = "user://quarry-flight-%d.json" % OS.get_process_id()
	moving = load("res://source/match/units/actions/Moving.gd")
	await _make_match()
	for unit in game._enemy.get_children():
		if unit.is_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
	var snapshot
	var saved_id
	var saved_position
	var crossed_count = 0
	for role in ["Drone", "Helicopter", "EvacTransport"]:
		var unit = game._spawn(role, game._get_human_player(), Vector3(30, 0, 51))
		await _frames(5)
		var bottom = 0.0
		for vertex in _vertices(unit.get_node("Geometry")):
			bottom = minf(bottom, vertex.y - unit.position.y)
		# Cross the thirteen quarry landmarks. Campaign interior districts also
		# register flight obstacles, some beside the map edge where a 15 m
		# crossing would leave the playable area.
		for body in game.map.flight_obstacles.filter(
			func(item): return not item.has_meta("campaign_scenery")
		):
			var obstacle = body.get_node("MovementObstacle")
			var top = 0.0
			for vertex in _vertices(body):
				top = maxf(top, vertex.y)
			unit.position = Vector3(body.position.x - 15, unit.position.y, body.position.z)
			unit.get_node("Movement")._align_unit_position_to_navigation()
			unit.issue_manual_order(moving.new(Vector3(body.position.x + 15, 0, body.position.z)))
			var start = game.simulation_time
			var crossed = false
			while unit.position.x < body.position.x + 14 and game.simulation_time - start < 25:
				await physics_frame
				if absf(unit.position.x - body.position.x) <= obstacle.radius + 1:
					crossed = true
					_check(
						unit.position.y + bottom > top + .15, "Airframe intersects quarry landmark"
					)
				if (
					snapshot == null
					and role == "Drone"
					and absf(unit.position.x - body.position.x) < 1
				):
					paused = true
					var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
					snapshot = capture.capture(game)
					saved_id = capture._reference(unit)
					saved_position = unit.position
					paused = false
			_check(crossed and unit.position.x >= body.position.x + 14, "Quarry crossing stalled")
			crossed_count += 1
		unit.issue_manual_order(null)
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_check(snapshot != null, "No raised flight archive captured")
	var archive = load("res://source/match/saves/SaveFile.gd").new()
	_check(archive.write_file(EVIDENCE + "raised-flight.json", snapshot), archive.error)
	snapshot = archive.read_file(EVIDENCE + "raised-flight.json")
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var loaded = await restore.restore(self, snapshot)
	_check(loaded.ok, "Raised flight restoration failed")
	if loaded.ok:
		game = loaded.game
		game.progress_path = path
		var unit = restore.entities[saved_id]
		_check(
			unit.position == saved_position and paused, "Restore changed raised aircraft position"
		)
		await _frames(10)
		_check(
			game.simulation_time == snapshot.simulation_time, "Raised archive advanced paused time"
		)
		game.hud._toggle_pause()
		await _frames(240)
		_check(
			unit.position.x > saved_position.x + 5, "Raised aircraft failed to resume saved route"
		)
	print("QUARRY FLIGHTS crossings=", crossed_count, " saved_altitude=", saved_position.y)
	await _close()
	for message in errors:
		push_error(message)
	print("Quarry flight: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
