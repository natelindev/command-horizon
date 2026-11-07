extends "res://tests/rendered/RayBeamPreview.gd"

# Actual prism routing at normal battle distance, plus isolated role lifecycles.
const ROLE_OUTPUT = "res://art/prism-roles/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("PrismRolesPreview requires a graphical renderer")
		quit(1)
		return
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"day_cycle": false,
			"weather": 1,
			"time_of_day": 0,
			"graphics_dof": false,
			"living_world": false,
			"reduced_flashes": false
		}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROLE_OUTPUT))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	await _skirmish("helix", "res://source/match/maps/IndustrialCrossroads.tscn")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	for layer in game.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.hide()
		# Keep existing armies out of the real spatial query for this fixture.
		unit.global_position = Vector3(10, 0, 10)
	var terrain = game.map.get_node("Geometry/Terrain")
	for mesh in game.map.find_children("*", "GeometryInstance3D", true, false):
		if mesh != terrain:
			mesh.hide()
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var shooter = _spawn("AdvancedTank", human, ORIGIN + Vector3(-4, 0, 0))
	var feeder = _spawn("AntiGroundTurret", human, ORIGIN + Vector3(-5, 0, 4))
	var targets = []
	for offset in [Vector3(3, 0, -1), Vector3(5, 0, 1), Vector3(4, 0, 4)]:
		targets.append(_spawn("Tank", enemy, ORIGIN + offset))
	shooter.rotation.y = -PI * .5
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(18)
	camera.set_position_safely(ORIGIN + Vector3(0, .4, 1))
	var effects = game.combat_effects
	effects.set_physics_process(false)
	effects.set_process(false)
	await _frames(15)
	for unit in [shooter, feeder] + targets:
		var visuals = unit.get_node_or_null("BastionVisuals")
		if visuals != null:
			visuals._advance_pose(1.0 / 60.0)
			visuals._publish_simulation_pose()
			visuals._sync_muzzle()
	paused = true
	var baseline = await _role_capture("baseline")
	game.battlefield.invalidate()
	var health = targets.map(func(unit): return unit.hp + unit.shields)
	paused = false
	game.projectile_system.launch(shooter, targets[0])
	paused = true
	var roles = effects._tracers.map(
		func(entry): return entry.beam_material.get_shader_parameter("beam_role")
	)
	_check(
		roles.count(0) == 1 and roles.count(1) == 1 and roles.count(2) == 2,
		"Real prism launch did not route one primary, one feeder and two refractions: " + str(roles)
	)
	for index in targets.size():
		_check(
			targets[index].hp + targets[index].shields < health[index],
			"Visual role routing lost immediate refraction damage"
		)
	for frame in 22:
		var pixels = await _role_capture("network-%02d" % frame)
		if frame == 2:
			_check(_changed_pixels(baseline, pixels) > 100, "Prism network is invisible")
		effects._advance_tracers(1.0 / 60.0)
	_check(effects._tracers.is_empty(), "Prism network retained expired beams")
	# Isolate each role at the same scale/age for direct appearance comparison.
	for emitter in effects._emitters.values():
		emitter.hide()
	effects.aftermath.clear_flashes()
	var origin = game.projectile_system.muzzle_of(shooter, targets[0].global_position)
	var endpoint = game.projectile_system.center_of(targets[0])
	var weapons = load("res://source/match/combat/WeaponCatalog.gd")
	for role in ["primary", "link", "refraction", "thermal"]:
		var weapon = (
			weapons.THERMAL_BEAM
			if role == "thermal"
			else weapons.PRISM_BEAM.merged({"beam_role": role})
		)
		paused = false
		effects.shot(shooter, origin, endpoint, .22, false, null, true, weapon)
		paused = true
		_check(effects._tracers.size() == 1, "Missing isolated " + role + " beam")
		if effects._tracers.is_empty():
			continue
		effects.aftermath.clear_flashes()
		for age in [0.0, .06, .12]:
			effects._tracers[0].age = age
			effects._update_tracer(effects._tracers[0])
			await _role_capture("%s-%03dms" % [role, roundi(age * 1000)])
		options.reduced_flashes = true
		effects._update_tracer(effects._tracers[0])
		await _role_capture(role + "-reduced")
		options.reduced_flashes = false
		effects._advance_tracers(1.0)
	game.queue_free()
	await _frames(5)
	paused = false
	options.restore(original)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("Prism role preview: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _role_capture(label):
	await process_frame
	RenderingServer.force_draw()
	var pixels = root.get_texture().get_image()
	_check(pixels != null and not pixels.is_empty(), "Empty capture: " + label)
	_check(pixels.save_png(ROLE_OUTPUT + label + ".png") == OK, "Cannot save " + label)
	return pixels
