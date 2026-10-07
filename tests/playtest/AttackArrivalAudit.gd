extends "res://tests/headless/AttackCrowdedArrivalRegression.gd"

const OUTPUT = "res://docs/playtests/2026-10-06/attack-arrival-audit/"
var records = []


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for trial in 12:
		await _audit(trial)
	var path = OUTPUT + "audit-%d.json" % OS.get_process_id()
	if FileAccess.file_exists(path):
		push_error("Audit output already exists")
		quit(1)
		return
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	for message in errors:
		push_error(message)
	print("Attack arrival audit: %d failures; %s" % [errors.size(), path])
	quit(0 if errors.is_empty() else 1)


func _audit(trial):
	var unit = await _open_attack()
	if unit == null:
		return
	var movement = unit.get_node("Movement")
	var action = unit.action
	var start = unit.position
	var started = game.simulation_time
	var record = {"trial": trial, "arrival": -1.0, "samples": [], "archive": ""}
	paused = false
	for frame in 1200:
		await _frames(1)
		if unit.action != action:
			record.arrival = game.simulation_time - started
			break
		if frame % 30 == 0:
			record.samples.append(_state(unit, started))
		if frame == 359:
			game.hud.pause_after_load()
			var builder = Snapshot.new()
			var data = builder.capture(game)
			record.archive = OUTPUT + "late-%d-%d.json" % [OS.get_process_id(), trial]
			record.unit = builder._reference(unit)
			_check(
				(
					not FileAccess.file_exists(record.archive)
					and FileStore.new().write_file(record.archive, data)
				),
				"Late arrival archive failed or already exists"
			)
			paused = false
	record.travel = unit.position.distance_to(start)
	record.moving = movement._has_destination
	_check(record.arrival > 0, "Attack never settled in twenty seconds")
	print(
		"ATTACK ARRIVAL AUDIT ",
		JSON.stringify(
			{
				"trial": trial,
				"arrival": record.arrival,
				"travel": record.travel,
				"archive": record.archive
			}
		)
	)
	records.append(record)
	game.queue_free()
	await _frames(5)


func _state(unit, started):
	var movement = unit.get_node("Movement")
	var path = movement.get_current_navigation_path()
	var end = path[-1] * Vector3(1, 0, 1) if not path.is_empty() else Vector3.ZERO
	var neighbors = []
	for other in game.battlefield.nearby_units(unit.position, 4):
		if other == unit or other.movement_speed <= 0:
			continue
		var other_movement = other.get_node("Movement")
		neighbors.append(
			{
				"role": other.type,
				"friendly": other.player == unit.player,
				"point": str(other.position),
				"end_distance": other.position.distance_to(end),
				"spacing": other.radius + unit.radius,
				"moving": other_movement._has_destination,
				"velocity": str(other_movement.velocity)
			}
		)
	return {
		"seconds": game.simulation_time - started,
		"point": str(unit.position),
		"end": str(end),
		"path": str(path),
		"path_index": movement.get_current_navigation_path_index(),
		"occupied": movement.has_occupied_endpoint(),
		"arrival_elapsed": unit.action._arrival_elapsed,
		"arrival_progress": str(unit.action._arrival_progress),
		"recovery_left": movement._recovery_left,
		"velocity": str(movement.velocity),
		"neighbors": neighbors
	}
