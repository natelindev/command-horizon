extends "res://tests/headless/SkirmishTravelProbe.gd"


func _run():
	constants = root.get_node("Constants")
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	var settings = _settings("bastion", "helix", false)
	settings.map_path = "res://source/match/maps/DesertFrontier.tscn"
	game = await _start(settings)
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var worker = _spawn_worker(Vector3(40, 0, 48))
	var neighbor = _spawn_worker(Vector3(42, 0, 50))
	await _frames(60)
	worker.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(Vector3(60, 0, 48))
	)
	await _frames(30)
	var id = worker.get_instance_id()
	_check(avoidance_frames.has(id), "Actual avoidance callback was not observed")
	_check(
		avoidance_velocities.get(id, Vector3.ZERO).length() > 0.1, "Missing live avoidance velocity"
	)
	var neighbors = _nearby_agents(worker)
	_check(neighbors.size() == 1, "Nearby-agent trace includes distant or nonmobile units")
	if neighbors.size() == 1:
		_check(neighbors[0].position == str(neighbor.position), "Wrong nearby-agent position")
		_check(neighbors[0].action == str(neighbor.action), "Wrong nearby-agent action")
		_check(neighbors[0].radius == neighbor.radius, "Wrong nearby-agent clearance")
	archive_path = "user://travel-diagnostics-%d.json" % OS.get_process_id()
	var point = worker.position
	var clock_before = game.simulation_time
	var reference = _capture_stationary_state(worker)
	_check(not paused, "Diagnostic capture changed the running pause state")
	var file = load("res://source/match/saves/SaveFile.gd").new()
	var record = file.read_file(archive_path)
	_check(record != null, "Diagnostic archive was not readable")
	if record != null:
		var entries = record.units.filter(func(entry): return entry.id == reference)
		_check(entries.size() == 1, "Diagnostic identifier does not select exactly one saved unit")
		if entries.size() == 1:
			_check(entries[0].position == point, "Diagnostic archive selected the wrong position")
		var original = FileAccess.get_sha256(archive_path)
		await _frames(15)
		_capture_stationary_state(neighbor)
		_check(
			FileAccess.get_sha256(archive_path) == original,
			"A later sample replaced the first archive"
		)
		var restore = load("res://source/match/saves/MatchRestore.gd").new()
		var loaded = await restore.restore(self, record)
		_check(loaded.ok, "Diagnostic archive could not be restored")
		if loaded.ok:
			game = loaded.game
			worker = restore.entities.get(reference)
			_check(
				worker != null and worker.position == point,
				"Restored identifier selected wrong unit"
			)
			_check(
				paused and game.simulation_time == clock_before,
				"Diagnostic restore changed saved clock"
			)
			for player in get_nodes_in_group("players"):
				player.set_process(false)
			paused = false
			await _frames(120)
			_check(
				worker.position.distance_to(point) > 2, "Restored diagnostic order did not continue"
			)
	DirAccess.remove_absolute(archive_path)
	saves.autosaves_enabled = autosaves
	for error in _errors:
		push_error(error)
	print("Travel diagnostics: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _spawn_worker(point):
	var worker = load(Catalog.scene_path("Worker")).instantiate()
	game._setup_and_spawn_unit(worker, Transform3D(Basis(), point), human, false)
	_track_unit(worker)
	return worker
