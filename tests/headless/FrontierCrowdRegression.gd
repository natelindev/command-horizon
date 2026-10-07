extends "res://tests/headless/FrontierRegression.gd"


func _run():
	moving = load("res://source/match/units/actions/Moving.gd")
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	# Repeated fresh armies exercise different avoidance ordering around the outer field.
	for attempt in 4:
		var faction = "bastion" if attempt % 2 == 0 else "helix"
		print("Desert crowd traversal ", attempt + 1, " / 4: ", faction)
		await _skirmish(faction, FRONTIER)
		_enemy().set_process(false)
		await _frames(100)
		_check(
			await _frontier_routes(game._get_human_player()) == true,
			"Repeated desert route/archive suite aborted"
		)
		paused = false
		game.queue_free()
		await _frames(5)
	manager.autosaves_enabled = autosaves
	print("Desert crowd traversal: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
