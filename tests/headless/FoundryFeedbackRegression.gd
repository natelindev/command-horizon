extends "res://tests/headless/BrokenFoundryRegression.gd"

var prefix = "res://docs/playtests/2026-10-07/foundry-feedback/focused"
var actor
var defender


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="):
			prefix = argument.trim_prefix("--evidence=")
	path = "user://foundry-feedback-%d.json" % OS.get_process_id()
	await _prepare_display()
	await _make_match()
	_freeze()
	actor = _units(game._get_human_player(), "Infantry")[0]
	defender = _units(game._enemy, "Infantry")[0]
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.position = (
				Vector3(10, 0, 105)
				if unit.player == game._get_human_player()
				else Vector3(151, 0, 105)
			)
	actor.position = game.map.CONTROL + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(60)
	_check(
		game.map.relay.progress == 0 and "disable" in game.hud._capture.text.to_lower(),
		"Locked foundry guidance changed"
	)
	await _review("locked")
	for entry in game.nodes:
		entry.unit.hp = 0
	await _frames(3)
	game.response_done = true
	game.response_left = 0
	await _frames(180)
	_check(
		game.map.relay.progress > 2 and "Capturing" in game.hud._capture.text,
		"Active foundry capture unclear"
	)
	actor.position = game.map.CONTROL + Vector3(-12, 0, 0)
	game.battlefield.invalidate()
	await _frames(90)
	var held = game.map.relay.progress
	_check(
		"Capture held" in game.hud._capture.text,
		"Vacant foundry progress described as active capture"
	)
	await _review("vacant")
	await _archive_roundtrip("partial")
	_check(
		game.map.relay.progress == held and "Capture held" in game.hud._capture.text,
		"Paused partial capture misrepresented"
	)
	await _review("loaded")
	game.hud._toggle_pause()
	actor.position = game.map.CONTROL + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(480)
	_check(
		game.map.relay.captured_by == game._get_human_player() and game.hold_seconds > 0,
		"Actual capture failed"
	)
	defender.position = game.map.CONTROL + Vector3(1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(3)
	var secured = game.hold_seconds
	await _frames(90)
	_check(
		game.hold_seconds == secured and game.hud._capture.text.begins_with("Contested"),
		"Contested hold still described as secure"
	)
	await _review("contested")
	actor.position = game.map.CONTROL + Vector3(-12, 0, 0)
	game.battlefield.invalidate()
	await _frames(120)
	_check("Enemy capture" in game.hud._capture.text, "Enemy takeover unclear")
	await _frames(540)
	_check(game.map.relay.captured_by == game._enemy, "Enemy actual capture failed")
	defender.position = Vector3(151, 0, 105)
	actor.position = game.map.CONTROL + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(180)
	_check("Recapturing" in game.hud._capture.text, "Recapture confused with blocked contest")
	await _review("recapturing")
	await _frames(480)
	actor.position = game.map.CONTROL + Vector3(-12, 0, 0)
	game.battlefield.invalidate()
	await _frames(3)
	secured = game.hold_seconds
	await _frames(90)
	_check(game.hold_seconds == secured, "Absent infantry advanced securing")
	_check("Infantry needed" in game.hud._capture.text, "Absent infantry still described as secure")
	_check("Infantry needed" in game.objective_text(), "Objective omits missing infantry")
	_check("INFANTRY NEEDED" in game.map.relay._label.text, "World marker omits missing infantry")
	await _archive_roundtrip("owned")
	_check(
		"Infantry needed" in game.hud._capture.text, "Paused owned archive hides missing infantry"
	)
	await _review("infantry-needed")
	await _recover()
	var start = game.simulation_time
	game.hud._toggle_pause()
	while not game.finished and game.simulation_time - start < 45:
		await _frames(15)
	_check(game.result == "Victory", "Explicit infantry return did not finish securing")
	print("FOUNDRY FEEDBACK RECOVERY elapsed=", game.simulation_time - start)
	await _review("victory")
	await _close()
	await _restore_display()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Foundry feedback: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _freeze():
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED


func _archive_roundtrip(label):
	game.hud._toggle_pause()
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var store = load("res://source/match/saves/SaveFile.gd").new()
	var data = capture.capture(game)
	_check(
		data != null and store.write_file(prefix + "-" + label + ".json", data),
		"Foundry archive write failed"
	)
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await restore.restore(self, store.read_file(prefix + "-" + label + ".json"))
	_check(result.ok, "Foundry feedback restoration failed")
	if not result.ok:
		return
	game = result.game
	game.progress_path = path
	_freeze()
	var infantry = _units(game._get_human_player(), "Infantry")
	actor = infantry.filter(func(unit): return unit.position.distance_to(game.map.CONTROL) < 15)[0]
	defender = _units(game._enemy, "Infantry")[0]
	await _frames(6)
	var again = capture.capture(game)
	_check(
		again.mission == data.mission and game.simulation_time == data.simulation_time and paused,
		"Restoration changed objective or time"
	)
	for saved in data.units:
		var actual = again.units.filter(func(unit): return unit.id == saved.id)[0]
		_check(
			actual.position == saved.position and actual.hp == saved.hp,
			"Restoration changed unit position/HP"
		)


func _recover():
	actor.process_mode = Node.PROCESS_MODE_INHERIT
	actor.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(
			game.map.CONTROL + Vector3(-1.6, 0, 0)
		)
	)


func _review(_label):
	pass


func _prepare_display():
	pass


func _restore_display():
	pass
