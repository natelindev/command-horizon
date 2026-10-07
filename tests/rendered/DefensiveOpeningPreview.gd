extends "res://tests/rendered/CargoReturnPreview.gd"

const OPENINGS = "res://docs/playtests/2026-10-06/defensive-opening/"


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
	if capture_prefix == "":
		quit(2)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	await create_timer(2).timeout
	for index in [6, 2]:
		var restore = Restore.new()
		var loaded = await restore.restore(
			self,
			FileStore.new().read_file(
				OPENINGS + "earned-%d-case%d-10-opening_contact.json" % [index, index]
			)
		)
		_check(loaded.ok, "Earned opening archive failed to load")
		if not loaded.ok:
			quit(1)
			return
		game = loaded.game
		owner = game._get_human_player()
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_size = Vector2i(1920, 1080)
		var army = _units(owner, "Infantry") + _units(owner, "Tank")
		var clock = game.simulation_time
		var funds = Vector2i(owner.resource_a, owner.resource_b)
		var health = army.map(func(unit): return unit.hp)
		var camera = game.get_node("IsometricCamera3D")
		camera.set_size_safely(30)
		camera.set_position_safely(_units(owner, "CommandCenter")[0].position + Vector3(6, 0, 6))
		await _select_units(army)
		game.fog_of_war._physics_process(0.0)
		await _frames(10)
		_check(
			(
				paused
				and game.simulation_time == clock
				and funds == Vector2i(owner.resource_a, owner.resource_b)
				and health == army.map(func(unit): return unit.hp)
			),
			"Paused earned opening advanced"
		)
		await _capture("%d-contact" % index)
		print("OPENING NATIVE ", index, " original_army=", army.size(), " funds=", funds)
		await _wait_input(func(): return not paused, "Space: continue earned opening")
		while game.simulation_time - clock < 35 and not game.finished:
			await _frames(1)
		game.hud._toggle_pause()
		await _frames(8)
		await _capture("%d-continued" % index)
		print(
			"OPENING CONTINUED ",
			index,
			" seconds=",
			game.simulation_time - clock,
			" survivors=",
			army.filter(func(unit): return is_instance_valid(unit) and unit.hp > 0).size()
		)
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Native defensive opening: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
