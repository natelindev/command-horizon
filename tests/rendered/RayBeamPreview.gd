extends "res://tests/headless/SaveRestoreEdges.gd"

# Run without --headless. Production shot path, deterministic lifecycle captures,
# and a second camera elevation to review the crossed ribbons' volume.
const OUTPUT = "res://art/ray-beams/"
const ORIGIN = Vector3(51, 0, 51)
var _captures = 0


class RenderErrorLog:
	extends Logger
	var messages = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, kind, _backtraces):
		if kind == Logger.ERROR_TYPE_WARNING:
			return
		mutex.lock()
		messages.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("RayBeamPreview requires a graphical renderer; omit --headless")
		quit(1)
		return
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	(
		options
		. restore(
			{
				"screen": 1,
				"edge_scrolling": false,
				"day_cycle": false,
				"weather": 1,
				"time_of_day": 0,
				"graphics_dof": false,
				"living_world": false,
				"reduced_flashes": false,
			}
		)
	)
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, "res://source/match/maps/IndustrialCrossroads.tscn")
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		for layer in game.find_children("*", "CanvasLayer", true, false):
			layer.hide()
		for unit in get_nodes_in_group("units"):
			unit.hide()
		var terrain = game.map.get_node("Geometry/Terrain")
		for mesh in game.map.find_children("*", "GeometryInstance3D", true, false):
			if mesh != terrain:
				mesh.hide()
		var human = game._get_human_player()
		var shooter = _spawn("AdvancedTank", human, ORIGIN + Vector3(-5, 0, 0))
		var target = _spawn("Tank", human, ORIGIN + Vector3(5, 0, 0))
		shooter.rotation.y = -PI * .5
		target.rotation.y = PI * .5
		var camera = game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.size_min = 1
		camera.set_size_safely(9)
		camera.set_position_safely(ORIGIN + Vector3(0, .4, 0))
		var effects = game.combat_effects
		effects.set_physics_process(false)
		effects.set_process(false)
		await _frames(15)
		paused = true
		var baseline = await _capture(faction + "-baseline")
		var muzzle = load("res://source/match/combat/ProjectileSystem.gd").muzzle_of(
			shooter, target.global_position
		)
		var endpoint = target.global_position + Vector3.UP * .8
		paused = false
		effects.shot(shooter, muzzle, endpoint, .16, false, target, true, {"kind": "rail"})
		# Let endpoint particles spawn, then freeze them while beam age is sampled.
		await _frames(2)
		paused = true
		_check(effects._tracers.size() == 1, faction + " did not create a beam")
		var core = await _capture(faction + "-core")
		_check(effects._tracers[0].age == 0.0, "Frozen core preview advanced its beam age")
		_check(_changed_pixels(baseline, core) > 100, faction + " beam is not visible")
		var midpoint = camera.unproject_position((muzzle + endpoint) * .5)
		var core_pixels = _hot_core_pixels(core, midpoint)
		_check(core_pixels > 100, faction + " has no white-hot optical core")
		# Remove endpoint bursts to measure only the residual beam.
		for emitter in effects._emitters.values():
			emitter.hide()
		effects.aftermath.clear_flashes()
		effects._advance_tracers(.09)
		var sheath = await _capture(faction + "-ion-sheath")
		_check(_changed_pixels(baseline, sheath) > 100, faction + " has no residual sheath")
		_check(
			_hot_core_pixels(sheath, midpoint) < core_pixels * .3,
			faction + " optical core did not snap off before its sheath"
		)
		effects._advance_tracers(.12)
		await _capture(faction + "-dissipation")
		effects._advance_tracers(.08)
		var expired = await _capture(faction + "-expired")
		_check(effects._tracers.is_empty(), faction + " beam did not expire")
		_check(
			_changed_pixels(baseline, expired) < _changed_pixels(baseline, core) * .1,
			faction + " left a persistent beam"
		)
		camera.rotation_degrees.x = -25
		camera.set_position_safely(ORIGIN + Vector3(0, .4, 0))
		paused = false
		effects.shot(shooter, muzzle, endpoint, .16, false, target, true, {"kind": "rail"})
		paused = true
		await _capture(faction + "-low-angle")
		game.queue_free()
		await _frames(5)
		paused = false
	options.restore(original)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	for message in errors:
		push_error(message)
	print("Ray beam preview: %d failures, %d captures" % [errors.size(), _captures])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _spawn(role, side, point):
	var catalog = load("res://source/match/FactionCatalog.gd")
	var unit = load(catalog.scene_path(side.faction, role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _capture(label):
	await _frames(3)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels != null and not pixels.is_empty(), "Empty capture: " + label)
	_check(pixels.save_png(OUTPUT + label + ".png") == OK, "Cannot save " + label)
	_captures += 1
	print("Captured ", label)
	return pixels


func _changed_pixels(before, after):
	var previous = before.get_data()
	var current = after.get_data()
	var changed = 0
	for index in current.size():
		if absi(int(current[index]) - int(previous[index])) > 4:
			changed += 1
	return changed


func _hot_core_pixels(pixels, midpoint):
	var count = 0
	for x in range(int(midpoint.x) - 80, int(midpoint.x) + 80):
		for y in range(int(midpoint.y) - 10, int(midpoint.y) + 10):
			var color = pixels.get_pixel(x, y)
			if minf(color.r, minf(color.g, color.b)) > .85:
				count += 1
	return count
