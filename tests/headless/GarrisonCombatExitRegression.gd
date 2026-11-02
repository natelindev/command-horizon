extends "res://tests/headless/NeutralWorldRegression.gd"


func _run():
	Manual = load("res://source/match/orders/ManualOrders.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://garrison-combat-exit-%d.json" % OS.get_process_id()
	var maps = ["battlefields/EmberworksMap", "IndustrialCrossroads", "CoastalFoundry"]
	var selected = maps.filter(func(map_name): return map_name in OS.get_cmdline_user_args())
	var checked_maps = 0
	for map_name in maps:
		if not selected.is_empty() and map_name not in selected:
			continue
		await _create(map_name)
		checked_maps += 1
		game.settings.visibility = game.settings.Visibility.FULL
		for building in game.get_node("NeutralWorld").buildings:
			if building.habitable:
				await _exercise(building)
		await _restored_shot_and_exit()
		await _close()
	_check(checked_maps > 0, "Garrison combat fixture did not exercise a map")
	for message in errors:
		push_error(message)
	print("Garrison combat and exits: %d maps, %d failures" % [checked_maps, errors.size()])
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _exercise(building):
	var previous_errors = errors.size()
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var troops = []
	for index in 8:
		var soldier = _spawn_infantry(
			human, building.global_position + Vector3(building.radius + .9 + index * .7, 0, 0)
		)
		troops.append(soldier)
	await _frames(20)
	if "--native-crowd-runtime" in OS.get_cmdline_user_args():
		_check(
			troops.all(func(soldier): return soldier.get_node("Movement")._native_handle >= 0),
			"Garrison movement did not bind the requested native runtime"
		)
	# Establish ownership before the other seven approach. Their avoidance
	# can otherwise push the capturer outside range and restart its channel;
	# this fixture tests eight firing slots and exits, not contested capture.
	troops[0].manual_orders.submit(Manual.target_order("garrison", building))
	await _wait_for_garrison(building, 1)
	_check(troops[0] in building.occupants, building._asset + ": initial capture failed")
	for index in range(1, troops.size()):
		troops[index].manual_orders.submit(Manual.target_order("garrison", building))
	await _wait_for_garrison(building, 8)
	_check(building.occupants.size() == 8, building._asset + ": failed to fill shelter")
	var target = _spawn_infantry(
		enemy, building.global_position + Vector3(building.radius + 2.5, 0, 0)
	)
	target.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	var hp = target.hp
	_check(
		troops[0].manual_orders.submit(Manual.target_order("attack", target)),
		"Garrison rejected a legal direct shot"
	)
	_check(
		troops[0].has_meta("garrison_host") and building.occupants.size() == 8,
		"Attack order evacuated infantry"
	)
	await _frames(90)
	_check(
		not is_instance_valid(target) or target.hp < hp,
		building._asset + ": occupants did not fire"
	)
	if is_instance_valid(target):
		target.queue_free()
	# Exercise all firing slots and verify travel, not just removal of metadata.
	var starts = []
	var destinations = []
	for index in troops.size():
		var soldier = troops[index]
		soldier.manual_orders.cancel()
		soldier.action = null
		starts.append(soldier.global_position)
		var direction = (
			(soldier.global_position_yless - building.global_position_yless).normalized()
		)
		var destination = (
			NavigationServer3D.map_get_closest_point(
				soldier.get_node("Movement").get_navigation_map(),
				soldier.global_position_yless + direction * 5.0
			)
			* Vector3(1, 0, 1)
		)
		if destination.distance_to(soldier.global_position_yless) < 3.0:
			destination = (
				soldier.global_position_yless + direction.rotated(Vector3.UP, PI / 2) * 4.0
			)
		destinations.append(destination)
		soldier.manual_orders.submit(Manual.point_order("move", destination))
	await _frames(150)
	for index in troops.size():
		var soldier = troops[index]
		_check(not soldier.has_meta("garrison_host"), "Unloading retained occupant metadata")
		_check(
			soldier.global_position.distance_to(starts[index]) > 2.0,
			(
				"%s slot %d stuck after unloading: %s -> %s (goal %s)"
				% [
					building._asset,
					index,
					starts[index],
					soldier.global_position,
					destinations[index]
				]
			)
		)
		soldier.queue_free()
	await _frames(5)
	print(
		"Garrison ",
		game.settings.map_path.get_file(),
		" / ",
		building._asset,
		": ",
		errors.size() - previous_errors,
		" failures"
	)


func _restored_shot_and_exit():
	var buildings = game.get_node("NeutralWorld").buildings.filter(
		func(item): return item.habitable
	)
	var building = buildings[0]
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var soldier = _spawn_infantry(
		human, building.global_position + Vector3(building.radius + .8, 0, 0)
	)
	soldier.manual_orders.submit(Manual.target_order("garrison", building))
	await _wait_for_garrison(building, 1)
	var target = _units(enemy, "Tank")[0]
	target.position = building.global_position + Vector3(building.radius + 3, 0, 0)
	game.battlefield.invalidate()
	_check(
		soldier.manual_orders.submit(Manual.target_order("attack", target)),
		"Direct firing fixture rejected target"
	)
	target.position += Vector3(30, 0, 0)
	game.battlefield.invalidate()
	_check(
		not soldier.manual_orders.submit(Manual.target_order("attack", target)),
		"Shelter accepted an out-of-range shot"
	)
	_check(soldier.has_meta("garrison_host"), "Out-of-range attack evacuated the shelter")
	target.position -= Vector3(30, 0, 0)
	game.battlefield.invalidate()
	soldier.manual_orders.submit(Manual.target_order("attack", target))
	await _archive_garrison()
	building = game.get_node("NeutralWorld").buildings.filter(func(item): return item.habitable)[0]
	_check(building.occupants.size() == 1, "Direct firing save lost occupant")
	if building.occupants.is_empty():
		return
	soldier = building.occupants[0]
	human = game._get_human_player()
	enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	target = _units(enemy, "Tank")[0]
	var durability = Vector2(target.hp, target.shields)
	await _frames(90)
	print(
		"Garrison restored fire ",
		game.settings.map_path.get_file(),
		" hull=",
		durability.x,
		"->",
		target.hp,
		" shields=",
		durability.y,
		"->",
		target.shields
	)
	_check(
		target.hp + target.shields < durability.x + durability.y,
		"Saved direct shot did not resume from inside shelter"
	)
	soldier.manual_orders.submit(
		Manual.point_order("move", building.global_position + Vector3(building.radius + 7, 0, 0))
	)
	await _frames(150)
	_check(
		(
			not soldier.has_meta("garrison_host")
			and (
				soldier.global_position_yless.distance_to(building.global_position_yless)
				> building.radius + 3
			)
		),
		"Saved direct shooter stuck after unloading"
	)


func _wait_for_garrison(building, count):
	# Neutral/enemy ownership already requires a 15 s capture channel. Wait for
	# that contract plus bounded approach time before testing firing and exits.
	var duration = load("res://source/match/units/actions/Garrisoning.gd").CAPTURE_DURATION
	for tick in ceili((duration + 5.0) * Engine.physics_ticks_per_second):
		if building.occupants.size() == count:
			return
		await physics_frame
