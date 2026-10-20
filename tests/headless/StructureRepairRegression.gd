extends "res://tests/headless/SkirmishSupportRegression.gd"


func _run():
	support_orders = load("res://source/match/units/actions/Repairing.gd")
	var behavior = load("res://source/match/orders/UnitBehavior.gd")
	for faction in ["bastion", "helix"]:
		var errors_before = errors.size()
		await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn")
		var human = game._get_human_player()
		get_nodes_in_group("players").filter(func(p): return p != human)[0].set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		for role in ["CommandCenter", "AircraftFactory"]:
			var building = _support_unit(role, human, Vector3(64, 0, 48))
			building.construct(1.0)
			await _frames(60)
			await _range_boundary(building, human)
			for mode in ["manual", "guard"]:
				var robot = _support_unit("RepairRobot", human, Vector3(54, 0, 48))
				building.hp = building.hp_max * 0.5
				await _frames(5)
				if mode == "manual":
					robot.issue_manual_order(support_orders.new(building))
				else:
					# A robot posted beside the structure services it in place.
					_check(
						behavior.guard(robot, Vector3(60, 0, 48)),
						"Structure repair guard order rejected"
					)
				var before = building.hp
				await _frames(600)
				_check(
					building.hp > before + building.hp_max * 0.05,
					"%s %s cannot actually repair %s" % [faction, mode, role]
				)
				_check(
					not robot.get_node("Movement")._has_destination,
					"Structure repair kept travelling during service"
				)
				paused = true
				before = building.hp
				await _frames(20)
				_check(building.hp == before, "Structure repair progressed while paused")
				paused = false
				robot.queue_free()
				await _frames(5)
			building.queue_free()
			await _frames(45)
		print(
			"PASS: " if errors.size() == errors_before else "FAIL: ",
			faction,
			" actual HQ/airfield repair by direct order and posted guard; pause"
		)
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Structure repair regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _range_boundary(building, human):
	var robot = _support_unit("RepairRobot", human, Vector3(54, 0, 48))
	await _frames(10)
	building.hp = building.hp_max * 0.5
	robot.global_position = building.global_position + Vector3(building.radius + 3.05, 0, 0)
	var before = building.hp
	game.repair_service.service(1.0)
	_check(building.hp == before, "Repair reached beyond three metres from the structure footprint")
	robot.global_position = building.global_position + Vector3(building.radius + 2.95, 0, 0)
	game.repair_service.service(1.0)
	_check(building.hp > before, "Repair did not reach the structure footprint")
	robot.queue_free()
	await _frames(5)
