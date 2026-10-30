extends "res://tests/headless/SaveRestoreEdges.gd"

const OUTPUT = "res://art/endgame-presentation/"


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"screen": 1,
			"hud_motion": true,
			"reduced_flashes": false,
			"edge_scrolling": false,
			"language": "en"
		}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _skirmish("bastion", "res://source/match/maps/battlefields/PinebreakValleyMap.tscn")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var opponents = get_nodes_in_group("players").filter(
		func(side): return side != game._get_human_player()
	)
	var opponent = opponents[0]
	var enemy_hq = _units(opponent, "CommandCenter")[0]
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(enemy_hq.position)
	camera.set_size_safely(20)
	await _frames(20)
	# Use the actual destruction signal and effect path, then capture its midpoint.
	enemy_hq.hp = 0
	var presentation = game.get_node("BattlePresentation")
	await _frames(60)
	await _capture("hq-collapse")
	presentation.end_collapse()
	_check(not game.finished, "HQ presentation ended the match before recovery grace")
	game.finished = true
	game.result = "Victory"
	game.hud.show_result("Victory")
	await _capture("results-720p")
	options.interface_scale = 1.5
	options.apply()
	await _capture("results-720p-scale150")
	options.interface_scale = 1.0
	options.apply()
	presentation.inspect_battlefield()
	await _capture("inspection-720p")
	var worker = _units(game._get_human_player(), "Worker")[0]
	presentation._inspect_unit(worker)
	await _capture("inspection-selected-720p")
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	await _capture("inspection-1080p")
	presentation.show_results()
	options.language = "zh_CN"
	options.apply()
	game.hud.show_result("Victory")
	await _capture("results-1080p-zh")
	paused = false
	game.queue_free()
	await _frames(5)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Endgame presentation rendered: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _capture(label):
	await _frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
