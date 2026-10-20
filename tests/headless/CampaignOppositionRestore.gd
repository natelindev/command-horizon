extends "res://tests/headless/CommandHorizonRegression.gd"

var snapshot_script
var restore_script


func _run():
	snapshot_script = load("res://source/match/saves/MatchSnapshot.gd")
	restore_script = load("res://source/match/saves/MatchRestore.gd")
	path = "user://opposition-restore-%d.json" % OS.get_process_id()
	await _make_match()
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var opposition = game.opposition
	opposition.activate()
	var target = game._spawn(
		"Tank", game._get_human_player(), opposition.boss.position + Vector3(-5, 0, 0)
	)
	target.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(45)
	opposition.salvo_left = 0
	opposition._step_boss(.1)
	_check(opposition.warning_left == 4.0, "Restore fixture did not lock a real observed target")
	paused = true
	var capture = snapshot_script.new()
	var data = capture.capture(game)
	_check(data != null, "Opponent state capture failed: " + capture.error)
	if data != null:
		await _archive(data)
	await _close()
	for message in errors:
		push_error(message)
	print("Campaign opposition restore: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _archive(data):
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(data.mission.has("opposition"), "Archive dropped campaign opposition")
	if not data.mission.has("opposition"):
		return
	_check(schema.validate(data), "Opponent schema failed: " + schema.error)
	var bad = data.duplicate(true)
	bad.mission.opposition.warning_left = 5.0
	_check(not schema.validate(bad), "Invalid boss warning length accepted")
	bad = data.duplicate(true)
	bad.mission.opposition.boss = data.units.filter(func(unit): return unit.role == "Worker")[0].id
	_check(not schema.validate(bad), "Engineer accepted as siege commander")
	var file = load("res://source/match/saves/SaveFile.gd").new()
	var archive = path + ".archive"
	_check(file.write_file(archive, data), "Opponent archive write failed: " + file.error)
	var saved = file.read_file(archive)
	DirAccess.remove_absolute(archive)
	if saved == null:
		_check(false, "Opponent archive could not be read")
		return
	var restore = await restore_script.new().restore(self, saved)
	_check(restore.ok, "Opponent restore failed: " + restore.get("error", ""))
	if not restore.ok:
		return
	game = restore.game
	game.progress_path = path
	_check(paused, "Opponent load resumed combat")
	var state = capture_state(game)
	_check(
		state == saved.mission.opposition,
		"Opponent timers, boss or locked ground point changed on load"
	)
	var boss = game.opposition.boss
	_check(
		game._alive(boss) and boss.type == "AdvancedTank",
		"Restored commander did not bind the actual artillery unit"
	)
	game.opposition._step_boss(4.0)
	_check(
		game.opposition.warning_left < 0 and game.opposition.salvo_left == 14.0,
		"Restored warning failed to resolve exactly once"
	)
	var missing = saved.duplicate(true)
	missing.mission.erase("opposition")
	_check(not schema.validate(missing), "Mission archive without opponent state accepted")


func capture_state(match_game):
	var capture = snapshot_script.new()
	var data = capture.capture(match_game)
	return data.mission.opposition if data != null else {}
