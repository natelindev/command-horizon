extends "res://tests/playtest/reference/RegionalSkirmishMatches.gd"

var worker_cargo = {}
var signature_groups = {}
var wreck_ids = {}
var home_wreck_ids = {}


func _faction_id(index):
	return "frontier" if index < 4 else ("bastion" if index < 6 else "helix")


func _opponent_id(index):
	return ("bastion" if index < 2 else "helix") if index < 4 else "frontier"


func _map_id(_index):
	return "CoastalFoundry"


func _play_case(index):
	worker_cargo.clear()
	signature_groups.clear()
	wreck_ids.clear()
	home_wreck_ids.clear()
	await super(index)


func _process(delta):
	var result = super(delta)
	if not is_instance_valid(game) or human == null or opponent == null or game.finished:
		return result
	if not metrics.has("frontier"):
		metrics.frontier = {
			"bursts": [],
			"wrecks": 0,
			"observed_home_wrecks": [0, 0],
			"salvage_collected": [0, 0],
			"salvage_delivered": [0, 0],
			"salvage_lost": [0, 0],
			"coordination_at": [null, null],
			"completed_research": [[], []],
			"salvage_orders": [0, 0]
		}
	for wreck in get_nodes_in_group("salvage_wrecks"):
		if not wreck_ids.has(wreck.get_instance_id()):
			wreck_ids[wreck.get_instance_id()] = true
			metrics.frontier.wrecks += 1
		for side in [human, opponent]:
			if side.faction != "frontier":
				continue
			var index = 0 if side == human else 1
			var hq = _unit(side, "CommandCenter")
			var key = str(index) + ":" + str(wreck.get_instance_id())
			if (
				not home_wreck_ids.has(key)
				and hq != null
				and wreck.known_to(side)
				and wreck.global_position_yless.distance_to(hq.global_position_yless) <= 30
			):
				home_wreck_ids[key] = true
				metrics.frontier.observed_home_wrecks[index] += 1
	for side in [human, opponent]:
		var index = 0 if side == human else 1
		if side.coordination_unlocked and metrics.frontier.coordination_at[index] == null:
			metrics.frontier.coordination_at[index] = game.simulation_time
		metrics.frontier.completed_research[index] = side.technology.completed.duplicate()
	for unit in get_nodes_in_group("units"):
		if unit.is_queued_for_deletion() or unit.hp <= 0:
			continue
		var side = 0 if unit.player == human else 1
		if unit.type == "Worker":
			_sample_cargo(unit, side)
		if unit.signature != null and unit.signature.kind == "maneuver":
			var key = str(side) + ":" + str(unit.signature.group_id)
			if not signature_groups.has(key):
				signature_groups[key] = true
				metrics.frontier.bursts.append(
					{
						"side": side,
						"seconds": game.simulation_time,
						"role": unit.type,
						"moving": unit.get_node("Movement")._has_destination,
						"position": [unit.position.x, unit.position.z]
					}
				)
	return result


func _sample_cargo(worker, side):
	var id = worker.get_instance_id()
	var old = worker_cargo.get(id, {"materials": 0, "salvage": 0, "wreck": false, "target": 0})
	var action = worker.action
	var target = action.get_resource_unit() if is_instance_of(action, harvest_action) else null
	var at_wreck = is_instance_valid(target) and target.is_in_group("salvage_wrecks")
	var target_id = target.get_instance_id() if at_wreck else 0
	var delta = worker.resource_a - old.materials
	if delta > 0 and (at_wreck or old.wreck):
		old.salvage += delta
		metrics.frontier.salvage_collected[side] += delta
	if delta < 0 and old.salvage > 0:
		var delivered = mini(old.salvage, -delta)
		metrics.frontier.salvage_delivered[side] += delivered
		old.salvage -= delivered
	if at_wreck and target_id != old.target:
		metrics.frontier.salvage_orders[side] += 1
	old.materials = worker.resource_a
	old.wreck = at_wreck
	old.target = target_id
	worker_cargo[id] = old


func _loss(unit):
	super(unit)
	if not metrics.has("frontier") or unit.type != "Worker":
		return
	var cargo = worker_cargo.get(unit.get_instance_id(), {})
	if not cargo.is_empty():
		metrics.frontier.salvage_lost[0 if unit.player == human else 1] += cargo.salvage
