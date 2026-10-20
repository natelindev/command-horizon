extends SceneTree

# Rendered review of fixed-wing operations: taxi, take-off roll, climb, banked
# turns, a bombing pass, approach and landing. Run without --headless; captures
# go to art/air-combat/flight/.

const Catalog = preload("res://source/match/BastionCatalog.gd")
const CAPTURE_DIR = "res://art/air-combat/flight"
const FIELD_CENTER = Vector3(44, 0, 40)
var _game
var _camera
var _phase_names = ["parked", "taxi", "takeoff", "airborne", "approach", "rollout"]


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
	var faction = "bastion"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--faction="):
			faction = argument.get_slice("=", 1)
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			constants.PlayerType.HUMAN if side == 0 else constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = faction if side == 0 else "helix"
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
	_camera = _game.get_node("IsometricCamera3D")
	_camera.set_physics_process(false)
	_camera.set_size_safely(14)
	await _frames(10)
	var field = _spawn("AircraftFactory", players[0], FIELD_CENTER)
	await _frames(10)
	var fighter = _spawn("Fighter", players[0], FIELD_CENTER + Vector3(2, 0, -4))
	var bomber = _spawn("Bomber", players[0], FIELD_CENTER + Vector3(2, 0, 0))
	var tanks = []
	for index in range(3):
		tanks.append(_spawn("Tank", players[1], Vector3(22, 0, 44 + index * 1.6)))
	await _frames(20)
	for tank in tanks:
		tank.process_mode = Node.PROCESS_MODE_DISABLED
	var seen = {}
	_camera.set_position_safely(FIELD_CENTER)
	await _capture("airfield-parked")
	fighter.action = load("res://source/match/units/actions/Moving.gd").new(Vector3(24, 0, 22))
	await _follow(fighter, 900, seen, "fighter")
	bomber.action = load("res://source/match/units/actions/AutoAttacking.gd").new(tanks[0])
	await _follow(bomber, 1500, seen, "bomber", tanks[0])
	bomber.action = load("res://source/match/units/actions/RecoveringAtService.gd").new(field)
	await _follow(bomber, 3000, seen, "bomber-return")
	print("PASS: flight preview phases=", seen.keys())
	_game.queue_free()
	await process_frame
	quit(0)


# Follows an aircraft and captures the first frame of each flight phase plus a
# few mid-phase frames (turns, bomb release, flare).
func _follow(unit, frames, seen, label, watched = null):
	var flight = unit.get_node("Movement")
	var last_phase = -1
	var banked = false
	var released = false
	for frame in range(frames):
		await process_frame
		if not is_instance_valid(unit):
			return
		_camera.set_position_safely(unit.global_position * Vector3(1, 0, 1))
		var phase_name = _phase_names[flight.phase]
		if flight.phase != last_phase:
			last_phase = flight.phase
			seen[label + "-" + phase_name] = true
			await _frames(8)
			await _capture("%s-%s" % [label, phase_name])
		elif not banked and absf(flight.bank) > flight.max_bank * 0.8:
			banked = true
			await _capture(label + "-banked-turn")
		elif not released and "_stick_left" in unit and unit._stick_left > 0 and watched != null:
			released = true
			await _frames(10)
			await _capture(label + "-stick")
		if label == "bomber" and unit.stores.get("bomb", 1) == 0 and released:
			await _frames(40)
			await _capture(label + "-impacts")
			return
		if label.ends_with("return") and flight.is_parked():
			return
		if label == "fighter" and flight.arrived():
			await _frames(30)
			await _capture(label + "-station")
			return


func _capture(name):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CAPTURE_DIR + "/" + name + ".png")


func _spawn(role, player, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _frames(count):
	for _index in range(count):
		await process_frame
