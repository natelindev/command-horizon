extends "res://source/match/Skirmish.gd"

const Progress = preload("res://source/match/campaign/CampaignProgress.gd")
const Moving = preload("res://source/match/units/actions/Moving.gd")
const AttackMove = preload("res://source/match/units/actions/AttackMoving.gd")
const CLEARANCE_SECONDS = 12.0
var convoy = []
var responses = [-1.0, -1.0, -1.0]
var resolved = [false, false, false]
var progress_path = Progress.PATH
var progress_error = ""
var _enemy


func _ready():
	super()
	var opponents = get_tree().get_nodes_in_group("players").filter(
		func(p): return p != _get_human_player()
	)
	_enemy = opponents[0]
	_enemy.set_process(false)
	_checkpoint("Operation start")
	hud.show_notice(
		"Supply Line: scout the route, then advance your convoy. Use tactical pause to plan orders."
	)


func _create_hud():
	return load("res://source/match/campaign/SupplyLineHUD.gd").new()


func _spawn_player_units(side, _spawn_transform):
	if side.faction == "helix":
		for stage in 3:
			var count = [3, 4, 5][side.difficulty]
			for index in count:
				_spawn("Infantry", side, map.POINTS[stage] + Vector3((index - 2) * 2, 0, -2))
			if stage > 0:
				_spawn("Tank", side, map.POINTS[stage] + Vector3(3, 0, 3))
		return
	side.resource_a = 0
	side.resource_b = 0
	for index in 3:
		var truck = _spawn("SupplyTruck", side, Vector3(18, 0, 95 + index * 4))
		convoy.append({"unit": truck, "leg": 0, "clearance": 0.0, "delivered": false})
	for index in 4:
		_spawn("Tank", side, Vector3(25 + index * 2.5, 0, 96))
	for index in 12:
		_spawn("Infantry", side, Vector3(26 + index % 4 * 1.6, 0, 103 + index / 4 * 1.6))
	for z in [96, 103]:
		_spawn("RepairRobot", side, Vector3(21, 0, z))


func _spawn(role, side, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	_setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, false)
	return unit


func trucks():
	return convoy.filter(func(entry): return _alive(entry)).map(func(entry): return entry.unit)


func escorts():
	return _get_human_player().get_children().filter(
		func(unit):
			return (
				unit.is_in_group("units")
				and unit.type != "SupplyTruck"
				and not unit.is_queued_for_deletion()
			)
	)


func advance_convoy():
	if finished:
		return
	for index in convoy.size():
		var entry = convoy[index]
		if _alive(entry):
			entry.unit.issue_manual_order(
				Moving.new(map.POINTS[entry.leg] + Vector3(0, 0, (index - 1) * 3))
			)


func hold_convoy():
	for truck in trucks():
		truck.issue_manual_order(null)
		truck.get_node("Movement").stop()


func _alive(entry):
	return (
		not entry.delivered
		and is_instance_valid(entry.unit)
		and not entry.unit.is_queued_for_deletion()
		and entry.unit.hp > 0
	)


func _check_outcome(delta):
	if _enemy == null or convoy.size() != 3:
		return
	var delivered = convoy.filter(func(entry): return entry.delivered).size()
	if delivered + trucks().size() < 2:
		_finish("Defeat")
		return
	for index in convoy.size():
		var entry = convoy[index]
		if not _alive(entry):
			continue
		var point = map.POINTS[entry.leg]
		if entry.unit.global_position_yless.distance_to(point) > 7:
			entry.clearance = 0.0
			continue
		if responses[entry.leg] < 0 and not resolved[entry.leg]:
			responses[entry.leg] = 10.0
			hud.show_notice(
				(
					"%s: Helix response in 10 seconds. Hold and repair if needed."
					% map.NAMES[entry.leg]
				)
			)
		if checkpoint_contested(entry.leg) or entry.unit.get_node("Movement")._has_destination:
			continue
		entry.clearance = minf(CLEARANCE_SECONDS, entry.clearance + delta)
		if entry.clearance >= CLEARANCE_SECONDS:
			entry.clearance = 0.0
			entry.leg += 1
			if entry.leg == 3:
				entry.delivered = true
				entry.unit.queue_free()
			else:
				hud.show_notice(
					(
						"Truck %d cleared %s. Repair, then order the next leg."
						% [index + 1, map.NAMES[entry.leg - 1]]
					)
				)
			_checkpoint("Convoy checkpoint")
	for index in responses.size():
		if responses[index] >= 0 and not resolved[index]:
			responses[index] = maxf(0, responses[index] - delta)
			if responses[index] == 0:
				_send_response(index)
	if convoy.filter(func(entry): return entry.delivered).size() >= 2:
		_finish("Victory")


func checkpoint_contested(leg):
	return battlefield.nearby_units(map.POINTS[leg], 10).any(
		func(unit):
			return (
				unit.player == _enemy
				and unit.movement_domain == 1
				and not unit.is_queued_for_deletion()
			)
	)


func _send_response(index):
	if resolved[index]:
		return
	resolved[index] = true
	responses[index] = 0.0
	var entry = map.ENTRIES[index]
	if _get_human_player().get_children().any(
		func(unit):
			return (
				unit.is_in_group("units")
				and not unit.is_queued_for_deletion()
				and unit.global_position_yless.distance_to(entry) <= 12
			)
	):
		hud.show_notice("%s: reinforcement approach secured; response denied." % map.NAMES[index])
		return
	for member in [2, 3, 4][_enemy.difficulty]:
		var unit = _spawn("Infantry", _enemy, entry + Vector3(member * 1.5, 0, 0))
		unit.issue_manual_order(AttackMove.new(map.POINTS[index]))
	hud.show_notice("%s: Helix response has entered." % map.NAMES[index])


func _finish(value):
	if finished:
		return
	finished = true
	result = value
	if value == "Victory":
		var progress = Progress.new()
		if not progress.record_supply_victory(progress_path):
			progress_error = progress.error
	hud.show_result("Supply Line · " + value)


func objective_text():
	return "Escort at least two supply trucks through all three checkpoints."


func result_summary():
	var delivered = convoy.filter(func(entry): return entry.delivered).size()
	var text = "%d / 3 trucks extracted. " % delivered
	text += (
		"First Orders starts with +20 materials."
		if result == "Victory"
		else "Two truck losses make the delivery impossible."
	)
	return text + ("\n" + progress_error if not progress_error.is_empty() else "")


func _checkpoint(reason):
	get_node("/root/SaveManager").request_checkpoint(self, reason)
