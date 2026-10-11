extends "res://tests/headless/InfantryHeroesRegression.gd"

const OUTPUT = "res://docs/playtests/2026-10-11/infantry-heroes/"


func _run():
	Factions = load("res://source/match/FactionCatalog.gd")
	Combat = load("res://source/match/combat/CombatRules.gd")
	Engine.max_fps = 60
	path = "user://infantry-preview-%d.json" % OS.get_process_id()
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore(
		{"screen": 1, "day_cycle": false, "time_of_day": 0, "weather": 1, "language": "zh_CN"}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for faction in Factions.IDS:
		await _fixture(faction)
		game.fog_of_war.reveal()
		var canvases = []
		for layer in game.find_children("*", "CanvasLayer", true, false):
			if layer.visible:
				canvases.append(layer)
				layer.hide()
		var point = Vector3(62, 0, 51)
		var index = 0
		for role in Roster.INFANTRY_ROLES:
			var unit = _soldier(role, human, point + Vector3(1, 0, -1) * (index - 2) * 1.7)
			unit.rotation.y = PI + .5
			unit.get_node("BastionVisuals").set_physics_process(false)
			var label = Label3D.new()
			label.text = tr(Factions.title(faction, role))
			label.font = load("res://assets/fonts/NotoSansSC.ttf")
			label.font_size = 24
			label.pixel_size = .012
			label.position.y = 2.25
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			unit.add_child(label)
			if role == "Hero":
				unit.get_node("HeroAura")._physics_process(.1)
			index += 1
		await _capture(faction + "-roster", point, 13)
		if faction == "bastion":
			_soldier("CommandLab", human, Vector3(35, 0, 10))
			for layer in canvases:
				layer.show()
			barracks.get_node("Selection").select()
			await _capture("barracks-menu", barracks.position, 26)
		await _close()
	preferences.restore(original)
	print("Infantry heroes preview complete")
	quit()


func _capture(label, point, size):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(size)
	camera.set_position_safely(point)
	await _frames(15)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
