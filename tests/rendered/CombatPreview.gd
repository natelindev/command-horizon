extends SceneTree

const Catalog = preload("res://source/match/BastionCatalog.gd")
var _game
var _errors = []
var _preferences
var _original_options


func _initialize():
	call_deferred("_run")


func _run():
	Engine.max_fps = 60
	_preferences = root.get_node("Globals").options
	_original_options = _preferences.capture()
	_preferences.reduced_flashes = false
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if side == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "bastion" if side == 0 else "helix"
		player.color = Color("e3ad48") if side == 0 else Color("38c8ce")
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	var players = get_nodes_in_group("players")
	players[1].set_process(false)
	for unit in get_nodes_in_group("units"):
		if unit.type != "CommandCenter":
			unit.queue_free()
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(22)
	camera.set_position_safely(Vector3(29, 0, 17))
	var armies = [[], []]
	var roster = [
		"Tank",
		"Tank",
		"CombatRobot",
		"CombatRobot",
		"AdvancedTank",
		"Helicopter",
		"Infantry",
		"Infantry",
		"Infantry",
		"Infantry"
	]
	for side in range(2):
		for index in range(roster.size()):
			var unit = load(Catalog.scene_path(roster[index])).instantiate()
			var point = Vector3(23 if side == 0 else 35, 0, 9 + index * 1.5)
			_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), players[side], false)
			armies[side].append(unit)
	for _index in range(90):
		await process_frame
	for side in range(2):
		for unit in armies[side]:
			unit.action = load("res://source/match/units/actions/AttackMoving.gd").new(
				Vector3(34 if side == 0 else 24, 0, unit.global_position.z)
			)
	var directory = "res://art/skirmish/combat-frames"
	DirAccess.make_dir_recursive_absolute(directory)
	var ignore_file = FileAccess.open(directory + "/.gdignore", FileAccess.WRITE)
	ignore_file.close()
	var capture_video = "--capture" in OS.get_cmdline_user_args()
	for frame in range(480):
		await process_frame
		if frame in [120, 240, 360] or (capture_video and frame % 2 == 0):
			await RenderingServer.frame_post_draw
			var image = root.get_texture().get_image()
			if frame in [120, 240, 360]:
				image.save_png("res://art/skirmish/combat-%d.png" % frame)
			if capture_video and frame % 2 == 0:
				image.save_jpg(directory + "/frame-%04d.jpg" % (frame / 2), 0.9)
	var effects = _game.combat_effects
	assert(effects.shots_emitted > 20 and effects.impacts_emitted > 10)
	assert(effects.deaths_emitted > 0, "No destruction animation exercised")
	assert(effects._tracers.size() <= effects.MAX_TRACERS)
	assert(effects._wrecks.size() <= effects.MAX_WRECKS)
	assert(effects.aftermath.scars.size() > 0, "Actual battle left no ground scars")
	assert(effects.aftermath.debris.size() <= 32, "Debris exceeded visual clutter budget")
	var scar_ages = effects.aftermath.scars.map(func(entry): return entry.age)
	# Effects must remain frozen during tactical pause, including server particles.
	paused = true
	await process_frame
	var shots = effects.shots_emitted
	var time_before = _game.simulation_time
	var ages = effects._tracers.map(func(entry): return entry.age)
	for _index in range(12):
		await process_frame
	assert(effects.shots_emitted == shots and _game.simulation_time == time_before)
	assert(effects._tracers.map(func(entry): return entry.age) == ages)
	for emitter in effects._emitters.values():
		assert(emitter.speed_scale == 0.0)
	assert(effects.aftermath.scars.map(func(entry): return entry.age) == scar_ages)
	paused = false
	await process_frame
	# Controlled impact in an open patch verifies all layers at known ages.
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var point = Vector3(28, 0.4, 21)
	effects._explosion(point, 1.5, true)
	for frame in range(180):
		await process_frame
		if frame in [6, 35, 170]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://art/skirmish/impact-%d.png" % frame)
	print(
		"PASS: combat animation shots=",
		effects.shots_emitted,
		" impacts=",
		effects.impacts_emitted,
		" deaths=",
		effects.deaths_emitted,
		"; pause and bounded effect pools"
	)
	_game.queue_free()
	for _index in range(8):
		await process_frame
	_preferences.restore(_original_options)
	quit()
