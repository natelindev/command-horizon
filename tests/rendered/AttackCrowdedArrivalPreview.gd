extends "res://tests/rendered/CargoReturnPreview.gd"

const ARCHIVE = "res://docs/playtests/2026-10-06/engineer-reassignment/reassigned-2-stationary.json"


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
	if capture_prefix == "":
		push_error("Supply a fresh --captures prefix")
		quit(2)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	await create_timer(2).timeout
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(ARCHIVE))
	_check(loaded.ok, "Earned attack archive failed to restore")
	if not loaded.ok:
		quit(1)
		return
	game = loaded.game
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var unit = restore.entities["unit-16"]
	var action = unit.action
	var point = unit.position
	var started = game.simulation_time
	var funds = Vector2i(unit.player.resource_a, unit.player.resource_b)
	var pending = unit.manual_orders.pending.duplicate(true)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(24)
	camera.set_position_safely(unit.position)
	await _select_units([unit])
	await _frames(10)
	_check(
		(
			paused
			and game.simulation_time == started
			and unit.action == action
			and unit.position == point
			and unit.manual_orders.pending == pending
			and funds == Vector2i(unit.player.resource_a, unit.player.resource_b)
		),
		"Review selection changed the earned battle"
	)
	await _capture("paused")
	await _wait_input(func(): return not paused, "Crowded AttackMove: press Space")
	var arrived = -1.0
	while game.simulation_time - started < 6:
		await physics_frame
		if arrived < 0 and unit.action != action:
			arrived = game.simulation_time - started
	game.hud._toggle_pause()
	_check(arrived > 0 and arrived < 6, "Native earned AttackMove remained stuck")
	_check(unit.position.distance_to(point) < 1, "Native arrival abandoned its location")
	_check(not unit.get_node("Movement")._has_destination, "Native arrival retained movement")
	print(
		"NATIVE ATTACK ARRIVAL seconds=",
		arrived,
		" displacement=",
		unit.position.distance_to(point),
		" action=",
		unit.action
	)
	await _frames(6)
	await _capture("arrived")
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Native crowded attack arrival: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
