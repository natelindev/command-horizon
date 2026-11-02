extends "res://tests/headless/StructureCollapseRegression.gd"

const OUTPUT = "res://art/structure-collapse/"
var _output = OUTPUT


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Structure collapse preview needs a renderer; omit --headless")
		quit(1)
		return
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_output += "opengl/"
	_factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore(
		{
			"screen": 1,
			"interface_scale": 1.5,
			"edge_scrolling": false,
			"day_cycle": false,
			"weather": 1
		}
	)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	for faction in ["bastion", "helix", "frontier"]:
		await _preview(faction)
		paused = false
		game.queue_free()
		await _frames(5)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Structure collapse preview: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _preview(faction):
	await _skirmish(faction, "res://source/match/maps/PlainAndSimple.tscn", false)
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var handler = game.get_node("Handlers/UnitVisibilityHandler")
	for unit in game.get_tree().get_nodes_in_group("units"):
		handler._recalculate_unit_visibility(unit)
	game.fog_of_war._physics_process(0.0)
	_freeze()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(18.0)
	camera.set_position_safely(Vector3(25, 0, 25))
	var building = _unit("VehicleFactory", game._get_human_player(), Vector3(25, 0, 25))
	await _frames(12)
	var transform_before = camera.global_transform
	building.hp = 0.0
	await _frames(6)
	paused = true
	await _shot(faction + "-critical")
	var ruin = get_nodes_in_group("structure_ruins")[0]
	_check(ruin.age < .3 and ruin._model.scale.y > .9, "Critical failure stage was skipped")
	paused = false
	await _frames(39)
	paused = true
	await _shot(faction + "-falling")
	_check(ruin._model.scale.y < .9 and ruin._model.scale.y > .18, "Mid-collapse pose missing")
	paused = false
	await _frames(65)
	paused = true
	await _shot(faction + "-ruin")
	_check(is_equal_approx(ruin._model.scale.y, .18), "Persistent ruin pose missing")
	_check(
		camera.global_transform.is_equal_approx(transform_before),
		"Skirmish collapse displaced camera"
	)
	_check(
		not game.combat_effects._wrecks.any(func(entry): return not entry.motion.mobile),
		"Collapsed building also spawned a disappearing duplicate wreck"
	)
	if faction == "bastion":
		await _cannon_preview(camera)


func _cannon_preview(camera):
	paused = false
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var tank = _unit("Tank", human, Vector3(23, 0, 25))
	var target = _unit("Tank", enemy, Vector3(23, 0, 18))
	tank.aim_target = target
	await _frames(6)
	var before = camera.global_transform
	var round = game.projectile_system.launch(tank, target)
	_check(round != null, "Cannon preview did not fire a real projectile")
	await _frames(3)
	paused = true
	_check(
		game.combat_effects._shockwaves.any(
			func(entry): return entry.node.name == "CannonMuzzleShockwave"
		),
		"Cannon muzzle refraction ring missing"
	)
	await _shot("bastion-cannon")
	_check(camera.global_transform == before, "Cannon displaced the Skirmish camera")
	root.get_node("Globals").options.reduced_flashes = true
	game.combat_effects._advance_hit_flashes(.01)
	_check(game.combat_effects._shockwaves.is_empty(), "Reduced flashes retained refraction")
	root.get_node("Globals").options.reduced_flashes = false


func _shot(label):
	root.mode = Window.MODE_WINDOWED
	await _frames(3)
	root.size = Vector2i(1280, 720)
	await _frames(12)
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
	var picture = root.get_texture().get_image()
	_check(picture.get_size() == Vector2i(1280, 720), "Capture is not720p")
	_check(picture.save_png(_output + label + ".png") == OK, "Could not save " + label)
	print("Captured ", label)
