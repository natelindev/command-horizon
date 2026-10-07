extends "res://tests/headless/CommandHorizonRules.gd"

var prefix = "res://docs/playtests/2026-10-07/horizon-control/focused"
var actor
var defender
var returns = 0


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="):
			prefix = argument.trim_prefix("--evidence=")
	path = "user://horizon-control-%d.json" % OS.get_process_id()
	await _prepare_display()
	await _make_match()
	_isolate()
	# Reset the initial enemy capture for this controlled unclaimed-state fixture.
	game.map.relay.candidate = null
	game.map.relay.progress = 0
	actor = _units(game._get_human_player(), "Infantry")[0]
	defender = _units(game._enemy, "Infantry")[0]
	await _frames(3)
	_check(game.hud._zone.text == "Unclaimed", "Unclaimed deployment described as active capture")
	await _review("unclaimed")
	actor.position = game.map.DEPLOYMENT + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(180)
	_check(
		game.map.relay.progress > 2 and "Capturing" in game.hud._zone.text, "Active capture unclear"
	)
	actor.position = game.map.DEPLOYMENT + Vector3(-12, 0, 0)
	game.battlefield.invalidate()
	await _frames(90)
	var held = game.map.relay.progress
	_check("Capture held" in game.hud._zone.text, "Vacant capture described as advancing")
	_check("Capture held" in game.objective_text(), "Objective hides vacant capture")
	await _review("vacant")
	await _archive_roundtrip("partial")
	_check(
		game.map.relay.progress == held and "Capture held" in game.hud._zone.text,
		"Paused partial capture unclear"
	)
	await _review("loaded")
	game.hud._toggle_pause()
	actor.position = game.map.DEPLOYMENT + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(480)
	_check(
		game.map.relay.captured_by == game._get_human_player() and game.hold_seconds > 0,
		"Actual deployment capture failed"
	)
	# Isolate objective states from the separately verified finite responses.
	game.defence_time = 120
	game.waves_sent = 4
	game.waves_warned = 4
	defender.position = game.map.DEPLOYMENT + Vector3(1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(3)
	var secured = game.hold_seconds
	await _frames(90)
	_check(
		game.hold_seconds == secured and game.hud._zone.text.begins_with("Contested"),
		"Contested securing described as advancing"
	)
	await _review("contested")
	actor.position = game.map.DEPLOYMENT + Vector3(-12, 0, 0)
	game.battlefield.invalidate()
	await _frames(120)
	_check("Enemy capture" in game.hud._zone.text, "Enemy takeover unclear")
	await _frames(540)
	_check(game.map.relay.captured_by == game._enemy, "Actual enemy capture failed")
	defender.position = Vector3(175, 0, 100)
	actor.position = game.map.DEPLOYMENT + Vector3(-1.6, 0, 0)
	game.battlefield.invalidate()
	await _frames(180)
	_check(
		"Recapturing" in game.hud._zone.text and not "Contested" in game.hud._zone.text,
		"Advancing recapture presented as blocked"
	)
	await _review("recapturing")
	await _frames(480)
	actor.position = game.map.DEPLOYMENT + Vector3(-12, 0, 0)
	game.battlefield.invalidate()
	await _frames(3)
	secured = game.hold_seconds
	await _frames(90)
	_check(game.hold_seconds == secured, "Absent infantry advanced securing")
	await _assert_missing_infantry()
	await _archive_roundtrip("owned")
	await _assert_missing_infantry()
	await _review("infantry-needed")
	await _recover()
	var start = game.simulation_time
	game.hud._toggle_pause()
	while not game.deployed and game.simulation_time - start < 45:
		await _frames(15)
	_check(
		game.deployed and not game.finished and game.hold_seconds == 30,
		"Securing bypassed enemy command objective"
	)
	_check("Guard in place" in game.hud._zone.text, "Secured deployment guard not distinguished")
	print("HORIZON CONTROL SECURING elapsed=", game.simulation_time - start)
	await _review("guard-ready")
	actor.issue_manual_order(null)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	actor.position = game.map.DEPLOYMENT + Vector3(-12, 0, 0)
	game.battlefield.invalidate()
	await _frames(3)
	await _assert_missing_infantry()
	await _review("guard-absent")
	game.target_command.hp = 0
	await _frames(3)
	_check(game.command_destroyed and not game.finished, "Missing guard bypassed victory condition")
	_check(
		game.objective_text() == "Command destroyed · return infantry to deployment",
		"Owned empty deployment asks for recapture"
	)
	game.hud._toggle_pause()
	await _review("command-destroyed")
	await _recover()
	start = game.simulation_time
	game.hud._toggle_pause()
	while not game.finished and game.simulation_time - start < 20:
		await _frames(15)
	_check(game.result == "Victory", "Ordinary guard return did not finish")
	_check(
		game.objective_text() == "Command destroyed · deployment secured",
		"Victory objective changed"
	)
	print("HORIZON CONTROL RETURN elapsed=", game.simulation_time - start)
	await _review("victory")
	await _close()
	await _restore_display()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Horizon control: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _assert_missing_infantry():
	await _frames(12)
	_check(
		"Infantry needed" in game.hud._zone.text,
		"Panel hides absent infantry: " + game.hud._zone.text
	)
	_check("Infantry needed" in game.objective_text(), "Objective hides absent infantry")
	_check("INFANTRY NEEDED" in game.map.relay._label.text, "World marker hides absent infantry")


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
		"Deployment archive write failed"
	)
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await restore.restore(self, store.read_file(prefix + "-" + label + ".json"))
	_check(result.ok, "Deployment archive restoration failed")
	if not result.ok:
		return
	game = result.game
	game.progress_path = path
	_freeze()
	var infantry = _units(game._get_human_player(), "Infantry")
	actor = infantry.filter(func(unit): return unit.position.distance_to(game.map.DEPLOYMENT) < 15)[0]
	defender = _units(game._enemy, "Infantry")[0]
	await _frames(6)
	var again = capture.capture(game)
	_check(
		again.mission == data.mission and game.simulation_time == data.simulation_time and paused,
		"Deployment restoration changed time/state"
	)
	_check(again.players == data.players, "Deployment restoration changed economy")
	for saved in data.units:
		var actual = again.units.filter(func(unit): return unit.id == saved.id)[0]
		_check(
			actual.position == saved.position and actual.hp == saved.hp,
			"Deployment restoration changed unit position/HP"
		)


func _recover():
	returns += 1
	actor.process_mode = Node.PROCESS_MODE_INHERIT
	actor.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(
			game.map.DEPLOYMENT + Vector3(-1.6, 0, 0)
		)
	)


func _review(_label):
	pass


func _prepare_display():
	pass


func _restore_display():
	pass
