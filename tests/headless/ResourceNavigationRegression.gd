extends "res://tests/headless/Skirmish.gd"

var game
var human
var moving
var harvest


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	moving = load("res://source/match/units/actions/Moving.gd")
	harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	for faction in ["bastion", "helix"]:
		game = await _start(_settings(faction, "helix", false))
		human = game._get_human_player()
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		for unit in get_nodes_in_group("units"):
			if unit.movement_speed > 0:
				unit.queue_free()
		for deposit in get_nodes_in_group("resource_units"):
			deposit.queue_free()
		await _frames(90)
		for spacing in [2.0, 2.5, 3.0, 3.5]:
			_check(await _gap(spacing) == true, "Gap scenario aborted")
		_check(await _approaches() == true, "Harvest approach scenario aborted")
		_check(await _range_limit() == true, "Resource range scenario aborted")
		_check(await _legacy_position() == true, "Legacy-position scenario aborted")
		game.queue_free()
		await _frames(5)
	for message in _errors:
		push_error(message)
	print("Resource navigation: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _spawn(role, point):
	var unit = load(Catalog.scene_path(role)).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), human, false)
	unit.sight_range = 0
	return unit


func _deposit(kind, point):
	var deposit = load("res://source/match/units/non-player/Resource%s.tscn" % kind).instantiate()
	deposit.position = point
	game.map.get_node("Resources").add_child(deposit)
	return deposit


func _gap(spacing):
	var center = Vector3(31.25, 0, 25)
	var left = _deposit("A", center - Vector3.RIGHT * spacing / 2)
	var right = _deposit("B", center + Vector3.RIGHT * spacing / 2)
	for role in ["Worker", "Tank"]:
		var unit = _spawn(role, center + Vector3(0, 0, -5))
		await _frames(120)
		for direction in [1, -1]:
			var destination = center + Vector3(0, 0, 5 * direction)
			unit.issue_manual_order(moving.new(destination))
			var closest = INF
			var lateral = 0.0
			for frame in 1200:
				await physics_frame
				closest = minf(
					closest,
					minf(
						unit.position.distance_to(left.position),
						unit.position.distance_to(right.position)
					)
				)
				lateral = maxf(lateral, absf(unit.position.x - center.x))
				if unit.position.distance_to(destination) < .4:
					break
			_check(
				unit.position.distance_to(destination) < .4,
				"%s stuck between %.1f m deposits" % [role, spacing]
			)
			_check(
				closest >= unit.radius + left.radius - .08,
				"%s crossed resource avoidance footprint" % role
			)
			if spacing == 3.5:
				_check(lateral < 1.0, "Open resource gap was unnecessarily closed")
		unit.queue_free()
		await _frames(5)
	left.queue_free()
	right.queue_free()
	await _frames(90)
	print("RESOURCE GAP ", human.faction, " spacing=", spacing, " complete")
	return true


func _approaches():
	for kind in ["A", "B"]:
		var deposit = _deposit(kind, Vector3(30.13, 0, 24.87))
		for offset in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var worker = _spawn("Worker", deposit.position + offset * 5)
			await _frames(90)
			var property = "resource_a" if kind == "A" else "resource_b"
			var before = human.get(property)
			worker.issue_manual_order(harvest.new(deposit))
			await _frames(2400)
			_check(
				human.get(property) >= before + 4,
				"%s harvest/return blocked from %s: %s" % [kind, offset, worker.position]
			)
			worker.queue_free()
			await _frames(5)
		deposit.queue_free()
		await _frames(90)
	print("RESOURCE APPROACHES ", human.faction, " materials/electronics four sides complete")
	return true


func _range_limit():
	var deposit = _deposit("B", Vector3(30.13, 0, 24.87))
	var worker = _spawn("Worker", Vector3(30, 0, 20))
	await _frames(90)
	var movement = worker.get_node("Movement")
	movement.set_physics_process(false)
	movement.avoidance_enabled = false
	var collecting = load("res://source/match/units/actions/CollectingResourcesWhileInRange.gd")
	worker.position = deposit.position + Vector3(1.75, 0, 0)
	worker.issue_manual_order(collecting.new(deposit))
	await _frames(150)
	_check(worker.resource_b > 0, "Engineer cannot work from rounded navigation boundary")
	worker.issue_manual_order(null)
	worker.resource_b = 0
	worker.position = deposit.position + Vector3(1.85, 0, 0)
	worker.issue_manual_order(collecting.new(deposit))
	await _frames(150)
	_check(worker.resource_b == 0, "Engineer gathers beyond bounded resource contact range")
	worker.issue_manual_order(null)
	var hq = _unit(human, "CommandCenter")
	var before = human.resource_b
	worker.resource_b = 4
	worker.position = hq.position + Vector3(hq.radius + 1.25, 0, 0)
	worker.issue_manual_order(harvest.new(hq))
	await _frames(60)
	_check(
		worker.resource_b == 4 and human.resource_b == before,
		"Engineer delivered beyond bounded building contact range"
	)
	worker.issue_manual_order(null)
	worker.position = hq.position + Vector3(hq.radius + 1.15, 0, 0)
	worker.issue_manual_order(harvest.new(hq))
	await _frames(60)
	_check(
		worker.resource_b == 0 and human.resource_b == before + 4,
		"Engineer cannot deliver from rounded HQ boundary"
	)
	_check(
		game.battlefield.line_clear(
			deposit.position + Vector3(-2, .4, 0), deposit.position + Vector3(2, .4, 0)
		),
		"Navigation footprint made salvage block sight"
	)
	worker.queue_free()
	deposit.queue_free()
	await _frames(90)
	return true


func _legacy_position():
	var left = _deposit("A", Vector3(30, 0, 25))
	var right = _deposit("A", Vector3(32.5, 0, 25))
	var worker = _spawn("Worker", Vector3(31.25, 0, 20))
	await _frames(90)
	worker.resource_b = 4
	worker.issue_manual_order(harvest.new(_unit(human, "CommandCenter")))
	# An older save may contain the exact position where the old navmesh trapped it.
	worker.position = Vector3(31.25, 0, 24.99)
	paused = true
	var snapshotter = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = snapshotter.capture(game)
	_check(snapshot != null, "Legacy gap capture failed: " + snapshotter.error)
	if snapshot == null:
		return false
	var id = snapshotter._reference(worker)
	var resource_ids = [snapshotter._reference(left), snapshotter._reference(right)]
	var before_position = worker.position
	var before_income = human.resource_b
	var store = load("res://source/match/saves/SaveFile.gd").new()
	var path = "user://resource-navigation-%d.json" % OS.get_process_id()
	_check(store.write_file(path, snapshot), "Resource navigation disk write failed")
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await restore.restore(self, store.read_file(path))
	DirAccess.remove_absolute(path)
	_check(result.ok, "Resource navigation restore failed: " + result.get("error", ""))
	if not result.ok:
		return false
	game = result.game
	human = game._get_human_player()
	worker = restore.entities[id]
	await _frames(30)
	_check(
		worker.position == before_position and worker.resource_b == 4,
		"Paused load changed the saved trapped position or cargo"
	)
	paused = false
	await _frames(1800)
	_check(
		human.resource_b == before_income + 4 and worker.resource_b == 0,
		"Restored trapped engineer failed to deliver exact cargo"
	)
	for resource_id in resource_ids:
		restore.entities[resource_id].set("resource_a", 0)
	await _frames(120)
	worker.position = Vector3(31.25, 0, 20)
	worker.issue_manual_order(moving.new(Vector3(31.25, 0, 30)))
	var lateral = 0.0
	for frame in 600:
		await physics_frame
		lateral = maxf(lateral, absf(worker.position.x - 31.25))
	_check(
		worker.position.z > 29.5 and lateral < .25,
		"Depleted resource footprints still block the direct route"
	)
	print(
		"RESOURCE ARCHIVE ",
		human.faction,
		" exact paused state, cargo return and depletion complete"
	)
	return true
