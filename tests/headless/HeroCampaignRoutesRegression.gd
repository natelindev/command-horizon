extends "res://tests/headless/HeroCampaignRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://hero-routes-%d.json" % OS.get_process_id()
	for id in Campaigns.stories():
		paused = false
		await _make_operation(id)
		game.set_physics_process(false)
		for enemy in game._enemy.get_children():
			if enemy.is_in_group("units"):
				enemy.hp = 0
		await _frames(3)
		for index in Campaigns.stories()[id].objectives.size():
			var objective = Campaigns.stories()[id].objectives[index]
			if objective.kind != "escort":
				continue
			game.stage = index
			game._enter_stage()
			await _frames(4)
			await _save_restore()
			paused = false
			game.advance_escort()
			for frame in 2400:
				await process_frame
				if (
					game.escort.global_position_yless.distance_to(
						game._point(objective.destination)
					)
					< 5
				):
					break
			_check(
				(
					game.escort.global_position_yless.distance_to(
						game._point(objective.destination)
					)
					< 5
				),
				"Convoy route failed: " + id + " at " + str(game.escort.position)
			)
			game.escort.hp = 0
			game._check_outcome(0)
			_check(game.result == "Defeat", "Convoy loss not enforced: " + id)
		game.queue_free()
		await _frames(4)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".sav")
	for message in errors:
		push_error(message)
	print("Hero campaign routes: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)
