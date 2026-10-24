extends "res://tests/headless/SaveRestoreEdges.gd"

const OUTPUT = "res://art/premium-battle/"
var _captures = 0


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("PremiumBattlePreview requires a renderer")
		quit(1)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"reduced_flashes": false,
			"day_cycle": false,
			"weather": 1,
			"graphics_dof": false
		}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/battlefields/GlacierNarrowsMap.tscn")
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		var camera = game.get_node("IsometricCamera3D")
		var center = game.map.ground_point(Vector2(34, 49))
		camera.set_position_safely(center)
		camera.set_size_safely(18)
		var human = game._get_human_player()
		var controller = human.get_node("UnitActionsController")
		var terrain = game.get_node("Terrain")
		var selection = []
		for index in 12:
			var role = "Tank" if index % 3 == 0 else "Infantry"
			var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
			var point = center + Vector3(-4 + index % 4 * 2, 0, 9 + index / 4 * 2)
			game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), human, false)
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			selection.append(unit)
		root.get_node("MatchSignals").deselect_all_units.emit()
		for unit in selection:
			unit.get_node("Selection").select()
		paused = true
		var pointer = camera.unproject_position(center)
		var press = InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_RIGHT
		press.pressed = true
		press.position = pointer
		terrain._on_input_event(camera, press, center, Vector3.UP, 0)
		terrain.set_process(false)
		terrain._update_formation_preview(pointer + Vector2(120, -40))
		_check(is_instance_valid(terrain._formation_preview), "Missing rendered formation preview")
		if is_instance_valid(terrain._formation_preview):
			var geometry = terrain._formation_preview.mesh.get_faces()
			var heights = Vector2(INF, -INF)
			for vertex in geometry:
				heights.x = minf(heights.x, vertex.y)
				heights.y = maxf(heights.y, vertex.y)
			_check(heights.y - heights.x > .5, "Formation geometry did not follow ramp heights")
		var feedback = game.hud.command_feedback
		feedback._process(3)
		feedback._add_marker(center + Vector3(3, 0, 1), "move", "Move", true)
		feedback._add_marker(center + Vector3(-3, 0, -1), "attack", "Attack target", true)
		feedback.set_process(false)
		await _capture(faction + "-formation-ramp")
		terrain._cancel_drag()
		feedback._process(3)
		# Close view: a short reflected fan and local light on surviving armor.
		var tank = selection[0]
		root.get_node("MatchSignals").deselect_all_units.emit()
		for unit in selection:
			if unit != tank:
				unit.hide()
		tank.get_node("Selection").select()
		tank.global_position = game.map.ground_point(Vector2(34, 57))
		camera.set_position_safely(tank.global_position)
		camera.set_size_safely(6)
		await _frames(4)
		var fx = game.combat_effects
		_check(
			fx._emitters.spark.process_material.get_shader_parameter("directional"),
			"Ricochet sparks are not aligned to velocity"
		)
		var point = tank.global_position + Vector3(.95, .75, .3)
		paused = false
		fx._ricochet(tank, point, Vector3(-.2, 0, -1).normalized())
		var muzzle = tank.global_position + Vector3(0, 1.1, .9)
		fx.shot(tank, muzzle, muzzle + Vector3.BACK * 6, .1, false, null, false)
		await _frames(2)
		paused = true
		_check(not fx.aftermath.lights.is_empty(), "Rendered muzzle flash has no local lighting")
		await _capture(faction + "-armor-ricochet-light")
		options.reduced_flashes = true
		fx._process(0)
		_check(
			fx.aftermath.lights.is_empty(), "Paused accessibility change retained muzzle lighting"
		)
		options.reduced_flashes = false
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Premium battle preview: %d captures, %d failures" % [_captures, errors.size()])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _capture(label):
	await _frames(4)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels != null and not pixels.is_empty(), "Empty capture " + label)
	_check(pixels.save_png(OUTPUT + label + ".png") == OK, "Cannot save " + label)
	_captures += 1
