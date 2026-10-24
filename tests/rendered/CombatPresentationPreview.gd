extends "res://tests/headless/SaveRestoreEdges.gd"

const OUTPUT = "res://art/combat-presentation/"
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
		push_error("CombatPresentationPreview requires a graphical renderer")
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
			"reduced_flashes": false
		}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	for faction in ["bastion", "helix", "frontier"]:
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
		var subjects = []
		for index in 3:
			var role = ["Tank", "Infantry", "Worker"][index]
			var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
			var point = ORIGIN + Vector3((index - 1) * 3.2, 0, 0)
			game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), human, false)
			unit.rotation.y = .8
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			unit.get_node("Selection").select()
			subjects.append(unit)
		var camera = game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.size_min = 1
		camera.set_size_safely(7)
		camera.set_position_safely(ORIGIN + Vector3(0, .2, 0))
		await _frames(20)
		paused = true
		var tank = subjects[0]
		tank.hp = tank.hp_max * .45
		var before_hit = await _capture(faction + "-selection-damage")
		game.combat_effects._material_hit(tank)
		_check(
			not game.combat_effects._hit_flashes.is_empty(), "Visible hit did not create emission"
		)
		if not game.combat_effects._hit_flashes.is_empty():
			_check(
				not game.combat_effects._hit_flashes[0].surfaces.is_empty(),
				"Hit pulse has no model surfaces"
			)
		var after_hit = await _capture(faction + "-material-hit")
		_check(
			_changed_pixels(before_hit, after_hit) > 100,
			"Material hit emission is not visible: " + faction
		)
		game.combat_effects._advance_hit_flashes(1.0)
		if faction == "bastion":
			game.combat_effects._shockwave(ORIGIN + Vector3(-3.2, 0, 0), 2.0)
			_check(
				not game.combat_effects._shockwaves.is_empty(),
				"Visible explosion did not create a shockwave"
			)
			game.combat_effects._advance_hit_flashes(.26)
			var wave = await _capture("heavy-shockwave")
			_check(_changed_pixels(before_hit, wave) > 100, "Heavy shockwave is not visible")
			game.combat_effects._advance_hit_flashes(1.0)
			# Advance the production wreck path for eight seconds, including the
			# detached turret's physics and particle emission, before freezing it.
			game.combat_effects._wreck(tank, false)
			tank.free()
			var wreck = game.combat_effects._wrecks.back()
			paused = false
			await _frames(500)
			paused = true
			_check(
				wreck.age > 7.0 and wreck.age < 12.0,
				"Persistent burn capture missed its review interval"
			)
			await _capture("persistent-wreck-fire")
			options.reduced_flashes = true
			game.combat_effects._advance_wreck_fire(wreck, .01)
			_check(wreck.light == null, "Reduced-flash preview retained its fire light")
			options.reduced_flashes = false
			var worker = subjects[2]
			worker.process_mode = Node.PROCESS_MODE_INHERIT
			worker.get_node("Sparkling").enable()
			paused = false
			await _frames(45)
			paused = true
			_check(
				worker.get_node("Sparkling")._animation.get_node("GPUParticles3D").emitting,
				"Harvesting particle preview did not emit sparks"
			)
			await _capture("worker-harvesting-sparks")
			worker.get_node("Sparkling").disable()
			var resource = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
			var resources = game.map.get_node("Resources")
			resources.add_child(resource)
			resource.global_position = worker.global_position + Vector3(-1.6, 0, 0)
			resource.resource_a = 0
			paused = false
			await _frames(8)
			paused = true
			var decay = resources.find_child("ResourceDecayAnimation", false, false)
			_check(decay != null, "Depleted resource did not create its particle effect")
			await _capture("resource-depletion-particles")
			paused = false
			await _frames(60)
			paused = true
			_check(
				not is_instance_valid(decay), "Depletion particles did not retire after finishing"
			)
		game.queue_free()
		await _frames(5)
		paused = false
	options.restore(original)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	for message in errors:
		push_error(message)
	print("Combat presentation preview: %d failures, %d captures" % [errors.size(), _captures])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


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
