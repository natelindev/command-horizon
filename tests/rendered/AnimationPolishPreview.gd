extends "res://tests/headless/AnimationPolishRegression.gd"

const OUTPUT = "res://art/animation-polish/"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var original_reduced = root.get_node("Globals").options.reduced_flashes
	root.get_node("Globals").options.reduced_flashes = false
	Engine.time_scale = 1.0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = root.size
	await _fixture("bastion")
	_game.hud.hide()
	_game.get_node("HUD").hide()
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(13)
	camera.set_position_safely(Vector3(28, 0, 18))
	var tank = _spawn("Tank", 0, Vector3(26, 0, 18))
	var rover = _spawn("Worker", 0, Vector3(30, 0, 18))
	var artillery = _spawn("AdvancedTank", 0, Vector3(29, 0, 22))
	var actors = [tank, rover, artillery]
	var capture_video = "--capture" in OS.get_cmdline_user_args()
	for unit in actors:
		unit.get_node("BastionVisuals").process_mode = Node.PROCESS_MODE_PAUSABLE
	await _frames(20)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var ignored = FileAccess.open(OUTPUT + ".gdignore", FileAccess.WRITE)
	ignored.close()
	tank.rotation.y = .5
	await _frames(20)
	await _capture("01-rest")
	var renderer = _game.get_node("UnitBatchRenderer")
	if "--enable-native-kernels" in OS.get_cmdline_user_args():
		_check(renderer._units.has(tank), "Tank hull lost GPU batching")
	for frame in 150:
		for unit in actors:
			if frame < 60:
				unit.position.z -= .035
			elif frame < 90:
				unit.rotation.y += .018
		if frame == 20:
			_game.hud.command_feedback._add_marker(Vector3(25, 0, 14), "move", "Move", true)
		if frame == 95:
			_game.hud.command_feedback._add_marker(Vector3(24, 0, 15), "attack", "Attack", true)
			tank.get_node("Selection").select()
			tank.get_node("BastionVisuals").fire_recoil()
			var origin = tank.get_node("ProjectileOrigin").global_position
			_game.combat_effects.shot(tank, origin, origin + Vector3.FORWARD * 12.0, .15)
			_check(
				not _game.combat_effects._weapon_heat.entries.is_empty(),
				"Heavy shot did not create heat"
			)
		if frame == 105:
			artillery.get_node("BastionVisuals").fire_recoil()
			var origin = artillery.get_node("ProjectileOrigin").global_position
			_game.combat_effects.shot(artillery, origin, origin + Vector3.FORWARD * 12.0, .15)
		await process_frame
		if capture_video and frame % 2 == 0:
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(OUTPUT + "frame-%03d.png" % (frame / 2))
		if frame in [25, 72, 99, 109, 149]:
			await _capture("motion-%03d" % frame)
	for unit in actors:
		var visual = unit.get_node("BastionVisuals")
		if visual._pose_hierarchy != null and visual._track_motion != null:
			_check(
				visual._geometry.global_transform.is_equal_approx(
					visual._pose_hierarchy.root.transform
				),
				"Native tracks detached from GPU hull"
			)
	# Test runtime shader code for both native and palette foliage materials.
	if _game.combat_effects.foliage != null:
		_game.combat_effects.foliage.impulse(tank.position, 6.0)
	var heat = _game.combat_effects._weapon_heat
	heat.shot(tank)
	_check(not heat.entries.is_empty(), "Heavy fire never generated barrel heat")
	paused = true
	await process_frame
	var held_heat = heat.entries.map(func(entry): return entry.heat)
	var held_foliage = _game.combat_effects.foliage._ages
	await _frames(6)
	_check(
		held_heat == heat.entries.map(func(entry): return entry.heat),
		"Barrel heat advanced during tactical pause"
	)
	_check(
		held_foliage == _game.combat_effects.foliage._ages, "Foliage advanced during tactical pause"
	)
	var options = root.get_node("Globals").options
	var reduced = options.reduced_flashes
	options.reduced_flashes = true
	options.changed.emit()
	await _frames(3)
	_check(heat.entries.is_empty(), "Reduced flashes retained muzzle heat during pause")
	_check(_game.combat_effects.foliage._ages.x == 10.0, "Reduced flashes retained foliage impulse")
	options.reduced_flashes = reduced
	options.changed.emit()
	paused = false
	_game.combat_effects.destruction(tank)
	_check(
		_game.combat_effects._cook_offs.is_empty(), "Turret launched before the delayed cook-off"
	)
	tank.queue_free()
	var soldier = _spawn("Infantry", 0, Vector3(24, 0, 18))
	soldier.get_node("BastionVisuals").hit_reaction(soldier.position + Vector3.FORWARD, true)
	_game.combat_effects.destruction(soldier)
	_check(
		_game.combat_effects.aftermath.debris.any(
			func(entry): return entry.node.name == "DroppedWeapon"
		),
		"Blast did not detach the infantry weapon"
	)
	soldier.queue_free()
	await _frames(35)
	await _capture("02-collapse")
	await _frames(140)
	await _capture("03-cookoff")
	_check(
		(
			_game
			. combat_effects
			. _wrecks
			. filter(func(entry): return not entry.infantry)
			. all(func(entry): return entry.secondary)
		),
		"Delayed cook-off never fired"
	)
	_check(
		_game.combat_effects._cook_offs.size() <= _game.combat_effects.MAX_COOK_OFFS,
		"Cook-off pool exceeded cap"
	)
	root.get_node("Globals").options.reduced_flashes = original_reduced
	await _close()
	for message in _errors:
		push_error(message)
	print("Animation polish rendered preview: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _capture(label):
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	print("Captured ", label)
