extends "res://tests/headless/PersistentCaptureRegression.gd"


func _run():
	Manual = load("res://source/match/orders/ManualOrders.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "edge_scrolling": false, "language": "en"})
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	path = "user://ownership-preview-%d.json" % OS.get_process_id()
	await _create("ExpandedDesertFrontier")
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var building = game.get_node("NeutralWorld").buildings.filter(func(item): return item.habitable)[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(building.global_position)
	camera.set_size_safely(24)
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	enemy.color = root.get_node("Constants").Player.COLORS[1]
	var soldier = await _enter_building(building, human)
	await _shot("occupied")
	await _leave_building(building, soldier)
	_check(building.player == human, "Leaving erased visible ownership")
	await _shot("vacant-owned")
	var invader = await _enter_building(building, enemy)
	await _leave_building(building, invader)
	_check(building.player == enemy, "Enemy recapture failed")
	await _shot("vacant-recaptured")
	await _close()
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Rendered neutral ownership: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _shot(label):
	await _frames(5)
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute("res://art/neutral-ownership")
	root.get_texture().get_image().save_png("res://art/neutral-ownership/" + label + ".png")
