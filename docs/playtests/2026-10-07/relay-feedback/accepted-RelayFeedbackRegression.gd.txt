extends "res://tests/headless/SplitSignalRegression.gd"

var capture_point: Vector3
var actor
var defender


func _run():
	path = "user://relay-feedback-%d.json" % OS.get_process_id()
	archive = "user://relay-feedback-archive-%d.json" % OS.get_process_id()
	await _prepare_display()
	await _make_match()
	game.waves_sent = 6
	game.waves_warned = 6
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		if unit.movement_speed > 0:
			unit.position = Vector3(5, 0, 5)
	actor = _units(game._get_human_player(), "Infantry")[0]
	defender = _units(game._enemy, "Infantry")[0]
	capture_point = game.map.relays[0].position
	defender.position = capture_point + Vector3(1.5, 0, 0)
	game.battlefield.invalidate()
	await _frames(660)
	_check(game.map.relays[0].captured_by == game._enemy, "Enemy failed actual initial capture")
	defender.position = Vector3(5, 0, 5)
	actor.position = capture_point + Vector3(-1.5, 0, 0)
	game.battlefield.invalidate()
	await _frames(180)
	var relay = game.map.relays[0]
	_check(relay.progress > 2 and relay.contested, "Recapture scenario did not advance")
	_check(
		"Recapturing" in game.hud._relay_labels[0].text,
		"Active recapture hidden by contested label"
	)
	_check("RECAPTURING" in relay._label.text, "World label hides active recapture")
	_check(
		"Recapture in progress" in game.objective_text(),
		"Active recapture asks for unnecessary clearance"
	)
	_check(
		"Clear opposing" not in game.hud._relay_labels[0].tooltip_text,
		"Active recapture tooltip requests clearance"
	)
	await _review("recapturing")
	game.hud._toggle_pause()
	var capture = Snapshot.new()
	var data = capture.capture(game)
	var store = Store.new()
	_check(store.write_file(archive, data), "Relay feedback archive write failed")
	var restored = await Restore.new().restore(self, store.read_file(archive))
	_check(restored.ok, "Relay archive restore failed")
	if not restored.ok:
		quit(2)
		return
	game = restored.game
	game.progress_path = path
	relay = game.map.relays[0]
	var infantry = _units(game._get_human_player(), "Infantry")
	actor = infantry.filter(func(unit): return unit.position.distance_to(capture_point) < 3)[0]
	defender = _units(game._enemy, "Infantry")[0]
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(10)
	_check(
		paused and game.simulation_time == data.simulation_time, "Paused recapture advanced time"
	)
	_check(relay.progress == data.mission.relays[0].progress, "Loaded capture progress changed")
	_check("Recapturing" in game.hud._relay_labels[0].text, "Paused archive hides recapture")
	_check("RECAPTURING" in relay._label.text, "Paused world marker hides restored recapture")
	await _review("loaded")
	game.hud._toggle_pause()
	defender.position = capture_point + Vector3(1.5, 0, 0)
	game.battlefield.invalidate()
	await _frames(3)
	var held = relay.progress
	await _frames(90)
	_check(relay.progress == held and relay.contested, "Opposing defenders did not stall capture")
	_check("Contested" in game.hud._relay_labels[0].text, "Stalled capture not labelled contested")
	_check(
		"Clear contested relays" in game.objective_text(), "Stalled uplink lacks clearance guidance"
	)
	await _review("contested")
	actor.position = Vector3(5, 0, 5)
	defender.position = Vector3(5, 0, 5)
	game.battlefield.invalidate()
	await _frames(90)
	_check(
		relay.progress == held and not relay.contested, "Vacancy changed stored capture progress"
	)
	_check("Capture held" in game.hud._relay_labels[0].text, "Vacant partial capture hidden")
	await _review("vacant")
	var tank = _units(game._get_human_player(), "Tank")[0]
	tank.position = capture_point + Vector3(-1.5, 0, 0)
	game.battlefield.invalidate()
	await _frames(90)
	_check(relay.contested and relay.progress == held, "Armor changed capture or contest rules")
	_check(
		"Infantry needed" in game.hud._relay_labels[0].text,
		"Armor-only presence asks for more combat"
	)
	_check("Move infantry" in game.objective_text(), "Armor-only uplink lacks infantry guidance")
	_check(
		"Clear opposing" not in game.hud._relay_labels[0].tooltip_text,
		"Armor-only tooltip asks for combat"
	)
	await _review("infantry-needed")
	tank.position = Vector3(5, 0, 5)
	game.battlefield.invalidate()
	actor.position = capture_point + Vector3(-1.5, 0, 0)
	game.battlefield.invalidate()
	await _frames(660)
	_check(relay.captured_by == game._get_human_player(), "Recapture failed to complete")
	_check("Secured" in game.hud._relay_labels[0].text, "Completed capture retained stale guidance")
	await _review("secured")
	actor.position = Vector3(5, 0, 5)
	defender.position = capture_point + Vector3(1.5, 0, 0)
	game.battlefield.invalidate()
	await _frames(120)
	_check(
		"Enemy capture" in game.hud._relay_labels[0].text,
		"Enemy takeover hidden by contested label"
	)
	await _review("enemy")
	await _cleanup()
	await _restore_display()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(archive)
	for message in errors:
		push_error(message)
	print("Relay feedback: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _prepare_display():
	pass


func _restore_display():
	pass


func _review(_label):
	pass
