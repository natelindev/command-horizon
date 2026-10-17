extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 120
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		var unit = _units(game._get_human_player(), "Infantry")[0]
		unit.action = null
		unit.get_node("Movement").set_physics_process(false)
		unit.get_node("Movement")._synchronized = false
		var camera = game.get_node("IsometricCamera3D")
		camera.set_position_safely(unit.global_position)
		camera.set_physics_process(true)
		var before = camera.global_position
		var key = InputMap.action_get_events("move_map_right")[0].duplicate()
		key.keycode = key.physical_keycode
		key.pressed = true
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		camera._process(1.0 / 240.0)
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		_check(
			camera.global_position.distance_to(before) > 0.001, "Camera waited for physics input"
		)
		camera.set_physics_process(false)
		var advance = func(): unit.position.x += 0.1
		physics_frame.connect(advance)
		var geometry = unit.get_node("Geometry")
		var visual = unit.get_node("BastionVisuals")
		var previous_root = unit.global_position
		var previous_model = geometry.global_position
		var between_ticks = 0
		for index in 100:
			await RenderingServer.frame_post_draw
			var expected = unit.get_global_transform_interpolated() * visual._geometry_pose
			_check(
				geometry.global_transform.is_equal_approx(expected),
				"Visual root did not interpolate: " + faction
			)
			if (
				unit.global_position == previous_root
				and geometry.global_position.distance_to(previous_model) > 0.0001
			):
				between_ticks += 1
			previous_root = unit.global_position
			previous_model = geometry.global_position
		physics_frame.disconnect(advance)
		_check(between_ticks >= 10, "Model still moves only on physics ticks: " + faction)
		var authority = unit.global_transform
		visual.fire_recoil()
		_check(unit.global_transform == authority, "Recoil changed simulation position")
		_check(
			geometry.transform.is_equal_approx(visual._geometry_pose),
			"Shot sampled an interpolated muzzle"
		)
		paused = true
		await _frames(3)
		_check(
			geometry.transform.is_equal_approx(visual._geometry_pose),
			"Pause retained render offset"
		)
		paused = false
		print("SMOOTH ", faction, " between_tick_frames=", between_ticks)
		game.queue_free()
		await _frames(5)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Frame pacing regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
