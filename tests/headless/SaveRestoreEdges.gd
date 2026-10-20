extends "res://tests/headless/SaveRestoreRegression.gd"


func _run():
	save_path = "user://restore-edges-%d.json" % OS.get_process_id()
	path = "user://restore-edges-campaign-%d.json" % OS.get_process_id()
	for faction in ["bastion", "helix"]:
		await _skirmish(faction)
		await _edge_cases()
		paused = false
		game.queue_free()
		await _frames(5)
	for map_name in ["PlainAndSimple", "BigArena"]:
		await _skirmish("bastion", "res://source/match/maps/%s.tscn" % map_name)
		paused = true
		var builder = Snapshot.new()
		var snapshot = builder.capture(game)
		var restore = Restore.new()
		var loaded = await restore.restore(self, snapshot)
		_check(loaded.ok, "Map reload failed: " + map_name + ": " + loaded.get("error", ""))
		if loaded.ok:
			game = loaded.game
			_check(game.settings.map_path == snapshot.settings.map_path, "Restored wrong map")
			_check(
				get_nodes_in_group("units").size() == snapshot.units.size(),
				"Reload spawned duplicate army"
			)
		paused = false
		game.queue_free()
		await _frames(5)
	await _finish()


func _skirmish(faction, map_path = "res://source/match/maps/BastionDesert.tscn", advanced = true):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = advanced
	settings.map_path = map_path
	for index in range(2):
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = faction if index == 0 else ("helix" if faction == "bastion" else "bastion")
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(60)


func _edge_cases():
	var behavior = load("res://source/match/orders/UnitBehavior.gd")
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	var other = _units(human, "Tank")[1]
	var worker = _units(human, "Worker")[0]
	var leader = _units(human, "Worker")[1]
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	enemy.set_process(false)
	_check(behavior.set_stance(tank, "hold_fire"), "Hold Fire fixture failed")
	_check(behavior.follow(other, leader), "Follow fixture failed")
	await _frames(90)
	var deposit = get_nodes_in_group("resource_units")[0]
	worker.issue_manual_order(
		load("res://source/match/units/actions/CollectingResourcesSequentially.gd").new(deposit)
	)
	worker.resource_a = 2
	var remembered = _units(enemy, "CommandCenter")[0]
	var visibility = game.get_node("Handlers/UnitVisibilityHandler")
	visibility._create_dummy_structure(remembered)
	# The real structure stays hidden; its remembered identity must survive repeated reloads.
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Edge fixture capture failed: " + builder.error)
	if snapshot == null:
		return
	var ids = {
		"hold": builder._reference(tank),
		"follow": builder._reference(other),
		"leader": builder._reference(leader),
		"worker": builder._reference(worker),
		"resource": builder._reference(worker.action.get_resource_unit()),
	}
	var restore = Restore.new()
	for cycle in range(2):
		var loaded = await restore.restore(self, snapshot)
		_check(loaded.ok, "Repeated load failed: " + loaded.get("error", ""))
		if not loaded.ok:
			return
		game = loaded.game
		game.get_node("IsometricCamera3D").set_physics_process(false)
		tank = restore.entities[ids.hold]
		other = restore.entities[ids.follow]
		_check(behavior.current(tank) == "hold_fire", "Reload lost Hold Fire")
		_check(
			(
				behavior.current(other) == "follow"
				and other.manual_orders.current.target.get_ref() == restore.entities[ids.leader]
			),
			"Reload lost the follow target"
		)
		_check(
			game.get_node("Handlers/UnitVisibilityHandler")._structure_to_dummy_mapping.size() == 1,
			"Remembered structure duplicated/lost"
		)
		var recaptured = Snapshot.new().capture(game)
		_check(recaptured != null, "Loaded match could not save again")
		if recaptured == null:
			return
		# Snapshot IDs are local; use a fresh capture for the next independent load below.
		_check(
			recaptured.simulation_time == snapshot.simulation_time, "Repeated reload advanced time"
		)
	game.hud._pause_button.pressed.emit()
	await _frames(120)
	_check(behavior.current(tank) == "hold_fire", "Hold Fire did not survive resume")
	_check(behavior.current(other) == "follow", "Follow did not survive resume")
	# Remove the actual reserved deposit (which may differ from the clicked field anchor).
	var missing = snapshot.duplicate(true)
	missing.resources = missing.resources.filter(func(value): return value.id != ids.resource)
	var loaded = await restore.restore(self, missing)
	_check(loaded.ok, "Missing resource rejected whole army")
	if not loaded.ok:
		return
	game = loaded.game
	worker = restore.entities[ids.worker]
	_check(worker.resource_a == 2, "Missing resource discarded cargo")
	_check(worker.action == null, "Missing nested target left a stuck harvesting action")
	_check(not loaded.warnings.is_empty(), "Missing target did not explain Hold fallback")
	game.hud._pause_button.pressed.emit()
	worker.manual_orders.submit({"kind": "move", "point": worker.position + Vector3(3, 0, 0)})
	var position = worker.position
	await _frames(90)
	_check(
		worker.position.distance_to(position) > 0.2, "Missing target fallback lost manual control"
	)
	# A missing follow target falls back to Hold without rejecting the army.
	missing = snapshot.duplicate(true)
	missing.units = missing.units.filter(func(value): return value.id != ids.leader)
	loaded = await restore.restore(self, missing)
	_check(loaded.ok, "Missing follow target rejected whole army")
	if not loaded.ok:
		return
	game = loaded.game
	other = restore.entities[ids.follow]
	_check(behavior.current(other) != "follow", "Follow survived without its target")
	game.hud._pause_button.pressed.emit()
	other.manual_orders.submit({"kind": "move", "point": other.position + Vector3(3, 0, 0)})
	position = other.position
	await _frames(90)
	_check(other.position.distance_to(position) > 0.2, "Missing follow target lost manual control")
	print("PASS: ", game._get_human_player().faction, " reload/repeat/stances/targets/knowledge")
