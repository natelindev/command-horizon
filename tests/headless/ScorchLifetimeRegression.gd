extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"battlefield_wear": true, "graphics_ground_detail": true})
	await _skirmish("bastion", "res://source/match/maps/PlainAndSimple.tscn", false)
	game.settings.visibility = game.settings.Visibility.FULL
	var wear = game.battlefield_wear
	wear.set_process(false)
	wear.scar(Vector3(25, 0, 25), 1.5)
	wear.add_mark(Vector2(20, 20), 1.0, 0.0, 0)
	_check(
		wear.marks.size() == 2 and wear.marks[0].left == 180.0,
		"Explosion did not create a three-minute scorch"
	)
	wear.advance_scars(90.0)
	_check(wear.marks[0].left == 90.0, "Scorch age did not advance")
	paused = true
	wear._process(10.0)
	_check(wear.marks[0].left == 90.0, "Paused scorch continued fading")
	var saved = Snapshot.new().capture(game)
	var bad = saved.duplicate(true)
	bad.battlefield_wear[0].left = 180.1
	var loader = Restore.new()
	_check(not loader.prepare(bad), "Save accepted an overlong scorch lifetime")
	var result = await loader.restore(self, saved)
	_check(result.ok, "Scorch restore failed: " + result.get("error", ""))
	if result.ok:
		game = result.game
		wear = game.battlefield_wear
		wear.set_process(false)
		_check(wear.marks[0].left == 90.0, "Reload restarted the scorch lifetime")
		wear.advance_scars(89.9)
		_check(wear.marks.size() == 2, "Scorch vanished before three minutes")
		wear.advance_scars(.11)
		_check(
			wear.marks.size() == 1 and wear.marks[0].kind == 0,
			"Expired scorch remained or erased vehicle tracks"
		)
		wear.scar(Vector3(26, 0, 25), 1.5)
		preferences.battlefield_wear = false
		paused = false
		wear._process(180.1)
		_check(wear.marks.size() == 1, "Disabled ground detail froze scorch lifetime")
	paused = false
	game.queue_free()
	await _frames(5)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Scorch lifetime: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
