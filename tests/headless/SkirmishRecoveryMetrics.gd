extends RefCounted

var records = []
var active = {}
var last_time = 0.0


func sample(game, player):
	var elapsed = maxf(0.0, game.simulation_time - last_time)
	last_time = game.simulation_time
	var seen = []
	for unit in game.get_tree().get_nodes_in_group("units"):
		if unit.player != player or unit.is_queued_for_deletion() or unit.hp <= 0:
			continue
		var id = unit.get_instance_id()
		seen.append(id)
		var fraction = unit.hp / unit.hp_max
		var recovering = (
			unit.action != null
			and unit.action.get_script().resource_path.ends_with("RecoveringAtService.gd")
		)
		if not recovering:
			if active.has(id):
				_finish(
					id,
					game.simulation_time,
					fraction,
					"recovered" if fraction >= 0.8 else "interrupted"
				)
			continue
		if not active.has(id):
			var record = {
				"role": unit.type,
				"start": game.simulation_time,
				"last_sample": game.simulation_time,
				"end": null,
				"entry_health": fraction,
				"peak_health": fraction,
				"end_health": null,
				"sampled_service": false,
				"sampled_blocked_seconds": 0.0,
				"outcome": "active"
			}
			records.append(record)
			active[id] = record
		var record = active[id]
		record.last_sample = game.simulation_time
		record.peak_health = maxf(record.peak_health, fraction)
		if unit.action._blocked:
			record.sampled_blocked_seconds += elapsed
		var service = unit.action._target
		if is_instance_valid(service) and not service.is_queued_for_deletion():
			var movement = unit.get_node("Movement")
			if (
				unit.global_position_yless.distance_to(service.global_position_yless) <= 5
				and not movement._has_destination
			):
				record.sampled_service = true
	for id in active.keys():
		if id not in seen:
			_finish(id, game.simulation_time, 0.0, "removed")


func loss(unit, game):
	if active.has(unit.get_instance_id()):
		_finish(unit.get_instance_id(), game.simulation_time, 0.0, "lost")


func _finish(id, now, fraction, outcome):
	var record = active[id]
	record.end = now
	record.end_health = fraction
	record.peak_health = maxf(record.peak_health, fraction)
	record.outcome = outcome
	active.erase(id)
