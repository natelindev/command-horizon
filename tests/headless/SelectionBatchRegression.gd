extends "res://tests/headless/SaveRestoreEdges.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	await _skirmish("bastion", "res://source/match/maps/battlefields/AlpineRelayMap.tscn", true)
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	var human = game._get_human_player()
	var workers = _units(human, "Worker")
	while workers.size() < 40:
		var worker = load("res://source/match/units/Worker.tscn").instantiate()
		game._setup_and_spawn_unit(
			worker, Transform3D(Basis(), game.map.ground_point(Vector2(30, 30))), human, false
		)
		workers.append(worker)
	await _frames(5)
	var menus = game.find_child("UnitMenus")
	game.hud.select_units([workers[0]])
	await _frames(3)
	# A box selection must not allocate a complete control tree for each
	# intermediate selection. Those trees survive until the end of this frame.
	var nodes_before = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	game.hud.select_units(workers)
	var added_nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes_before
	_check(added_nodes < 100, "Selection burst allocated intermediate HUD trees")
	_check(not menus._content.visible, "Old commands accept input during a pending selection")
	await _frames(3)
	_check(menus._selection == workers, "HUD does not describe the final selection")
	_check(menus._content.visible, "Final commands remain hidden")
	_check(menus._selection_roster._members.size() == 40, "Final roster omitted workers")
	# The deferred update must also run during tactical pause.
	paused = true
	game.hud.select_units([workers[-1]])
	await _frames(3)
	_check(menus._selection == [workers[-1]], "Paused selection did not update")
	_check(menus.find_child("BuildBarracks", true, false) != null, "Builder lost construction menu")
	var command_pages = menus._pages
	workers[0].hp = 0
	await _frames(3)
	_check(is_instance_valid(command_pages), "Previously selected death rebuilt current commands")
	var enemy = get_nodes_in_group("units").filter(func(unit): return unit.player != human)[0]
	enemy.hp = 0
	await _frames(3)
	_check(is_instance_valid(command_pages), "Unselected death rebuilt the current commands")
	workers[-1].hp = 0
	await _frames(3)
	_check(
		menus._selection.is_empty() and not menus.visible,
		"Dead selected worker left active commands"
	)
	paused = false
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Selection batch: %d failures; burst allocated %d nodes" % [errors.size(), added_nodes])
	quit(0 if errors.is_empty() else 1)
