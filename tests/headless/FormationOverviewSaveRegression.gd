extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion")
	var camera = game.get_node("IsometricCamera3D")
	var limit = root.get_node("Constants").Match.SKIRMISH_CAMERA_MAX_SIZE
	_check(
		is_equal_approx(camera.size_max, limit),
		"Skirmish overview limit differs from snapshot contract"
	)
	camera.set_size_safely(limit)
	camera.set_position_safely(Vector3(32, 0, 32))
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Full overview cannot be saved: " + builder.error)
	if snapshot != null:
		_check(is_equal_approx(snapshot.camera.size, limit), "Saved overview size was clamped")
		var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
		_check(schema.validate(snapshot), "Valid full overview rejected: " + schema.error)
		var invalid = snapshot.duplicate(true)
		invalid.camera.size = limit + .001
		_check(not schema.validate(invalid), "Snapshot accepted a camera beyond the overview limit")
		var result = await Restore.new().restore(self, snapshot)
		_check(result.ok, "Full overview restore failed: " + result.get("error", ""))
		if result.ok:
			game = result.game
			camera = game.get_node("IsometricCamera3D")
			_check(is_equal_approx(camera.size, limit), "Restored overview zoom changed")
			camera.set_size_safely(limit + 20)
			_check(
				is_equal_approx(camera.size, limit),
				"Camera zoom exceeded the shared overview limit"
			)
	paused = false
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Formation overview save: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
