extends "res://tests/headless/InfantryMotionRegression.gd"

const OUTPUT = "res://art/infantry/redesign/"
var camera
var soldiers = []


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("InfantryRedesignPreview requires a graphical renderer")
		quit(1)
		return
	Factions = load("res://source/match/FactionCatalog.gd")
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"day_cycle": false,
			"time_of_day": 0,
			"weather": 1,
			"graphics_dof": false,
			"graphics_msaa": 2,
			"graphics_shadows": true,
			"graphics_ao": true
		}
	)
	for faction in Factions.IDS:
		await _fixture(faction)
		game.fog_of_war.reveal()
		game.find_child("Minimap", true, false).set_physics_process(false)
		game.process_mode = Node.PROCESS_MODE_DISABLED
		var ground = game.map.get_node("Geometry/Terrain")
		for mesh in game.map.find_children("*", "GeometryInstance3D", true, false):
			if mesh != ground:
				mesh.hide()
		for unit in get_nodes_in_group("units"):
			unit.hide()
		for layer in game.find_children("*", "CanvasLayer", true, false):
			layer.hide()
			layer.process_mode = Node.PROCESS_MODE_DISABLED
		camera = Camera3D.new()
		game.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.make_current()
		soldiers.clear()
		for index in range(Roster.INFANTRY_ROLES.size()):
			var unit = _soldier(
				Roster.INFANTRY_ROLES[index], human, Vector3(40 + index * 1.1, 0, 10)
			)
			unit.position = Vector3(40 + index * 1.1, 0, 10)
			unit.rotation.y = PI + .2
			soldiers.append(unit)
		camera.size = 6.5
		camera.position = Vector3(42.2, 2.6, 16)
		camera.look_at(Vector3(42.2, .57, 10))
		await _pose(0, 0)
		await _capture(faction + "-lineup")
		await _pose(0, 1)
		await _capture(faction + "-aim")
		await _pose(1.7, 0)
		await _capture(faction + "-stride")
		for index in range(1, soldiers.size()):
			soldiers[index].hide()
		await _pose(0, 0)
		camera.size = 1.65
		camera.position = Vector3(41.6, 1.5, 13)
		camera.look_at(Vector3(40, .59, 10))
		await _capture(faction + "-detail")
		# Side-view contact sheet frames make grip/foot errors reviewable.
		if faction == "bastion":
			camera.position = Vector3(43, 1.15, 11.3)
			camera.look_at(Vector3(40, .57, 10))
			for frame in range(60):
				for unit in soldiers:
					unit.get_node("BastionVisuals")._infantry_motion.advance(
						1.0 / 60, 1.7 / 60, frame / 60.0, 0, 0, 0
					)
				if frame % 10 == 0:
					await _capture("walk-%02d" % frame)
		for unit in soldiers:
			unit.show()
		camera.size = 18
		camera.position = Vector3(49, 12, 20)
		camera.look_at(Vector3(42, 0, 10))
		await _capture(faction + "-battle-scale")
		await _close()
	options.restore(original)
	print("Infantry redesign preview complete")
	quit()


func _pose(speed_value, aiming):
	for frame in range(90):
		for unit in soldiers:
			unit.get_node("BastionVisuals")._infantry_motion.advance(
				1.0 / 60.0, speed_value / 60.0, frame / 60.0, 0, 0, aiming
			)


func _capture(label):
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	print("Captured ", label)


func _fixture(faction):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/IndustrialCrossroads.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = faction
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(45)
	_freeze_units()
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	game.repair_service.set_physics_process(false)
