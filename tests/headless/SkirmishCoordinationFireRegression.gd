extends "res://tests/headless/SkirmishCoordinationRegression.gd"


func _run():
	catalog = load("res://source/match/BastionCatalog.gd")
	coordination = load("res://source/match/players/skirmish-ai/SkirmishCoordination.gd")
	var saves = root.get_node("SaveManager")
	var autosaves = saves.autosaves_enabled
	saves.autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _fixture(faction, 2)
		var worker = _actor("Worker", opponent, Vector3(90, 0, 30))
		var counter = _actor("AdvancedTank", opponent, Vector3(76, 0, 24))
		var local_target = _actor("CommandCenter", human, Vector3(80, 0, 24))
		var threat = _actor("Tank", human, Vector3(88, 0, 30))
		counter.issue_manual_order(
			load("res://source/match/units/actions/AttackMoving.gd").new(Vector3(15, 0, 30))
		)
		counter.process_mode = Node.PROCESS_MODE_INHERIT
		for frame in 300:
			await physics_frame
		_check(local_target.hp < local_target.hp_max, "Prepared weapon fixture never fired")
		for dispatch in ["defense", "ordinary"]:
			var hp = local_target.hp
			for frame in 360:
				if frame % 45 == 0:
					threat.position.x = 88 if frame % 90 == 0 else 92
					game.battlefield.invalidate()
					var shot = counter.action._shot
					if dispatch == "defense":
						opponent._command_army([actors[0], worker, counter])
					else:
						coordination._order(opponent, counter, threat.position)
					_check(
						counter.action.destination.distance_to(threat.position) < 1,
						"Engaged dispatch did not update its strategic goal"
					)
					_check(
						counter.action._shot == shot,
						"Strategic dispatch replaced the active firing action"
					)
				await physics_frame
			print("COORDINATION CHARGE ", faction, " ", dispatch, " damage=", hp - local_target.hp)
			_check(
				local_target.hp < hp,
				"Strategic goal updates repeatedly cancelled weapon preparation"
			)
		game.queue_free()
		await _frames(5)
	saves.autosaves_enabled = autosaves
	for error in errors:
		push_error(error)
	print("Coordination prepared fire: ", errors.size(), " failures")
	quit(0 if errors.is_empty() else 1)
