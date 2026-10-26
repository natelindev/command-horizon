extends "res://tests/headless/SaveRestoreEdges.gd"


# Ground bodies must follow the visible slope, not the voxelized navigation height.
func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion", "res://source/match/maps/battlefields/AlpineRelayMap.tscn", false)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var human = game._get_human_player()
	var moving = load("res://source/match/units/actions/Moving.gd")
	for type in ["Infantry", "Tank"]:
		var unit = load("res://source/match/units/%s.tscn" % type).instantiate()
		game._setup_and_spawn_unit(unit, Transform3D(Basis(), Vector3(52, 0, 46)), human)
		await _frames(30)
		for target in [Vector3(32, 3, 46), Vector3(52, 0, 46)]:
			unit.issue_manual_order(moving.new(target))
			var max_burial = 0.0
			var max_hover = 0.0
			var reached = false
			for frame in 3600:
				await physics_frame
				var point = unit.global_position
				var ground = game.map.height_at(Vector2(point.x, point.z))
				max_burial = maxf(max_burial, ground - point.y)
				max_hover = maxf(max_hover, point.y - ground)
				if Vector2(point.x, point.z).distance_to(Vector2(target.x, target.z)) < .35:
					reached = true
					break
			print("%s to %s: burial %.3f m, hover %.3f m" % [type, target, max_burial, max_hover])
			_check(reached, "%s did not finish the alpine ramp" % type)
			_check(
				max_burial < .08, "%s sinks below the alpine ramp by %.3f m" % [type, max_burial]
			)
			_check(max_hover < .08, "%s floats above the alpine ramp by %.3f m" % [type, max_hover])
		unit.manual_orders.cancel()
		unit.queue_free()
		await _frames(5)
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Terrain grounding: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
