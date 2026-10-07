extends "res://tests/rendered/RelayOverviewPreview.gd"


func _run():
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	for index in [0, 6]:
		await _earned_capture(index)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Earned relay review: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _archive_file(index):
	return (
		"res://docs/playtests/2026-10-06/relay-contest/earned%d-case%d-10-relay_secured.json"
		% [index, index]
	)


func _earned_capture(index):
	var file = _archive_file(index)
	var loaded = await Restore.new().restore(self, FileStore.new().read_file(file))
	_check(loaded.ok, "Earned relay capture did not restore")
	if not loaded.ok:
		return
	game = loaded.game
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var player = game._get_human_player()
	var objective = game.map.relays.filter(func(item): return item.captured_by == player)[0]
	var units = get_nodes_in_group("units").filter(func(unit): return unit.player == player)
	var infantry = units.filter(func(unit): return unit.type == "Infantry")
	infantry.sort_custom(
		func(a, b):
			return (
				a.position.distance_to(objective.position)
				< b.position.distance_to(objective.position)
			)
	)
	root.get_node("MatchSignals").deselect_all_units.emit()
	infantry[0].get_node("Selection").select()
	var clock = game.simulation_time
	var orders = units.map(func(unit): return unit.action)
	var funds = Vector2i(player.resource_a, player.resource_b)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(22)
	camera.set_position_safely(objective.position)
	await _review("case%d-field" % index)
	await _activate(game.hud.find_child("OpenRelays", true, false), "earned ownership")
	var overview = game.hud.find_child("RelayOverview", true, false)
	var row = overview._rows.filter(func(item): return item.relay == objective)[0]
	_check("Yours" in row.status.text, "Earned relay ownership missing from overview")
	await _review("case%d-overview" % index)
	await _activate(row.button, "locate earned relay")
	_check(paused and game.simulation_time == clock, "Relay review changed paused clock")
	_check(
		units.map(func(unit): return unit.action) == orders, "Relay review replaced earned orders"
	)
	_check(Vector2i(player.resource_a, player.resource_b) == funds, "Relay review changed funds")
	await _review("case%d-located" % index)
	paused = false
	game.queue_free()
	await _frames(5)
