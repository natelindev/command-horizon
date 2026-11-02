extends "res://tests/headless/PreparationRegression.gd"

const OUTPUT = "res://art/weapon-charge/"
const CENTER = Vector3(51, 0, 51)


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("ChargeEffectsPreview requires a graphical renderer; omit --headless")
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
	for faction in ["bastion", "helix"]:
		await _skirmish(faction, "res://source/match/maps/IndustrialCrossroads.tscn")
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			unit.hide()
		for layer in game.find_children("*", "CanvasLayer", true, false):
			layer.hide()
		var terrain = game.map.get_node("Geometry/Terrain")
		for mesh in game.map.find_children("*", "GeometryInstance3D", true, false):
			if mesh != terrain:
				mesh.hide()
		var unit = _spawn_weapon("AdvancedTank", game._get_human_player(), CENTER)
		unit.rotation.y = -PI * 0.5
		var rocket = _spawn_weapon("RocketInfantry", game._get_human_player(), CENTER)
		rocket.hide()
		var camera = game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.size_min = 1
		camera.set_size_safely(6)
		camera.set_position_safely(CENTER + Vector3(0, 0.4, 0))
		await _frames(15)
		unit.global_position = CENTER
		rocket.global_position = CENTER
		# Frozen fixtures still need their posed model and muzzle synchronized.
		for fixture in [unit, rocket]:
			var visuals = fixture.get_node("BastionVisuals")
			visuals._advance_pose(1.0 / 60.0)
			visuals._publish_simulation_pose()
			visuals._sync_muzzle()
		paused = true
		var display = unit.get_node("WeaponPreparationVisual")
		var baseline = await _capture_charge(faction + "-idle")
		for stage in [["early", 0.1, 0.05], ["half", 0.5, 0.26], ["full", 0.98, 0.48]]:
			unit.weapon_charge_progress = stage[1]
			display._phase = stage[2]
			display.refresh()
			var image = await _capture_charge(faction + "-" + stage[0])
			_check(_changed_pixels(baseline, image) > 80, faction + " charge is not visible")
		options.reduced_flashes = true
		display.refresh()
		await _capture_charge(faction + "-reduced")
		options.reduced_flashes = false
		unit.weapon_charge_progress = -1
		display.refresh()
		var cancelled = await _capture_charge(faction + "-cancelled")
		_check(_changed_pixels(baseline, cancelled) < 30, faction + " charge leaves a visual tail")
		unit.hide()
		rocket.show()
		var lock_display = rocket.get_node("WeaponPreparationVisual")
		for stage in [["lock-acquiring", 0.1], ["lock-ready", 0.95]]:
			rocket.weapon_charge_progress = stage[1]
			lock_display.refresh()
			await _capture_charge(faction + "-" + stage[0])
		await _clean_match()
	options.restore(original)
	print("Charge effects preview: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _capture_charge(title):
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	image.save_png(OUTPUT + title + ".png")
	return image


func _spawn_weapon(role, side, point):
	var factions = load("res://source/match/FactionCatalog.gd")
	var unit = load(factions.scene_path(side.faction, role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, true)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	return unit


func _changed_pixels(before, after):
	var count = 0
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			var a = before.get_pixel(x, y)
			var b = after.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.2:
				count += 1
	return count
