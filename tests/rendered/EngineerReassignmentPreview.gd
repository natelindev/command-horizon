extends "res://tests/rendered/CargoReturnPreview.gd"


func _run():
	var archive = ""
	var unit_id = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--archive="):
			archive = argument.trim_prefix("--archive=")
		if argument.begins_with("--unit="):
			unit_id = argument.trim_prefix("--unit=")
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
	if archive == "" or unit_id == "" or capture_prefix == "":
		push_error("Supply --archive, --unit and a fresh --captures prefix")
		quit(2)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	root.get_node("SaveManager").autosaves_enabled = false
	await create_timer(2).timeout
	var snapshot = FileStore.new().read_file(archive)
	var restore = Restore.new()
	var result = await restore.restore(self, snapshot)
	_check(result.ok, "Alternative-work archive could not be restored")
	if not result.ok:
		quit(1)
		return
	game = result.game
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var worker = restore.entities.get(unit_id)
	_check(is_instance_valid(worker) and worker.type == "Worker", "Invalid archived engineer")
	if not is_instance_valid(worker):
		quit(1)
		return
	_check(
		worker.manual_orders.pending.any(func(order): return order.kind == "gather"),
		"Selected engineer has no earned pending gather order"
	)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(24)
	camera.set_position_safely(worker.position)
	var owner = worker.player
	var before = [
		game.simulation_time,
		owner.resource_a,
		owner.resource_b,
		worker.action,
		worker.manual_orders.pending.duplicate(true)
	]
	await _select_units([worker])
	await _frames(10)
	_check(
		(
			paused
			and (
				before
				== [
					game.simulation_time,
					owner.resource_a,
					owner.resource_b,
					worker.action,
					worker.manual_orders.pending
				]
			)
		),
		"Review selection changed earned state"
	)
	await _capture("assigned")
	await _wait_input(func(): return not paused, "Alternative work: press Space for twenty seconds")
	var start = worker.position
	var loaded = Vector2i(worker.resource_a, worker.resource_b)
	var delivered = Vector2i.ZERO
	var peak = loaded
	for frame in 1200:
		await _frames(1)
		if not is_instance_valid(worker) or worker.is_queued_for_deletion():
			break
		var cargo = Vector2i(worker.resource_a, worker.resource_b)
		peak = Vector2i(maxi(peak.x, cargo.x), maxi(peak.y, cargo.y))
		if cargo == Vector2i.ZERO and loaded != Vector2i.ZERO:
			var hqs = _units(owner, "CommandCenter")
			if hqs.any(
				func(hq):
					return (
						worker.position.distance_to(hq.position) < worker.radius + hq.radius + 1.0
					)
			):
				delivered += loaded
		loaded = cargo
	game.hud._toggle_pause()
	_check(game.simulation_time > before[0], "Alternative-work battle did not resume")
	print(
		"EARNED ALTERNATIVE ",
		unit_id,
		" elapsed=",
		game.simulation_time - before[0],
		" alive=",
		is_instance_valid(worker),
		" travel=",
		worker.position.distance_to(start) if is_instance_valid(worker) else -1,
		" peak_cargo=",
		peak,
		" delivered_near_hq=",
		delivered
	)
	await _frames(6)
	await _capture("continued")
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Earned engineer reassignment review: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
