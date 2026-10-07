extends "res://tests/headless/Skirmish.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	var game = await _start(_settings("bastion", "helix", false))
	get_nodes_in_group("players")[1].set_process(false)
	var human = game._get_human_player()
	var worker = _unit(human, "Worker")
	var resource = get_nodes_in_group("resource_units")[0]
	var movement = worker.get_node("Movement")
	movement.set_physics_process(false)
	movement.avoidance_enabled = false
	worker.global_position = resource.global_position + Vector3(1.3, 0, 0)
	var collecting = load("res://source/match/units/actions/CollectingResourcesWhileInRange.gd")
	worker.issue_manual_order(collecting.new(resource))
	var action = worker.action
	var kind = "resource_a" if "resource_a" in resource else "resource_b"
	var before = resource.get(kind)
	movement.passive_movement_started.emit()
	await _frames(150)
	_check(
		worker.get(kind) > 0 and resource.get(kind) < before,
		"Crowd nudging starved an in-range harvester"
	)
	paused = true
	var cargo = worker.get(kind)
	await _frames(150)
	_check(worker.get(kind) == cargo, "Tactical pause advanced collection")
	paused = false
	# Moving out of range must not grant one final resource during action cleanup.
	worker.global_position += Vector3(5, 0, 0)
	action._transfer_single_resource_unit_from_resource_to_worker()
	_check(worker.get(kind) == cargo, "Out-of-range cleanup granted a resource")
	await _frames(3)
	worker.set(kind, 0)
	worker.global_position = resource.global_position + Vector3(1.3, 0, 0)
	worker.issue_manual_order(collecting.new(resource))
	worker.action._timer.paused = true  # Legacy crowd pause saved by previous builds.
	paused = true
	var snapshotter = load("res://source/match/saves/MatchSnapshot.gd").new()
	var saved = snapshotter.capture(game)
	_check(saved != null, "Harvest archive fixture failed")
	if saved != null:
		var id = snapshotter._reference(worker)
		var restorer = load("res://source/match/saves/MatchRestore.gd").new()
		var loaded = await restorer.restore(self, saved)
		_check(loaded.ok, "Legacy harvest archive failed to restore")
		if loaded.ok:
			game = loaded.game
			worker = restorer.entities[id]
			_check(not worker.action._timer.paused, "Legacy crowd pause remained latched")
			await _frames(150)
			_check(worker.get(kind) == 0, "Loading bypassed tactical pause")
			paused = false
			await _frames(150)
			_check(worker.get(kind) > 0, "Restored harvester never resumed collection")
	paused = false
	game.queue_free()
	await _frames(4)
	for error in _errors:
		push_error(error)
	print("Harvest continuity: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)
