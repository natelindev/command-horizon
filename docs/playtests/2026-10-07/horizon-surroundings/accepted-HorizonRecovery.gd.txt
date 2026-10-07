extends RefCounted

var issued = {}
var replacements = 0


func step(game, service):
	var human = game._get_human_player()
	for unit in human.get_children():
		if not unit.is_in_group("units") or not game._alive(unit) or unit.movement_speed <= 0:
			continue
		if unit.type in ["Worker", "Drone"] or issued.has(unit.get_instance_id()):
			continue
		issued[unit.get_instance_id()] = true
		if unit.type == "RepairRobot":
			unit.program.anchor = game.map.DEPLOYMENT + Vector3(-7, 0, 0)
			unit.program.safe_point = game.map.DEPLOYMENT + Vector3(-12, 0, 0)
			unit.program.apply_prepared(service, null)
		else:
			unit.issue_manual_order(
				load("res://source/match/units/actions/AttackMoving.gd").new(game.map.DEPLOYMENT)
			)
	var barracks = human.get_children().filter(
		func(unit):
			return unit.is_in_group("units") and game._alive(unit) and unit.type == "Barracks"
	)
	var infantry = human.get_children().filter(
		func(unit):
			return unit.is_in_group("units") and game._alive(unit) and unit.type == "Infantry"
	)
	if not barracks.is_empty() and infantry.size() < 4 and replacements < 6:
		var queue = barracks[0].get_node("ProductionQueue")
		if (
			queue.size() < 2
			and queue.produce(load("res://source/match/units/Infantry.tscn")) != null
		):
			replacements += 1
