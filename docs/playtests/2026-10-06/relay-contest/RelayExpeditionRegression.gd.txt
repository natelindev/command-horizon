extends "res://tests/headless/SaveRestoreEdges.gd"

var policy_script


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	policy_script = load("res://tests/playtest/reference/RelayExpeditionPolicy.gd")
	for map_name in ["AlpineRelay", "IndustrialCrossroads"]:
		for faction in ["bastion", "helix", "frontier"]:
			await _capture_case(faction, map_name)
	await _observed_priority()
	for message in errors:
		push_error(message)
	print("Relay expedition: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _capture_case(faction, map_name):
	await _skirmish(faction, "res://source/match/maps/%s.tscn" % map_name, false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var player = game._get_human_player()
	var units = _owned(player)
	var home = _units(player, "CommandCenter")[0].position + Vector3(0, 0, 6)
	var policy = policy_script.new()
	var funds = Vector2i(player.resource_a, player.resource_b)
	var label = faction + " " + map_name
	await _bounds(policy, player, units, home, label)
	var held = (
		[]
		if "--original-policy" in OS.get_cmdline_user_args()
		else policy.update(game, player, units, "defend", [], home)
	)
	_check(held.size() == 1, label + ": Standard opening never dispatched a relay infantry")
	if held.size() == 1:
		var unit = held[0]
		var objective = policy.relay.get_ref()
		var other = _units(player, "Infantry").filter(func(item): return item != unit)[0]
		_check(not other.get_node("Movement")._has_destination, "Home infantry was also dispatched")
		_check(unit.program == null or not unit.program.installed, "Expedition granted a chip")
		var order = unit.action
		paused = true
		var point = unit.position
		await _frames(60)
		_check(
			policy.update(game, player, units, "attack", [], home) == held,
			"Pause changed expedition"
		)
		_check(unit.position == point and unit.action == order, "Paused expedition advanced")
		paused = false
		await _frames(30)
		var travelling = await _travel_roundtrip(unit, objective)
		if not travelling.is_empty():
			unit = travelling.unit
			objective = travelling.objective
			player = unit.player
		paused = false
		var partial = false
		for frame in 3600:
			await _frames(1)
			if objective.candidate == player and objective.progress >= 2:
				partial = true
				break
		_check(partial, label + ": paid opening infantry did not reach relay capture")
		if partial:
			_check(
				Vector2i(player.resource_a, player.resource_b) == funds, "Expedition changed funds"
			)
			await _capture_roundtrip(unit, objective, label)
	paused = false
	game.queue_free()
	await _frames(5)


func _capture_roundtrip(unit, objective, label):
	paused = true
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var unit_id = builder._reference(unit)
	var name = objective.name
	var progress = objective.progress
	var point = unit.position
	var file = "user://relay-expedition-%d.json" % OS.get_process_id()
	var store = FileStore.new()
	_check(store.write_file(file, data), "Partial expedition save failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, store.read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Partial expedition restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return
	game = loaded.game
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	unit = restore.entities[unit_id]
	objective = game.map.relays.filter(func(item): return item.name == name)[0]
	var player = unit.player
	_check(
		unit.position == point and objective.progress == progress, "Paused capture reload advanced"
	)
	await _frames(60)
	_check(objective.progress == progress, "Paused capture timer advanced")
	paused = false
	await _frames(660)
	_check(objective.captured_by == player, label + ": loaded expedition did not finish capture")
	_check(objective.is_revealing(), "Captured relay did not grant player vision")
	_check(
		unit.position.distance_to(objective.position) <= objective.RADIUS,
		"Infantry left capture circle"
	)
	print("RELAY EXPEDITION ", label, " captured=", name, " after partial disk restoration")
	await _review_relay(unit, objective, label)


func _bounds(policy, player, units, home, label):
	var infantry = _units(player, "Infantry")
	_check(
		policy.update(game, player, units, "attack", [], home).is_empty(),
		"Assault dispatched expedition"
	)
	_check(
		policy.update(game, player, units, "recover", [], home).is_empty(),
		"Regroup dispatched expedition"
	)
	_check(
		policy.update(game, player, units, "defend", infantry, home).is_empty(),
		"Recovery patient dispatched"
	)
	var hp = infantry[0].hp
	infantry[0].hp = hp * .5
	_check(
		policy.update(game, player, units, "defend", [], home).is_empty(), "No healthy home reserve"
	)
	infantry[0].hp = hp
	for relay in game.map.relays:
		relay.captured_by = player
	_check(
		policy.update(game, player, units, "defend", [], home).is_empty(),
		"Owned relay dispatched expedition"
	)
	for relay in game.map.relays:
		relay.captured_by = null
	game.battlefield.invalidate()
	print("RELAY BOUNDS ", label, " phase, recovery, health, home reserve and ownership")


func _owned(player):
	return get_nodes_in_group("units").filter(
		func(unit):
			return unit.player == player and unit.hp > 0 and not unit.is_queued_for_deletion()
	)


func _review_relay(_unit, _objective, _label):
	pass


func _observed_priority():
	await _skirmish("frontier", "res://source/match/maps/AlpineRelay.tscn", false)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var player = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != player)[0]
	var units = _owned(player)
	var hq = _units(player, "CommandCenter")[0]
	var home = hq.position + Vector3(0, 0, 6)
	var objective = game.map.relays[0]
	var hostiles = []
	for index in 3:
		var hostile = load("res://source/match/units/Tank.tscn").instantiate()
		game._setup_and_spawn_unit(
			hostile,
			Transform3D(Basis(), objective.position + Vector3(index + 2, 0, 0)),
			enemy,
			false
		)
		hostile.set_process(false)
		hostiles.append(hostile)
	await _frames(8)
	game.battlefield.invalidate()
	_check(
		hostiles.all(func(unit): return not game.battlefield.is_observed(player, unit)),
		"Hidden-contact fixture is visible"
	)
	var policy = policy_script.new()
	var held = policy.update(game, player, units, "defend", [], home)
	_check(held.size() == 1, "Hidden relay army leaked into expedition planning")
	if held.is_empty():
		game.queue_free()
		await _frames(5)
		return
	var unit = held[0]
	hostiles[0].position = hq.position + Vector3(6, 0, 0)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(player, hostiles[0]), "Home danger fixture is hidden")
	_check(
		policy.update(game, player, units, "defend", [], home).is_empty(),
		"Observed home danger did not recall expedition"
	)
	_check(policy.episodes[-1].result == "home_priority", "Home recall reason lost")
	_check(unit.action.destination == home, "Recalled infantry did not return home")
	for hostile in hostiles:
		hostile.queue_free()
	await _frames(5)
	game.battlefield.invalidate()
	_check(
		policy.update(game, player, units, "defend", [], home).is_empty(),
		"Recall cooldown immediately redispatched infantry"
	)
	policy = policy_script.new()
	held = policy.update(game, player, units, "defend", [], home)
	var order = held[0].action
	_check(
		policy.update(game, player, units, "defend", held, home).is_empty(),
		"Recovery retained relay control"
	)
	_check(held[0].action == order, "Relay recall replaced protected recovery order")
	policy = policy_script.new()
	held = policy.update(game, player, units, "defend", [], home)
	policy.started -= 60
	_check(
		policy.update(game, player, units, "defend", [], home).is_empty(),
		"Unfinished expedition exceeded timeout"
	)
	_check(policy.episodes[-1].result == "timeout", "Expedition timeout reason lost")
	print(
		"RELAY PRIORITIES hidden contacts, observed home danger, protected recovery and bounded retries"
	)
	game.queue_free()
	await _frames(5)


func _travel_roundtrip(unit, objective):
	paused = true
	_check(
		unit.position.distance_to(objective.position) > objective.RADIUS,
		"Travel archive was already at relay"
	)
	var destination = unit.action.destination
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var id = builder._reference(unit)
	var name = objective.name
	var point = unit.position
	var file = "user://relay-travel-%d.json" % OS.get_process_id()
	var store = FileStore.new()
	_check(store.write_file(file, data), "Travelling expedition save failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, store.read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Travelling expedition restore failed: " + loaded.get("error", ""))
	if not loaded.ok:
		return {}
	game = loaded.game
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	unit = restore.entities[id]
	objective = game.map.relays.filter(func(item): return item.name == name)[0]
	_check(
		unit.position == point and unit.action.destination == destination,
		"Reload changed travelling relay order"
	)
	return {"unit": unit, "objective": objective}
