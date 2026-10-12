extends "res://tests/headless/StructureActivityRegression.gd"

const OUTPUT = "res://docs/playtests/2026-10-11/structure-activity/"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	departure_type = load("res://source/match/effects/ProductionDeparture.gd")
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"day_cycle": false, "time_of_day": 0, "weather": 1})
	for faction in factions.IDS:
		await _fixture(faction)
		game.fog_of_war.reveal()
		game.find_child("Minimap", true, false).set_physics_process(false)
		for layer in game.find_children("*", "CanvasLayer", true, false):
			layer.hide()
			layer.process_mode = Node.PROCESS_MODE_DISABLED
		var camera = Camera3D.new()
		game.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 25
		camera.position = Vector3(46, 15, -11)
		camera.look_at(Vector3(46, .5, 12))
		camera.make_current()
		var construction = _spawn("PowerPlant", Vector3(34, 0, 12), true)
		construction.construct(.45)
		var lab = _spawn("CommandLab", Vector3(40, 0, 12))
		human.technology.start("weapons_1", lab)
		human.technology._physics_process(12)
		var producers = []
		for index in range(3):
			var pair = [
				["Barracks", "Infantry"],
				["VehicleFactory", "Tank"],
				["AircraftFactory", "Helicopter"]
			][index]
			var building = _spawn(pair[0], Vector3(46 + index * 6, 0, 12))
			producers.append(building)
			var job = building.production_queue.produce(load(factions.Bastion.scene_path(pair[1])))
			job.time_left = departure_type.seconds(job) + .8
		await _frames(30)
		for unit in [construction, lab] + producers:
			unit.get_node("StructureActivity").refresh(.1)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT + faction + "-activity.png")
		if faction == "bastion":
			camera.size = 10
			camera.position = Vector3(38, 6, 2)
			camera.look_at(Vector3(37, .7, 12))
			for frame in range(60):
				construction.construct(.003)
				human.technology._physics_process(1.0 / 30.0)
				for unit in [construction, lab]:
					unit.get_node("StructureActivity").refresh(1.0 / 30.0)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUTPUT + "departure-%03d.png" % frame)
		# Three close shots show the entire launch and the exact live-unit handoff.
		for index in range(producers.size()):
			var building = producers[index]
			camera.size = 6.8
			camera.position = building.position + Vector3(3.8, 4.4, -7.5)
			camera.look_at(building.position + Vector3(0, .7, -.8))
			var before = get_nodes_in_group("units")
			for frame in range(120):
				building.production_queue._process(1.0 / 30.0 / human.production_factor())
				building.get_node("StructureActivity").refresh(1.0 / 30.0)
				for unit in get_nodes_in_group("units"):
					if unit not in before:
						unit.process_mode = Node.PROCESS_MODE_DISABLED
				await process_frame
				await RenderingServer.frame_post_draw
				if faction == "bastion":
					root.get_texture().get_image().save_png(
						OUTPUT + "departure-%03d.png" % (60 + index * 120 + frame)
					)
				if frame == 44:
					root.get_texture().get_image().save_png(
						OUTPUT + "%s-%s.png" % [faction, building.type]
					)
		game.queue_free()
		await _frames(5)
	preferences.restore(original)
	print("Structure activity preview complete")
	quit()
