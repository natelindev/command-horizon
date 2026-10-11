extends "res://tests/headless/NeutralWorldRegression.gd"

const OUTPUT = "res://docs/playtests/2026-10-11/neutral-world/"


func _initialize():
	Engine.max_fps = 60
	super()


func _run():
	CombatRules = load("res://source/match/combat/CombatRules.gd")
	Manual = load("res://source/match/orders/ManualOrders.gd")
	path = "user://neutral-preview-%d.json" % OS.get_process_id()
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore(
		{"screen": 1, "day_cycle": false, "time_of_day": 0, "weather": 1, "living_world": true}
	)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	await _create("IndustrialCrossroads")
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	game.hud.hide()
	var building = game.get_node("NeutralWorld").buildings[2]
	var point = building.global_position
	await _capture_frame("01-neighborhood", Vector3(64, 0, 52), 56)
	await _capture_frame("02-building-detail", point, 19)
	var life = game.map.get_node("AmbientLife")
	life.set_physics_process(false)
	var actors = []
	for kind in ["car", "resident", "fox"]:
		var actor = life.actors.filter(func(a): return a.entry.kind == kind)[0]
		actor.position = Vector3(59 + actors.size() * 3.0, 0, 51)
		actor.rotation.y = .7
		actor.refresh_visibility(game)
		actors.append(actor)
	await _capture_frame("03-street-life", Vector3(62, 0, 51), 12)
	var player = game._get_human_player()
	for index in 4:
		var soldier = _spawn_infantry(player, point + Vector3(building.radius + 1, 0, index * .4))
		soldier.manual_orders.submit(Manual.target_order("garrison", building))
	await _frames(100)
	var enemy = get_nodes_in_group("players").filter(func(side): return side != player)[0]
	var target = _units(enemy, "Tank")[0]
	target.position = point + Vector3(11, 0, 0)
	game.battlefield.invalidate()
	await _capture_frame("04-garrison", point + Vector3(4, 0, 0), 25)
	for actor in actors:
		for hit in 120:
			if actor.hp <= 0:
				break
			actor.receive_weapon_hit(target)
		actor.advance_damage(.9)
	await _capture_frame("05-neutral-deaths", Vector3(62, 0, 51), 12)
	for hit in 120:
		if building.hp <= 0:
			break
		building.receive_weapon_hit(target)
	await _frames(65)
	await _capture_frame("06-building-collapse", point, 23)
	if "--inspect" in OS.get_cmdline_user_args():
		await create_timer(45).timeout
	await _close()
	preferences.restore(original)
	print("Neutral world preview complete")
	quit()


func _capture_frame(label, point, size):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(size)
	camera.set_position_safely(point)
	await _frames(15)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
