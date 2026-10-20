extends RefCounted

const Infantry = preload("res://source/match/units/Infantry.tscn")

var queued = false
var initial = {}
var dispatched = {}
var spent = Vector2.ZERO
var replacements = 0
var retake = -1
var retake_changed = false


func step(game):
	var human = game._get_human_player()
	var units = human.get_children().filter(
		func(unit): return unit.is_in_group("units") and unit.hp > 0
	)
	if not queued:
		for unit in units:
			initial[unit.get_instance_id()] = true
		var before = Vector2(human.resource_a, human.resource_b)
		for building in units:
			if building.type == "Barracks":
				for index in 4:
					building.get_node("ProductionQueue").produce(Infantry)
			if building.type == "VehicleFactory":
				for role in ["Tank", "Tank", "RepairRobot"]:
					building.get_node("ProductionQueue").produce(
						load("res://source/match/units/%s.tscn" % role)
					)
		spent = before - Vector2(human.resource_a, human.resource_b)
		queued = true
		print("SPLIT REINFORCEMENTS paid=", spent)
	var infantry_alive = units.any(func(unit): return unit.type == "Infantry")
	if not infantry_alive and replacements < 2:
		for building in units:
			if building.type != "Barracks":
				continue
			var queue = building.get_node("ProductionQueue")
			if queue.size() == 0:
				var before = Vector2(human.resource_a, human.resource_b)
				if queue.produce(Infantry) != null:
					spent += before - Vector2(human.resource_a, human.resource_b)
					replacements += 1
					print("SPLIT REPLACEMENT infantry at=", game.simulation_time)
	var lost = [0, 2].filter(func(index): return game.map.relays[index].captured_by != human)
	var destination = lost[0] if not lost.is_empty() else -1
	retake_changed = destination != retake and destination >= 0
	retake = destination
	if retake_changed:
		for unit in units:
			if unit.type in ["Tank", "Infantry", "RepairRobot"]:
				_dispatch(game, unit, retake)
		print("SPLIT RETAKE ", game.map.NAMES[retake], " at=", game.simulation_time)
	for unit in units:
		var id = unit.get_instance_id()
		if initial.has(id) or dispatched.has(id):
			continue
		dispatched[id] = true
		_dispatch(game, unit, retake if retake >= 0 else 0)
		print("SPLIT REINFORCEMENT dispatched=", unit.type, " at=", game.simulation_time)


func _dispatch(game, unit, index):
	var point = game.map.relays[index].position
	if unit.type == "RepairRobot":
		# Hold beside the relay; a stationary robot services nearby allies.
		load("res://source/match/orders/UnitBehavior.gd").guard(unit, point - Vector3(2, 0, 0))
	else:
		unit.issue_manual_order(
			load("res://source/match/units/actions/AttackMoving.gd").new(point - Vector3(1.5, 0, 0))
		)
