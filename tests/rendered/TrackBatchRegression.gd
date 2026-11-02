extends "res://tests/rendered/UnitBatchRegression.gd"

## Compare the actual raised-shoe geometry and shadows against the ordinary
## renderer after translation, reverse travel, pivoting, wrap and teleporting.
var _track_cases := 0


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	Engine.max_fps = 120
	root.mesh_lod_threshold = 0.0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	var options = root.get_node("Globals").options.capture()
	options.screen = 1
	options.graphics_shadows = true
	options.day_cycle = false
	root.get_node("Globals").options.restore(options)
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/BigArena.tscn")
		paused = true
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = root.size
		var renderer = game.get_node("UnitBatchRenderer")
		_check(renderer._native != null, "Track test requires a real GPU pose palette")
		if renderer._native == null:
			break
		var human = game._get_human_player()
		for branch in ["Decorations", "WorldDressing", "LivingWorld"]:
			var scenery = game.map.get_node_or_null(branch)
			if scenery != null:
				scenery.hide()
		for unit in get_nodes_in_group("units"):
			unit.hide()
		for role in ["Worker", "Tank", "AdvancedTank", "RepairRobot", "CombatRobot"]:
			var factions = load("res://source/match/FactionCatalog.gd")
			var unit = load(factions.scene_path(faction, role)).instantiate()
			game._setup_and_spawn_unit(unit, Transform3D(Basis(), Vector3(40, 0, 40)), human, false)
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			unit.action = null
			await _frames(2)
			var visual = unit.get_node("BastionVisuals")
			if visual._track_motion == null:
				unit.queue_free()
				await _frames(2)
				continue
			await _check_tracks(renderer, unit, faction + "-" + role)
			unit.queue_free()
			await _frames(2)
		paused = false
		game.queue_free()
		await _frames(8)
	_check(_track_cases >= 4, "Authored tracked roles were not exercised")
	for message in errors:
		push_error(message)
	print(
		(
			"Track batch regression: %d failures across %d rendered poses"
			% [errors.size(), _track_cases]
		)
	)
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _check_tracks(renderer, unit, label: String):
	var visual = unit.get_node("BastionVisuals")
	var motion = visual._track_motion
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(5)
	camera.set_position_safely(unit.global_position)
	for step in 5:
		_check(renderer._units.has(unit), "Tracked role did not batch: " + label)
		if not renderer._units.has(unit):
			return
		var entry = renderer._units[unit]
		_check(
			entry.tracks.size() == motion.belts.size(), "A belt escaped the shared batch: " + label
		)
		_check(not motion.has_unbatched_belts(), "Track still uses separate rendering: " + label)
		for tick in 24:
			if step == 1:
				unit.position += -unit.basis.z * .04
			elif step == 2:
				unit.position += unit.basis.z * .03
			elif step == 3:
				unit.rotate_y(.04)
			visual.prepare_gpu_pose(1.0 / 60.0).solve()
			visual.finish_gpu_pose(1.0 / 60.0)
		if step == 4:
			# Different wrapped values on the two belts expose accidental sharing.
			for index in motion.belts.size():
				motion.belts[index].travel = (
					.001 if index % 2 else motion.belts[index].perimeter - .001
				)
				motion._publish_belt(motion.belts[index])
			renderer._upload_poses()
			unit.global_position += Vector3(.1, 0, .1)
		visual._publish_simulation_pose()
		renderer._upload_poses()
		for track in entry.tracks:
			_check(track[1] > 0, "Belt overwrote the root hit-pulse row")
			_check(
				is_equal_approx(
					renderer._last_pixels.decode_float((entry.offset + track[1]) * 64 + 48),
					track[0].travel
				),
				"Belt palette lost actual travel: " + label
			)
		var batching = load("res://source/match/rendering/UnitBatchRenderer.gd")
		var copy = batching.duplicate_geometry(unit.get_node("Geometry"), 0)
		for belt in motion.belts:
			var copies = copy.find_children("*", "MeshInstance3D", true, false).filter(
				func(mesh):
					return (
						mesh.get_meta("track_belt_index", -1)
						== belt.mesh.get_meta("track_belt_index")
					)
			)
			_check(
				(
					not copies.is_empty()
					and is_equal_approx(
						copies[0].get_instance_shader_parameter("track_travel"), belt.travel
					)
				),
				(
					"Wreck/memory clone lost current belt state %s copies=%d actual=%s expected=%s"
					% [
						belt.mesh.name,
						copies.size(),
						(
							copies[0].get_instance_shader_parameter("track_travel")
							if not copies.is_empty()
							else null
						),
						belt.travel
					]
				)
			)
		copy.free()
		await _frames(6)
		await RenderingServer.frame_post_draw
		var batched: Image = root.get_texture().get_image()
		_check(batched.get_size() == Vector2i(1280, 720), "Track comparison raster changed size")
		renderer._invalidate(unit)
		_check(motion.has_unbatched_belts(), "Fallback kept a dead palette binding")
		for belt in motion.belts:
			_check(
				is_equal_approx(
					belt.mesh.get_instance_shader_parameter("track_travel"), belt.travel
				),
				"Fallback lost current travel"
			)
		await _frames(6)
		await RenderingServer.frame_post_draw
		var ordinary: Image = root.get_texture().get_image()
		if step == 0:
			unit.hide()
			await _frames(3)
			await RenderingServer.frame_post_draw
			var hidden: Image = root.get_texture().get_image()
			var body_pixels := 0
			for x in range(360, 920, 2):
				for y in range(100, 550, 2):
					var a := ordinary.get_pixel(x, y)
					var b := hidden.get_pixel(x, y)
					if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > .04:
						body_pixels += 1
			_check(
				body_pixels > 100, "Rendered comparison did not contain the tracked body: " + label
			)
			unit.show()
		DirAccess.make_dir_recursive_absolute("res://tmp/track-batch-review")
		batched.save_png("res://tmp/track-batch-review/%s-%d-gpu.png" % [label, step])
		ordinary.save_png("res://tmp/track-batch-review/%s-%d-ordinary.png" % [label, step])
		_check_material_parity(
			camera, unit.get_node("Geometry"), batched, ordinary, label + " pose " + str(step)
		)
		_track_cases += 1
		renderer._add_unit(unit)


func _skirmish(faction, map_path = "res://source/match/maps/BastionDesert.tscn", advanced = true):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
	settings.advanced_start = advanced
	settings.map_path = map_path
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = faction if index == 0 else "bastion"
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(30)
