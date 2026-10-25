extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _fixture("bastion")
	var before = _game.get_units()
	_check(before == get_nodes_in_group("units"), "Initial registry differs from groups")
	_check(is_same(before, _game.get_units()), "Stable membership allocated another array")
	var first = _spawn("Tank", 0, Vector3(25, 0, 25))
	_check(first not in before, "Spawn mutated an existing iteration snapshot")
	_check(_game.get_units() == get_nodes_in_group("units"), "Spawn missing or out of order")
	var old_snapshot = _game.get_units()
	first.reparent(_players[1])
	_check(_game.get_units() == get_nodes_in_group("units"), "Capture changed registry order")
	_check(
		first in _game.get_units() and first.player == _players[1], "Capture lost live ownership"
	)
	var second = _spawn("Fighter", 0, Vector3(30, 4, 30))
	_check(_game.get_units() == get_nodes_in_group("units"), "Aircraft spawn not registered")
	# Callbacks may read the registry while a node is still leaving its groups.
	first.tree_exiting.connect(func(): _game.get_units())
	second.queue_free()
	first.queue_free()
	await _frames(3)
	_check(
		_game.get_units() == get_nodes_in_group("units"), "Direct deletion left stale membership"
	)
	_check(old_snapshot.size() == before.size() + 1, "Removal mutated an iteration snapshot")
	var relay = load("res://source/match/objectives/CaptureRelay.gd").new()
	_game.add_child(relay)
	_check(relay in _game.get_observers(), "Dynamic vision source not registered")
	relay.captured_by = _players[0]
	relay._update_presentation()
	_check(
		_game.get_cached_group("revealed_units") == get_nodes_in_group("revealed_units"),
		"Revealed source missing"
	)
	relay.captured_by = _players[1]
	_game.settings.visibility = _game.settings.Visibility.PER_PLAYER
	relay._update_presentation()
	_check(
		_game.get_cached_group("revealed_units") == get_nodes_in_group("revealed_units"),
		"Capture retained old revealed membership"
	)
	relay.tree_exiting.connect(func(): _game.get_observers())
	relay.queue_free()
	await _frames(3)
	_check(
		_game.get_observers() == _game.get_units() + get_nodes_in_group("vision_sources"),
		"Deleted vision source remained"
	)
	var resources = _game.get_cached_group("resource_units")
	var resource = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
	_game.add_child(resource)
	_check(
		resource not in resources and resource in _game.get_cached_group("resource_units"),
		"Resource spawn invalidation failed"
	)
	resource.tree_exiting.connect(func(): _game.get_cached_group("resource_units"))
	resource.queue_free()
	await _frames(3)
	_check(
		_game.get_cached_group("resource_units") == get_nodes_in_group("resource_units"),
		"Resource removal invalidation failed"
	)
	await _close()
	for message in _errors:
		push_error(message)
	print("Unit registry regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
