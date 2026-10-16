extends "res://tests/headless/StructureActivityRegression.gd"

# Captures each faction's construction sites at 15/50/85/100% from the gameplay
# camera angle, plus a closer look at a worked factory, into art/construction/.

const OUTPUT = "res://art/construction/"
const STAGES = [.15, .5, .85, 1.0]
const ROLES = ["PowerPlant", "Barracks", "VehicleFactory"]


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "day_cycle": false, "time_of_day": 0, "weather": 1})
	for faction in factions.IDS:
		await _fixture(faction)
		game.fog_of_war.reveal()
		game.find_child("Minimap", true, false).set_physics_process(false)
		for layer in game.find_children("*", "CanvasLayer", true, false):
			layer.hide()
			layer.process_mode = Node.PROCESS_MODE_DISABLED
		var camera = game.get_node("IsometricCamera3D")
		var sites = []
		for row in ROLES.size():
			for column in STAGES.size():
				var site = _spawn(ROLES[row], Vector3(24 + column * 6.5, 0, 8 + row * 7.0), true)
				site.global_rotation.y = PI
				site.process_mode = Node.PROCESS_MODE_INHERIT
				sites.append([site, STAGES[column]])
		await _frames(2)
		for entry in sites:
			entry[0].construct(maxf(0.0, entry[1] - .03))
		# Builders are "working": progress creeps up so machinery and sparks run.
		for frame in range(45):
			for entry in sites:
				if is_instance_valid(entry[0]) and entry[0].is_under_construction():
					entry[0].construct(.03 / 45.0)
			await process_frame
		for entry in sites:
			if is_instance_valid(entry[0]) and entry[0].is_under_construction():
				entry[0].construct(entry[1] - entry[0]._construction_progress)
		await _shot(camera, Vector3(34, 0, 15), 26, faction + "-overview.png")
		await _shot(camera, Vector3(34, 0, 18), 15, faction + "-gameplay.png")
		await _shot(camera, Vector3(30.5, 0, 22), 7, faction + "-factory-50.png")
		await _shot(camera, Vector3(24, 0, 8), 6, faction + "-power-15.png")
		await _budget(camera, faction)
		game.queue_free()
		await _frames(5)
	preferences.restore(original)
	print("Construction preview complete")
	quit()


func _shot(camera, focus, size, file):
	camera.set_size_safely(size)
	camera.set_position_safely(focus)
	for frame in range(40):
		for site in get_nodes_in_group("units"):
			if site.has_node("ConstructionVisual") and site._construction_progress < 1.0:
				site.construct(.00001)
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUTPUT + file)


func _budget(camera, faction):
	# Script time per worked site and the draw calls the sites add over finished buildings.
	camera.set_size_safely(26)
	camera.set_position_safely(Vector3(34, 0, 15))
	var visuals = []
	for site in get_nodes_in_group("units"):
		if site.has_node("ConstructionVisual"):
			visuals.append(site.get_node("ConstructionVisual"))
	var start = Time.get_ticks_usec()
	for frame in 100:
		for visual in visuals:
			visual._unit.construct(.00001)
			visual._process(1.0 / 60.0)
	var micros = float(Time.get_ticks_usec() - start) / 100.0 / visuals.size()
	await _frames(3)
	RenderingServer.force_draw(false)
	var building = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	for visual in visuals:
		visual._unit.construct(1.0)
	await _frames(3)
	RenderingServer.force_draw(false)
	var finished = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print(
		(
			"%s: %d sites, %.1f us script per site-frame, %+.1f draw calls per site"
			% [faction, visuals.size(), micros, (building - finished) / visuals.size()]
		)
	)
