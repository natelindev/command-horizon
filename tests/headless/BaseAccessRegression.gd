extends "res://tests/headless/CrowdBoundaryRegression.gd"

const POCKET_ARCHIVE = "res://docs/playtests/2026-10-03/skirmish-empty-path-battle.json"
const POCKET_POINT = Vector3(109.686, 0, 65.25195)
const CLOSING_TURRET = Vector3(107.7039, 0, 64.45673)


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _rebuild_archived_turret()
	for message in errors:
		push_error(message)
	print("Base access regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _rebuild_archived_turret():
	var record = FileStore.new().read_file(POCKET_ARCHIVE)
	if DisplayServer.get_name() != "headless":
		record.settings.visibility = 2  # Show the AI base for the rendered diagnostic.
	var loaded = await Restore.new().restore(self, record)
	_check(loaded.ok, "Could not restore empty-path archive")
	if not loaded.ok:
		return
	game = loaded.game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var workers = get_nodes_in_group("units").filter(func(unit): return unit.type == "Worker")
	workers.sort_custom(
		func(a, b):
			return a.position.distance_to(POCKET_POINT) < b.position.distance_to(POCKET_POINT)
	)
	var worker = workers[0]
	var commander = worker.player
	var deposit = worker.action.get_resource_unit()
	worker.action = null
	for unit in get_nodes_in_group("units"):
		if unit != worker and unit.movement_speed > 0:
			unit.queue_free()
	paused = false
	await _frames(120)
	var movement = worker.get_node("Movement")
	var nav = movement.get_navigation_map()
	var original_path = NavigationServer3D.map_get_path(nav, POCKET_POINT, deposit.position, true)
	_check(
		not original_path.is_empty() and original_path[-1].distance_to(deposit.position) > 10,
		"Archive no longer reproduces island"
	)
	print("ARCHIVED ISLAND route=", original_path)
	await _review_traffic(worker, "base-closed")
	for unit in get_nodes_in_group("units"):
		if unit.type == "AntiAirTurret" and unit.position.distance_to(CLOSING_TURRET) < .1:
			unit.queue_free()
	await _frames(120)
	var opened_path = NavigationServer3D.map_get_path(nav, POCKET_POINT, deposit.position, true)
	_check(
		not opened_path.is_empty() and opened_path[-1].distance_to(deposit.position) < 2,
		"Removing closing turret did not open route"
	)
	var chosen = commander._find_site(Vector3(110, 0, 70), 1.1, nav)
	_check(chosen.is_finite(), "Commander could not find an accessible turret site")
	if not chosen.is_finite():
		return
	print("REBUILD SITE ", chosen)
	_traffic_unit("AntiAirTurret", commander, chosen)
	await _frames(120)
	var route = NavigationServer3D.map_get_path(nav, POCKET_POINT, deposit.position, true)
	_check(
		not route.is_empty() and route[-1].distance_to(deposit.position) < 2,
		"AI turret placement closed the engineer's exit"
	)
	# Keep the original worker position as the adverse construction fixture.
	worker.position = POCKET_POINT
	worker.issue_manual_order(
		load("res://source/match/units/actions/CollectingResourcesSequentially.gd").new(deposit)
	)
	var funds = commander.resource_b
	var previous = worker.position
	var maximum_step = 0.0
	for frame in 1800:
		await physics_frame
		maximum_step = maxf(maximum_step, worker.position.distance_to(previous))
		previous = worker.position
		if frame == 899:
			paused = true
			var snapshotter = Snapshot.new()
			var snapshot = snapshotter.capture(game)
			_check(snapshot != null, "Accessible base snapshot failed")
			if snapshot == null:
				quit(1)
				return
			var worker_id = snapshotter._reference(worker)
			var cargo = Vector2(worker.resource_a, worker.resource_b)
			var file = FileStore.new()
			var archive = "user://base-access-%d.json" % OS.get_process_id()
			_check(file.write_file(archive, snapshot), "Accessible base archive write failed")
			var restore = Restore.new()
			loaded = await restore.restore(self, file.read_file(archive))
			DirAccess.remove_absolute(archive)
			_check(loaded.ok, "Accessible base restore failed")
			if not loaded.ok:
				quit(1)
				return
			game = loaded.game
			worker = restore.entities[worker_id]
			commander = worker.player
			await _frames(30)
			_check(worker.position == previous, "Paused base restore moved engineer")
			_check(
				Vector2(worker.resource_a, worker.resource_b) == cargo, "Base restore changed cargo"
			)
			_check(
				worker.action != null and worker.action.has_method("harvest_status"),
				"Base restore lost harvest order"
			)
			paused = false
	print("REBUILT BASE income=", commander.resource_b - funds, " maximum_step=", maximum_step)
	_check(
		commander.resource_b > funds,
		"Engineer did not deliver electronics through the rebuilt base"
	)
	_check(maximum_step < worker.movement_speed / 60.0 + .002, "Engineer recovery teleported")
	await _review_traffic(worker, "base-open")
	game.queue_free()
	await _frames(5)
	game = null
