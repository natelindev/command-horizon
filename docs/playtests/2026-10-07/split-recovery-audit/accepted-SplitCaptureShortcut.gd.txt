extends "res://tests/headless/SplitSignalRegression.gd"

var prefix = "res://docs/playtests/2026-10-07/split-recovery-audit/shortcut"


func _run():
	path = "user://split-shortcut-%d.json" % OS.get_process_id()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="):
			prefix = argument.trim_prefix("--evidence=")
	await _prepare_display()
	var data = Store.new().read_file(
		"res://docs/playtests/2026-10-07/split-recovery-audit/headless-archive.json"
	)
	var restore = Restore.new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "Stranded infantry archive failed to restore")
	if not loaded.ok:
		quit(2)
		return
	game = loaded.game
	game.progress_path = path
	for record in data.units:
		var unit = restore.entities[record.id]
		_check(
			unit.position == record.position and unit.hp == record.hp,
			"Shortcut load changed position/HP"
		)
	await _frames(8)
	if "_infantry_buttons" not in game.hud:
		push_error("Missing infantry recovery shortcut")
		quit(1)
		return
	var human = game._get_human_player()
	var infantry = _units(human, "Infantry")
	_check(infantry.size() == 1, "Earned archive no longer contains the stranded infantry")
	var actor = infantry[0]
	var action = actor.action
	var orders = actor.manual_orders.pending.duplicate(true)
	var funds = Vector2(human.resource_a, human.resource_b)
	var time = game.simulation_time
	_check(game.hud._infantry_buttons[0].visible, "Missing-infantry shortcut hidden")
	_check(game.hud._infantry_buttons[0].text == "Find infantry", "Existing infantry overlooked")
	await _activate(game.hud._infantry_buttons[0])
	_check(actor.is_in_group("selected_units"), "Shortcut did not find earned idle infantry")
	_check(
		actor.action == action and actor.manual_orders.pending == orders, "Shortcut replaced orders"
	)
	_check(Vector2(human.resource_a, human.resource_b) == funds, "Shortcut spent resources")
	_check(paused and time == game.simulation_time, "Shortcut advanced paused battle")
	await _review("found")
	await _activate(game.hud._relay_buttons[0])
	await _capture_order(actor, game.map.relays[0].position + Vector3(0, 0, 1.9))
	await _frames(5)
	_check(
		actor.get_node("Movement")._has_destination or not actor.manual_orders.pending.is_empty(),
		"Explicit capture order was not accepted"
	)
	_check(paused and time == game.simulation_time, "Capture order advanced paused clock")
	await _review("ordered")
	game.hud._toggle_pause()
	while not game.finished and game.simulation_time - time < 60:
		await _frames(30)
	_check(
		game.finished and game.result == "Victory", "Earned idle infantry did not complete uplink"
	)
	print("SHORTCUT RECOVERY elapsed=", game.simulation_time - time)
	await _review("victory")
	await _cleanup()
	await _make_match()
	await _fallback()
	await _cleanup()
	await _restore_display()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Split capture shortcut: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _fallback():
	var human = game._get_human_player()
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		if unit.movement_speed > 0:
			unit.position = Vector3(5, 0, 5)
	var relay = game.map.relays[0]
	relay.captured_by = game._enemy
	_units(human, "Tank")[0].position = relay.position + Vector3(-1.5, 0, 0)
	game.battlefield.invalidate()
	await _frames(3)
	game.hud._toggle_pause()
	var infantry = _units(human, "Infantry")
	infantry[0].manual_orders.submit({"kind": "move", "point": Vector3(30, 0, 30)})
	infantry[0].position = relay.position + Vector3(0, 0, 5)
	await _frames(3)
	await _activate(game.hud._infantry_buttons[0])
	_check(
		not infantry[0].is_in_group("selected_units"),
		"Shortcut prefers busy nearby infantry over idle"
	)
	var preserved = infantry[0].manual_orders.pending.duplicate(true)
	for index in range(1, infantry.size()):
		infantry[index].queue_free()
	await _frames(3)
	await _activate(game.hud._infantry_buttons[0])
	_check(
		infantry[0].is_in_group("selected_units"),
		"Busy infantry cannot be found when it is the only survivor"
	)
	_check(
		infantry[0].manual_orders.pending == preserved, "Finding busy infantry changed its queue"
	)
	infantry[0].queue_free()
	await _frames(4)
	var barracks = _units(human, "Barracks")[0]
	var queue = barracks.get_node("ProductionQueue")
	var funds = Vector2(human.resource_a, human.resource_b)
	_check(game.hud._infantry_buttons[0].text == "Find barracks", "No-infantry fallback is missing")
	await _activate(game.hud._infantry_buttons[0])
	_check(barracks.is_in_group("selected_units"), "Fallback did not select barracks")
	_check(
		queue.size() == 0 and Vector2(human.resource_a, human.resource_b) == funds,
		"Fallback trained automatically"
	)
	await _review("barracks")
	barracks.queue_free()
	await _frames(4)
	_check(game.hud._infantry_buttons[0].disabled, "Missing barracks leaves actionable shortcut")
	_check(
		"Build a barracks" in game.hud._infantry_buttons[0].tooltip_text,
		"Missing barracks lacks recovery help"
	)
	await _review("no-barracks")


func _activate(button):
	button.pressed.emit()
	await _frames(3)


func _capture_order(unit, point):
	unit.manual_orders.submit({"kind": "move", "point": point})


func _review(_label):
	pass


func _prepare_display():
	pass


func _restore_display():
	pass
