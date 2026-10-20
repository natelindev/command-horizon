extends SceneTree

# Rendered review of physical rounds: tracers, shells, rockets and guided
# missiles in a mixed ground/air fight. Run without --headless; captures go to
# art/air-combat/projectiles/.

const Catalog = preload("res://source/match/BastionCatalog.gd")
const CAPTURE_DIR = "res://art/air-combat/projectiles"
var _game


func _initialize():
	call_deferred("_run")


func _run():
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	var constants = root.get_node("Constants")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.visibility = settings.Visibility.FULL
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
	camera.set_size_safely(12)
	camera.set_position_safely(Vector3(30, 0, 21))
	var ground = ["Tank", "Tank", "RocketInfantry", "RocketInfantry", "Infantry", "Infantry"]
	var armies = [[], []]
	for side in range(2):
		for index in range(ground.size()):
			armies[side].append(
				_spawn(
					ground[index],
					players[side],
					Vector3(25 if side == 0 else 35, 0, 17 + index * 1.6)
				)
			)
	armies[0].append(_spawn("AntiAirTurret", players[0], Vector3(26, 0, 25)))
	for index in range(2):
		armies[1].append(_spawn("Helicopter", players[1], Vector3(33, 0, 19 + index * 5)))
	for _index in range(90):
		await process_frame
	for side in range(2):
		for unit in armies[side]:
			if unit.movement_speed > 0:
				unit.action = load("res://source/match/units/actions/AttackMoving.gd").new(
					Vector3(33 if side == 0 else 26, 0, unit.global_position.z)
				)
	var system = _game.projectile_system
	var most = 0
	for frame in range(420):
		await process_frame
		most = maxi(most, system.round_count())
		if frame in [60, 75, 150, 240, 330]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(CAPTURE_DIR + "/battle-%d.png" % frame)
	assert(system.rounds_fired > 30, "Too few rounds fired for review")
	assert(most > 0, "No round was ever in flight")
	# Tactical pause freezes rounds where they are.
	while system.round_count() == 0:
		await process_frame
	paused = true
	var positions = system._rounds.map(func(round): return round.position)
	for _index in range(10):
		await process_frame
	assert(system._rounds.map(func(round): return round.position) == positions)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CAPTURE_DIR + "/paused.png")
	paused = false
	print("PASS: projectile preview rounds_fired=", system.rounds_fired, " peak_in_flight=", most)
	_game.queue_free()
	await process_frame
	quit(0)


func _spawn(role, player, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit
