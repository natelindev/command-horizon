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
	var human = game._get_human_player()
	var tank = _units(human, "Tank")[0]
	var other = _units(human, "Tank")[1]
	var worker = _units(human, "Worker")[0]
	var hq = _units(human, "CommandCenter")[0]
	var enemy = get_nodes_in_group("players").filter(func(p): return p != human)[0]
	enemy.set_process(false)
	human.resource_b = 100
	tank.program.installed = false
	tank.position = hq.position + Vector3(0, 0, 2.5)
	_check(tank.program.install_at(hq), "Retrofit fixture could not start")
	other.program.configure_lua(HOLD)
	other.program.run()
	await _frames(90)
	_check(
		tank.program.install_left > 0 and tank.program.install_left < 5, "Retrofit never progressed"
	)
	var deposit = get_nodes_in_group("resource_units")[0]
	worker.issue_manual_order(
		load("res://source/match/units/actions/CollectingResourcesSequentially.gd").new(deposit)
	)
	worker.resource_a = 2
	var remembered = _units(enemy, "CommandCenter")[0]
	var visibility = game.get_node("Handlers/UnitVisibilityHandler")
	visibility._create_dummy_structure(remembered)
	# The real structure stays hidden; its remembered identity must survive repeated reloads.
	other.program.lua_runtime.suspended = true
	other.program.lua_runtime.error = "Saved fault fixture"
	paused = true
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Edge fixture capture failed: " + builder.error)
	if snapshot == null:
		return
	var ids = {
		"chip": builder._reference(tank),
		"fault": builder._reference(other),
		"worker": builder._reference(worker),
		"resource": builder._reference(worker.action.get_resource_unit()),
		"hq": builder._reference(hq)
	}
	var before = snapshot.players[0].resource_b
	var left = tank.program.install_left
	var restore = Restore.new()
	for cycle in range(2):
		var loaded = await restore.restore(self, snapshot)
		_check(loaded.ok, "Repeated load failed: " + loaded.get("error", ""))
		if not loaded.ok:
			return
		game = loaded.game
		game.get_node("IsometricCamera3D").set_physics_process(false)
		tank = restore.entities[ids.chip]
		other = restore.entities[ids.fault]
		_check(tank.program.install_left == left, "Reload advanced retrofit")
		_check(game._get_human_player().resource_b == before, "Reload duplicated retrofit fee")
		_check(
			other.program.mode == "Error" and other.program.lua_runtime.suspended,
			"Fault resumed automatically"
		)
		_check(
			other.action == null or other.action.has_method("is_idle"),
			"Fault kept active Lua action"
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
	await _frames(320)
	_check(
		tank.program.installed and tank.program.install_left == 0,
		"Restored retrofit did not finish"
	)
	_check(other.program.lua_runtime.suspended, "Fault silently recovered after resume")
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
	# A missing paid retrofit service cancels once and refunds exactly its paid fee.
	missing = snapshot.duplicate(true)
	missing.units = missing.units.filter(func(value): return value.id != ids.hq)
	loaded = await restore.restore(self, missing)
	_check(loaded.ok, "Missing chip service rejected whole army")
	if not loaded.ok:
		return
	game = loaded.game
	tank = restore.entities[ids.chip]
	_check(
		tank.program.install_left == 0 and not tank.program.installed,
		"Missing service left installation active"
	)
	_check(game._get_human_player().resource_b == before + 4, "Missing service refund incorrect")
	# Invalid explicit memory resets with feedback, while the army/program remain available.
	var invalid_memory = snapshot.duplicate(true)
	var saved_program = _saved(invalid_memory, ids.fault).program
	saved_program.runtime.state = {"unsafe": Vector3.ZERO}
	saved_program.runtime.suspended = false
	saved_program.runtime.error = ""
	loaded = await restore.restore(self, invalid_memory)
	_check(loaded.ok, "Invalid memory rejected whole army")
	if not loaded.ok:
		return
	game = loaded.game
	other = restore.entities[ids.fault]
	_check(other.program.lua_runtime.state_snapshot().is_empty(), "Invalid memory was retained")
	_check(not loaded.warnings.is_empty(), "Memory reset feedback missing")
	game.hud._pause_button.pressed.emit()
	await _frames(20)
	_check(
		other.program.lua_runtime.state_snapshot().get("ticks", 0) > 0,
		"Program failed to resume after memory reset"
	)
	print(
		"PASS: ",
		game._get_human_player().faction,
		" reload/repeat/chip/targets/faults/memory/knowledge"
	)
