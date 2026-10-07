extends "res://tests/headless/SaveRestoreEdges.gd"

const TRAFFIC_ARCHIVE = (
	"res://docs/playtests/2026-10-06/relay-commitment/"
	+ "final6-earned-case6-10-infantry_ready.json"
)
var watched = []
var starting = []
var arrived = false
var collected = false
var delivered = false
var maximum_step = 0.0
var minimum_clearance = INF
var maximum_off_mesh = 0.0
var case_label = ""


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for trial in 3:
		case_label = "archive-%d" % trial
		await _open_traffic()
		if trial == 1:
			await _disk_recovery()
		await _travel()
	for message in errors:
		push_error(message)
	print("HQ traffic: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _open_traffic():
	arrived = false
	collected = false
	delivered = false
	maximum_step = 0.0
	minimum_clearance = INF
	maximum_off_mesh = 0.0
	var data = FileStore.new().read_file(TRAFFIC_ARCHIVE)
	var restore = Restore.new()
	var loaded = await restore.restore(self, data)
	_check(loaded.ok, "HQ traffic archive did not restore")
	if not loaded.ok:
		return
	game = loaded.game
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	watched = [restore.entities["unit-8"], restore.entities["unit-15"]]
	starting = watched.map(func(unit): return unit.position)
	_check(game.simulation_time == data.simulation_time and paused, "Traffic load advanced clock")
	var actions = watched.map(func(unit): return unit.action)
	await _frames(30)
	_check(watched.map(func(unit): return unit.position) == starting, "Paused traffic moved")
	_check(watched.map(func(unit): return unit.action) == actions, "Paused traffic changed orders")
	await _review_traffic("before")


func _travel():
	var target = watched[0].action._target_position
	var finish_reported = false
	var previous = starting.duplicate()
	var cargo = 0
	var started = game.simulation_time
	var arrival_time = -1.0
	var escape_time = -1.0
	var collection_time = -1.0
	var delivery_time = -1.0
	paused = false
	for frame in 3600:
		await _frames(1)
		for index in watched.size():
			var unit = watched[index]
			if not is_instance_valid(unit) or unit.hp <= 0:
				continue
			maximum_step = maxf(maximum_step, unit.position.distance_to(previous[index]))
			_measure_clearance(unit)
			previous[index] = unit.position
			if index == 0 and escape_time < 0 and unit.position.distance_to(starting[0]) > 2:
				escape_time = game.simulation_time - started
			if (
				index == 0
				and not finish_reported
				and not unit.get_node("Movement")._has_destination
			):
				print(
					"HQ MOVE END ",
					JSON.stringify(
						{
							"case": case_label,
							"seconds": game.simulation_time - started,
							"point": str(unit.position),
							"target": str(target),
							"distance": unit.position.distance_to(target),
							"action": str(unit.action),
							"hp": unit.hp
						}
					)
				)
				finish_reported = true
			if (
				index == 0
				and not arrived
				and not unit.get_node("Movement")._has_destination
				and unit.position.distance_to(target) < .5
			):
				arrived = true
				arrival_time = game.simulation_time - started
			if index == 1:
				if not collected and unit.resource_b > 0:
					collected = true
					collection_time = game.simulation_time - started
				if not delivered and cargo > 0 and unit.resource_b == 0:
					delivered = true
					delivery_time = game.simulation_time - started
				cargo = unit.resource_b
		if frame == 0:
			for unit in watched:
				_describe_recovery(unit)
		if frame == 599:
			await _review_traffic("ten-seconds")
		if delivered and (arrived or not is_instance_valid(watched[0])):
			break
	var survivor = is_instance_valid(watched[0]) and watched[0].hp > 0
	_check(
		escape_time >= 0 and escape_time <= 10, "Wounded engineer did not escape the traffic pinch"
	)
	_check(
		(arrived and arrival_time <= 15) or not survivor,
		"Surviving engineer failed its original Move within fifteen seconds"
	)
	_check(collected, "Stalled engineer never collected electronics")
	_check(delivered, "Stalled engineer never delivered electronics")
	_check(maximum_step < 3.84 / 60 + .002, "Traffic recovery teleported a worker")
	_check(minimum_clearance >= -.05, "Traffic recovery crossed a mobile body")
	_check(maximum_off_mesh <= .16, "Traffic recovery left the navigation boundary")
	print(
		"HQ TRAFFIC ",
		JSON.stringify(
			{
				"case": case_label,
				"escape": escape_time,
				"arrival": arrival_time,
				"survived": survivor,
				"collection": collection_time,
				"delivery": delivery_time,
				"maximum_step": maximum_step,
				"minimum_clearance": minimum_clearance,
				"maximum_off_mesh": maximum_off_mesh
			}
		)
	)
	await _review_traffic("after")
	paused = false
	game.queue_free()
	await _frames(5)


func _measure_clearance(unit):
	var movement = unit.get_node("Movement")
	var nearest = NavigationServer3D.map_get_closest_point(
		movement.get_navigation_map(), unit.position
	)
	maximum_off_mesh = maxf(
		maximum_off_mesh, ((nearest - unit.position) * Vector3(1, 0, 1)).length()
	)
	for other in game.battlefield.nearby_units(unit.position, 3):
		if (
			other == unit
			or other.movement_speed <= 0
			or other.movement_domain != unit.movement_domain
		):
			continue
		minimum_clearance = minf(
			minimum_clearance,
			(
				unit.global_position_yless.distance_to(other.global_position_yless)
				- unit.radius
				- other.radius
			)
		)


func _disk_recovery():
	paused = false
	await _frames(72)
	game.hud.pause_after_load()
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	var ids = watched.map(func(unit): return builder._reference(unit))
	var points = watched.map(func(unit): return unit.position)
	var destinations = watched.map(func(unit): return unit.get_node("Movement").target_position)
	var file = "user://hq-traffic-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, snapshot), "Traffic recovery save failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Traffic recovery disk restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	watched = ids.map(func(id): return restore.entities[id])
	starting = watched.map(func(unit): return unit.position)
	_check(starting == points and paused, "Recovery load moved workers")
	_check(game.simulation_time == snapshot.simulation_time, "Recovery load advanced clock")
	_check(
		watched.map(func(unit): return unit.get_node("Movement").target_position) == destinations,
		"Recovery load changed destinations"
	)
	await _review_traffic("reloaded")


func _describe_recovery(unit):
	var movement = unit.get_node("Movement")
	var path = movement.get_current_navigation_path()
	if path.is_empty():
		return
	var direction = (
		((path[movement.get_current_navigation_path_index()] - unit.position) * Vector3(1, 0, 1))
		. normalized()
	)
	var neighbors = game.battlefield.nearby_units(unit.position, 4)
	var candidates = []
	for angle in [PI / 2.0, -PI / 2.0, PI / 4.0, -PI / 4.0, 3 * PI / 4.0, -3 * PI / 4.0, PI]:
		var candidate = direction.rotated(Vector3.UP, angle)
		var clearance = movement._recovery_clearance(candidate)
		var contact = movement._ground_step_contact(
			unit.position, unit.position + candidate * clearance, neighbors
		)
		candidates.append(
			{
				"angle": rad_to_deg(angle),
				"nav_clearance": clearance,
				"free": clearance * contact.fraction
			}
		)
	print(
		"HQ RECOVERY ",
		JSON.stringify(
			{
				"position": str(unit.position),
				"radius": unit.radius,
				"chosen": str(movement._ground_recovery_direction(direction)),
				"candidates": candidates
			}
		)
	)


func _review_traffic(_label):
	pass
