extends "res://tests/headless/PolicyRecoveryRegression.gd"


func _recovery_fixture(faction):
	var case_index = 2 if faction == "bastion" else 6
	var entity_id = "unit-7" if faction == "bastion" else "unit-4"
	var store = _new_store()
	var data = store.read_file(
		"res://docs/playtests/2026-10-04/regional-case-%d-stall.json" % case_index
	)
	var restore = _new_restore()
	var result = await restore.restore(self, data)
	_check(result.ok, "Fallback archive did not restore")
	if not result.ok:
		return
	game = result.game
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var unit = restore.entities[entity_id]
	for other in get_nodes_in_group("units"):
		if other != unit:
			other.process_mode = Node.PROCESS_MODE_DISABLED
	var hq = _unit(human, "CommandCenter")
	_check(unit.program.mode == "Blocked", "Original archive lost the blocked retreat")
	_check(
		unit.program.safe_point == hq.global_position_yless,
		"Original failure was not the HQ-center fallback"
	)
	var destination = _recovery_point(unit, hq)
	_check(
		destination.distance_to(hq.global_position_yless) > hq.radius + unit.radius,
		"No-service fallback remains inside the HQ footprint"
	)
	var hp = unit.hp
	var funds = Vector2(human.resource_a, human.resource_b)
	unit.program.safe_point = destination
	_check(unit.program.run(), "Corrected retreat did not resume")
	paused = false
	await _frames(1200)
	_check(unit.program.mode == "Running", "Corrected retreat blocked again")
	_check(unit.position.distance_to(destination) < 1.0, "Corrected fallback was not reached")
	_check(not unit.get_node("Movement")._has_destination, "Reached fallback kept travelling")
	_check(is_equal_approx(unit.hp, hp), "Fallback without a provider invented healing")
	_check(Vector2(human.resource_a, human.resource_b) == funds, "Fallback changed paid resources")
	_check(_recovery_point(unit, hq) == destination, "Fallback drifts while its unit approaches")
	var arrived = unit.position
	var obstruction = _recovery_actor("PowerPlant", destination)
	await _frames(30)
	var replacement = _recovery_point(unit, hq)
	_check(
		(
			replacement.distance_to(obstruction.global_position_yless)
			> obstruction.radius + unit.radius
		),
		"A new owned structure did not invalidate the waiting point"
	)
	var depot = _recovery_actor("RepairDepot", hq.global_position_yless + Vector3(-7, 0, 7))
	await _frames(30)
	_check(
		_recovery_point(unit, hq) == depot.global_position_yless,
		"An available matching facility did not replace the waiting point"
	)
	print(
		"FALLBACK ",
		faction,
		" destination=",
		destination,
		" position=",
		arrived,
		" mode=",
		unit.program.mode,
		" hp=",
		unit.hp
	)
	paused = false
	game.queue_free()
	await _frames(5)
	if faction == "bastion":
		await _occupied_fallback()


func _occupied_fallback():
	var store = _new_store()
	var restore = _new_restore()
	var result = await restore.restore(
		self, store.read_file("res://docs/playtests/2026-10-04/regional-final-case-0-stall.json")
	)
	_check(result.ok, "Occupied fallback archive failed")
	if not result.ok:
		return
	game = result.game
	human = game._get_human_player()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var unit = restore.entities["unit-12"]
	for other in get_nodes_in_group("units"):
		if other != unit:
			other.process_mode = Node.PROCESS_MODE_DISABLED
	var hq = _unit(human, "CommandCenter")
	var before = unit.program.safe_point
	unit.set_meta(
		"policy_recovery_fallback", {"headquarters": hq.get_instance_id(), "point": before}
	)
	unit.set_meta("policy_programmed", true)
	phase = "defend"
	metrics = {"first_assault": null, "first_program": 0}
	defense_point = unit.program.anchor
	var held_point = unit.position
	var held_clock = game.simulation_time
	_command()
	_check(
		unit.program.safe_point.distance_to(before) > .2,
		"Commander retained the newly occupied fallback"
	)
	_check(
		unit.program.mode in ["Ready", "Running"], "Commander did not resume the reassigned retreat"
	)
	await _frames(90)
	_check(
		unit.position == held_point and game.simulation_time == held_clock,
		"Paused reassignment advanced the battle"
	)
	paused = false
	await _frames(900)
	_check(unit.program.mode == "Running", "Reassigned fallback blocked again")
	_check(
		unit.position.distance_to(unit.program.safe_point) < 1,
		"Reassigned fallback was not reached"
	)
	print(
		"OCCUPIED FALLBACK before=",
		before,
		" after=",
		unit.program.safe_point,
		" point=",
		unit.position,
		" mode=",
		unit.program.mode
	)
	game.queue_free()
	await _frames(5)


func _new_store():
	return load("res://source/match/saves/SaveFile.gd").new()


func _new_restore():
	return load("res://source/match/saves/MatchRestore.gd").new()
