extends "res://tests/rendered/PaidProgressionPreview.gd"


func _earned_interface():
	if "--cluster" in OS.get_cmdline_user_args():
		await _cluster()
		return
	_check(interactive, "Resource preview requires native --interactive input")
	var overlay = game.get_node("OwnershipLayer/OwnershipOverlay")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(25)
	camera.set_position_safely(lab.position)
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _frames(400)
	var resources = get_nodes_in_group("resource_units").filter(
		func(node): return overlay._resource_known(node)
	)
	var materials = resources.filter(
		func(node): return "resource_a" in node and not node.is_in_group("salvage_wrecks")
	)
	var electronics = resources.filter(func(node): return "resource_b" in node)
	var wrecks = resources.filter(func(node): return node.is_in_group("salvage_wrecks"))
	_check(not materials.is_empty(), "Earned battle lacks observed materials")
	_check(not electronics.is_empty(), "Earned battle lacks observed electronics")
	_check(not wrecks.is_empty(), "Earned battle lacks observed wrecks")
	if materials.is_empty() or electronics.is_empty() or wrecks.is_empty():
		return
	print(
		"EARNED RESOURCE POOL ",
		materials.size(),
		" materials, ",
		electronics.size(),
		" electronics, ",
		wrecks.size(),
		" wrecks"
	)
	await _capture("battle")
	for target in [materials[0], electronics[0], wrecks[0]]:
		camera.set_position_safely(target.global_position)
		await _frames(10)
		var projected = camera.unproject_position(target.global_position + Vector3.UP * .3)
		print("RESOURCE TARGET ", target.name, " physical=", root.get_final_transform() * projected)
		var before = _inspection_authority()
		await _wait_input(
			func(): return overlay.hover_card().get("unit") == target, "point at " + target.name
		)
		_check(_inspection_authority() == before, "Native inspection changed paused gameplay")
		var card = overlay.hover_card()
		if card.is_empty():
			continue
		_check(overlay.get_viewport_rect().encloses(card.rect), "Resource card outside viewport")
		for key in ["UnitMenus", "Minimap", "Resources"]:
			var control = game.find_child(key)
			_check(
				(
					not control.is_visible_in_tree()
					or not card.rect.intersects(control.get_global_rect())
				),
				"Resource card overlaps " + key
			)
		print("NATIVE RESOURCE CARD ", card.lines)
		await _capture(
			(
				"materials"
				if target == materials[0]
				else ("electronics" if target == electronics[0] else "wreck")
			)
		)
		await _wait_input(func(): return overlay.hover_card().is_empty(), "move pointer to HUD")
	# A new scout is a declared extension for actual raised-aircraft pointer input.
	var drone = load("res://source/match/units/Drone.tscn").instantiate()
	game._setup_and_spawn_unit(
		drone, Transform3D(Basis(), lab.position + Vector3(4, 3, 4)), human, true
	)
	await _frames(10)
	camera.set_position_safely(drone.global_position)
	print(
		"AIRCRAFT TARGET physical=",
		(
			root.get_final_transform()
			* camera.unproject_position(drone.global_position + Vector3.UP * .3)
		)
	)
	await _wait_input(
		func(): return overlay.hover_card().get("unit") == drone, "point at raised aircraft"
	)
	_check(
		"Your forces" in "\n".join(overlay.hover_card().get("lines", [])),
		"Native aircraft caption missing"
	)
	await _capture("aircraft")


func _inspection_authority():
	var state = [paused, game.simulation_time, human.resource_a, human.resource_b]
	for unit in human.get_children():
		if unit.is_in_group("units") and not unit.is_queued_for_deletion():
			state.append([unit, unit.position, unit.hp, unit.action])
			if unit.manual_orders != null:
				state.append(unit.manual_orders.pending.duplicate(true))
	for node in get_nodes_in_group("resource_units"):
		state.append(
			[node, node.get("resource_a"), node.get("resource_b"), node.get("salvage_left")]
		)
	return state


func _cluster():
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(25)
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _frames(400)
	var center = lab.global_position_yless + Vector3(5, 0, 6)
	var original = get_nodes_in_group("salvage_wrecks").size()
	for index in range(3):
		var victim = load("res://source/match/units/Tank.tscn").instantiate()
		game._setup_and_spawn_unit(
			victim, Transform3D(Basis(), center + Vector3(index * .85, 0, 0)), human, true
		)
		await _frames(3)
		victim.hp = 0
	await _frames(10)
	_check(
		get_nodes_in_group("salvage_wrecks").size() == original + 3, "Cluster deaths lost wrecks"
	)
	camera.set_position_safely(center)
	await _capture("cluster")
