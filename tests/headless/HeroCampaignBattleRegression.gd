extends "res://tests/headless/HeroCampaignRegression.gd"

var attack_order
var move_order


func _initialize():
	_run.call_deferred()


func _run():
	attack_order = load("res://source/match/units/actions/AttackMoving.gd")
	move_order = load("res://source/match/units/actions/Moving.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://hero-battle-%d.json" % OS.get_process_id()
	var only = OS.get_cmdline_user_args()
	for id in Campaigns.stories():
		if not only.is_empty() and id not in only:
			continue
		paused = false
		await _make_operation(id)
		game.set_physics_process(true)
		var human = game._get_human_player()
		var gather = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
		var deposits = get_nodes_in_group("resource_units").filter(
			func(u): return u.position.x < 25
		)
		var workers = _units(human, "Worker")
		for index in workers.size():
			workers[index].issue_manual_order(gather.new(deposits[index % deposits.size()]))
		var tanks = _units(human, "Tank")
		var behavior = load("res://source/match/orders/UnitBehavior.gd")
		for index in _units(human, "RepairRobot").size():
			var repair = _units(human, "RepairRobot")[index]
			_check(behavior.follow(repair, tanks[index]), "Repair robot rejected escort follow")
		var issued_stage = -1
		var elapsed = 0.0
		print("CAMPAIGN BATTLE BEGIN ", id)
		while not game.finished and elapsed < 600:
			var objective = game.current_objective()
			var point = game._point(objective.point)
			var new_stage = game.stage != issued_stage
			if new_stage:
				issued_stage = game.stage
				print("CAMPAIGN BATTLE ", id, " stage=", issued_stage, " time=", elapsed)
			var destination = (
				game._point(objective.destination) if objective.kind == "escort" else point
			)
			_command_army(human, destination, new_stage)
			_reinforce(human)
			if game.campaign_hero.alive():
				var hero = game.campaign_hero.unit
				var hero_destination = point + Vector3(-12, 0, 0)
				if objective.kind == "escort":
					game.advance_escort()
					hero_destination = game.escort.global_position_yless + Vector3(-6, 0, 0)
				if hero.global_position_yless.distance_to(hero_destination) > 4:
					hero.issue_manual_order(move_order.new(hero_destination))
				game.campaign_hero.activate()
			await _frames(120)
			elapsed += 2
			if int(elapsed) % 60 == 0:
				print(
					"CAMPAIGN STATUS ",
					id,
					" time=",
					elapsed,
					" stage=",
					game.stage,
					" infantry=",
					_units(human, "Infantry").size(),
					" tanks=",
					_units(human, "Tank").size()
				)
		_check(
			game.finished and game.result == "Victory",
			"Live campaign failed: " + id + " stage=" + str(game.stage) + " result=" + game.result
		)
		print("CAMPAIGN BATTLE END ", id, " stage=", game.stage, " result=", game.result)
		paused = false
		game.queue_free()
		await _frames(5)
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Hero campaign battles: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _idle(unit):
	return unit.action == null or (unit.action.has_method("is_idle") and unit.action.is_idle())


func _command_army(human, point, force):
	var infantry = _units(human, "Infantry")
	for index in infantry.size():
		var unit = infantry[index]
		if force or _idle(unit):
			var offset = (
				Vector3.RIGHT.rotated(Vector3.UP, index * TAU / maxi(1, infantry.size())) * 2
			)
			unit.issue_manual_order(attack_order.new(point + offset))
	var armor = _units(human, "Tank")
	for index in armor.size():
		var unit = armor[index]
		if force or _idle(unit):
			unit.issue_manual_order(attack_order.new(point + Vector3(-7, 0, (index % 3 - 1) * 3)))


func _reinforce(human):
	for spec in [["Barracks", "Infantry", 10], ["VehicleFactory", "Tank", 5]]:
		var buildings = _units(human, spec[0])
		if buildings.is_empty():
			continue
		var queue = buildings[0].get_node("ProductionQueue")
		if _units(human, spec[1]).size() + queue.size() < spec[2] and queue.size() < 2:
			queue.produce(load("res://source/match/units/" + spec[1] + ".tscn"))
