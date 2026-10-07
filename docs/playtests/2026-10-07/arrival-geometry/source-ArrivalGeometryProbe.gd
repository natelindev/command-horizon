extends "res://tests/playtest/ArrivalRepeatAudit.gd"


func _captured_attack(repetition):
	var unit = await _open_attack()
	if unit == null:
		return
	var action = unit.action
	var start = unit.position
	var started = game.simulation_time
	var rows = []
	paused = false
	var ended = -1.0
	for frame in 360:
		await physics_frame
		if unit.action != action:
			ended = game.simulation_time - started
			break
		if frame % 30 == 0:
			rows.append(_geometry(unit, started))
	var row = {"repetition": repetition, "ended": ended, "travel": unit.position.distance_to(start)}
	if ended < 0:
		game.hud.pause_after_load()
		var builder = Snapshot.new()
		var snapshot = builder.capture(game)
		var prefix = (
			"res://docs/playtests/2026-10-07/arrival-geometry/late-%d-%d"
			% [OS.get_process_id(), repetition]
		)
		row.unit = builder._reference(unit)
		row.archive = prefix + ".json"
		row.samples = rows
		_check(
			FileStore.new().write_file(row.archive, snapshot),
			"Failed arrival capture could not save"
		)
	_check(ended > 0 and ended < 6, "Arrival geometry deadline miss")
	print("ARRIVAL GEOMETRY ", JSON.stringify(row))
	paused = false
	game.queue_free()
	await _frames(5)


func _geometry(unit, started):
	var movement = unit.get_node("Movement")
	var path = movement.get_current_navigation_path()
	var remaining = 0.0
	var previous = unit.global_position_yless
	for index in range(movement.get_current_navigation_path_index(), path.size()):
		var point = path[index] * Vector3(1, 0, 1)
		remaining += previous.distance_to(point)
		previous = point
	var neighbors = []
	for other in game.battlefield.nearby_units(unit.position, 4):
		var agent = other.get_node_or_null("Movement")
		if other == unit or agent == null:
			continue
		neighbors.append(
			{
				"role": other.type,
				"position": str(other.position),
				"radius": other.radius,
				"friendly": other.player == unit.player,
				"travelling": agent._has_destination,
				"velocity": str(agent.velocity),
				"goal": str(agent.target_position),
				"action": str(other.action)
			}
		)
	return {
		"seconds": game.simulation_time - started,
		"position": str(unit.position),
		"target": str(movement.target_position),
		"path": str(path),
		"index": movement.get_current_navigation_path_index(),
		"remaining": remaining,
		"occupied": movement.has_occupied_endpoint(),
		"occupied_no_route": movement.has_occupied_endpoint(false),
		"neighbors": neighbors,
		"arrival_left": unit.action._arrival_elapsed,
		"progress": str(unit.action._arrival_progress),
		"shot": is_instance_valid(unit.action._shot)
	}
