extends "res://tests/rendered/CargoReturnPreview.gd"

const EVIDENCE = "res://docs/playtests/2026-10-06/conventional-recovery/"


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
	for index in [2, 6]:
		var restore = Restore.new()
		var loaded = await restore.restore(
			self,
			FileStore.new().read_file(
				EVIDENCE + "earned-%d-case%d-10-infantry_recovery.json" % [index, index]
			)
		)
		_check(loaded.ok, "Earned recovery archive failed to restore")
		if not loaded.ok:
			continue
		game = loaded.game
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_size = Vector2i(1920, 1080)
		var recover = load("res://source/match/units/actions/RecoveringAtService.gd")
		var units = _units(game._get_human_player(), "Infantry").filter(
			func(unit): return is_instance_of(unit.action, recover)
		)
		_check(not units.is_empty(), "Archive contains no recovering infantry")
		if units.is_empty():
			quit(1)
			return
		var unit = units[0]
		var before = [
			game.simulation_time,
			unit.hp,
			unit.action,
			unit.player.resource_a,
			unit.player.resource_b,
			unit.manual_orders.pending.duplicate(true)
		]
		var camera = game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.set_size_safely(24)
		camera.set_position_safely(unit.position)
		await _select_units([unit])
		await _frames(10)
		_check(
			(
				paused
				and (
					before
					== [
						game.simulation_time,
						unit.hp,
						unit.action,
						unit.player.resource_a,
						unit.player.resource_b,
						unit.manual_orders.pending
					]
				)
			),
			"Review selection changed treatment or earned state"
		)
		await _capture("%d-treatment" % index)
		await _wait_input(func(): return not paused, "%d: Space for live treatment" % index)
		var peak = unit.hp / unit.hp_max
		while game.simulation_time - before[0] < 45:
			await physics_frame
			if not is_instance_valid(unit) or unit.is_queued_for_deletion():
				break
			peak = maxf(peak, unit.hp / unit.hp_max)
		game.hud._toggle_pause()
		_check(game.simulation_time > before[0], "Treatment battle did not resume")
		print(
			"NATIVE TREATMENT ",
			index,
			" elapsed=",
			game.simulation_time - before[0],
			" survived=",
			is_instance_valid(unit),
			" peak_health=",
			peak,
			" action=",
			str(unit.action) if is_instance_valid(unit) else "lost"
		)
		await _frames(6)
		await _capture("%d-continued" % index)
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Native conventional recovery: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
