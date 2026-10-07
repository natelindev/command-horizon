extends "res://tests/rendered/CargoReturnPreview.gd"

const EVIDENCE = "res://docs/playtests/2026-10-06/engineer-survival/"


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
	if capture_prefix == "":
		push_error("Supply a fresh --captures=<prefix>; native Space input required")
		quit(2)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	for index in [2, 6]:
		for stage in ["worker_withdrawal", "worker_cargo_delivered"]:
			var label = "%d-%s" % [index, stage]
			var file = FileStore.new()
			var record = file.read_file(
				EVIDENCE + "earned-%d-case%d-10-%s.json" % [index, index, stage]
			)
			_check(record != null, "Earned worker archive unavailable: " + label)
			if record == null:
				continue
			var restore = Restore.new()
			var result = await restore.restore(self, record)
			_check(result.ok, "Earned worker archive rejected: " + label)
			if not result.ok:
				continue
			game = result.game
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1280, 720)
			var player = game._get_human_player()
			var candidates = _units(player, "Worker").filter(
				func(unit):
					if stage == "worker_withdrawal":
						return unit.manual_orders.pending.any(
							func(order): return order.kind == "move"
						)
					return (
						unit.action != null
						and unit.action.has_method("needs_assignment")
						and unit.action.needs_assignment()
						and unit.resource_a + unit.resource_b == 0
					)
			)
			_check(
				not candidates.is_empty(), "Archive has no worker with the expected pending order"
			)
			if not candidates.is_empty():
				var worker = candidates[0]
				var camera = game.get_node("IsometricCamera3D")
				camera.set_physics_process(false)
				camera.set_size_safely(24)
				camera.set_position_safely(worker.position)
				var before = [
					game.simulation_time,
					player.resource_a,
					player.resource_b,
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
								player.resource_a,
								player.resource_b,
								worker.action,
								worker.manual_orders.pending
							]
						)
					),
					"Review selection changed earned state"
				)
				await _capture(label + "-paused")
				var start = worker.position
				await _wait_input(
					func(): return not paused, label + ": press Space for live continuation"
				)
				await create_timer(2.0).timeout
				game.hud._toggle_pause()
				_check(game.simulation_time > before[0], "Earned battle did not resume")
				print(
					"EARNED WORKER ",
					label,
					" elapsed=",
					game.simulation_time - before[0],
					" survived=",
					is_instance_valid(worker),
					" travel=",
					worker.position.distance_to(start) if is_instance_valid(worker) else -1
				)
				await _frames(6)
				await _capture(label + "-continued")
			paused = false
			game.queue_free()
			await _frames(5)
	options.restore(original)
	for error in errors:
		push_error(error)
	print("Earned engineer survival review: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
