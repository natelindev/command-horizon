extends "res://tests/playtest/SupplyDifficultyMatches.gd"

var control_activations = []


func _play():
	for stage in 3:
		var response = load("res://tests/playtest/reference/SupplyResponse.gd").new()
		var destination = game.map.POINTS[stage]
		for unit in game.escorts():
			if unit.attack_range != null:
				unit.issue_manual_order(
					attack_move.new(destination + Vector3(unit.get_index() % 3, 0, 0))
				)
			else:
				unit.issue_manual_order(moving.new(destination + Vector3(-5, 0, 3)))
		var start = game.simulation_time
		while game.simulation_time - start < 150 and not game.finished:
			if (
				game
				. battlefield
				. nearby_units(destination, 12)
				. filter(func(unit): return unit.player == game._enemy)
				. is_empty()
			):
				break
			await _frames(30)
		await _activate_convoy(true)
		start = game.simulation_time
		var held = false
		while game.simulation_time - start < 160 and not game.finished:
			if "--respond-to-contest" in OS.get_cmdline_user_args():
				response.step(game)
			var arrivals = game.convoy.filter(
				func(entry):
					return (
						game._alive(entry)
						and entry.leg == stage
						and entry.unit.position.distance_to(destination) <= 4.5
					)
			)
			if not held and arrivals.size() >= 2:
				held = true
				await _activate_convoy(false)
			if _stage_done(stage):
				break
			await _frames(30)
		_check(held, "Group convoy could not reach checkpoint %d" % (stage + 1))
		_check(_stage_done(stage), "Group Hold failed clearance at checkpoint %d" % (stage + 1))
		print(
			"CONVOY GROUP stage=",
			stage,
			" time=",
			game.simulation_time,
			" held=",
			held,
			" cleared=",
			_stage_done(stage)
		)
		await _review_stage(stage)
		if game.finished or not _stage_done(stage):
			break
	_check(
		game.finished and game.result == "Victory", "Group convoy controls did not reach victory"
	)
	print(
		"CONVOY GROUP result=",
		game.result,
		" time=",
		game.simulation_time,
		" activations=",
		control_activations
	)


func _activate_convoy(advance):
	control_activations.append("advance" if advance else "hold")
	if advance:
		game.advance_convoy()
	else:
		game.hold_convoy()


func _review_stage(_stage):
	pass
