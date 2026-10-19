extends "res://tests/headless/SaveRestoreEdges.gd"

var behavior
var manual
var infantry_scene


func _run():
	behavior = load("res://source/match/orders/UnitBehavior.gd")
	manual = load("res://source/match/orders/ManualOrders.gd")
	infantry_scene = load("res://source/match/units/Infantry.tscn")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/BigArena.tscn")
		_quiet_match()
		await _defensive_archive()
		await _displaced_follower()
		game.queue_free()
		await _frames(5)
	await _skirmish("bastion", "res://source/match/maps/IndustrialCrossroads.tscn", false)
	_quiet_match()
	await _garrison_hold_fire()
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Behavior reliability: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _quiet_match():
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		behavior.set_stance(unit, "hold_fire")


func _defensive_archive():
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var tank = _units(human, "Tank")[0]
	var target = _units(enemy, "Tank")[0]
	tank.position = Vector3(38, 0, 40)
	target.position = Vector3(42, 0, 43)
	game.battlefield.invalidate()
	behavior.set_stance(tank, "defensive")
	await _frames(30)
	_check(
		(
			is_instance_valid(tank.action._sub_action)
			and tank.action._sub_action.get_script().resource_path.ends_with("AutoAttacking.gd")
		),
		"Fixture did not engage Defensive combat"
	)
	paused = true
	var builder = Snapshot.new()
	var saved = builder.capture(game)
	_check(saved != null, "Defensive snapshot failed: " + builder.error)
	if saved == null:
		paused = false
		return
	var tank_id = builder._reference(tank)
	var target_id = builder._reference(target)
	var slots = load("res://source/match/saves/SaveSlots.gd").new()
	slots.directory = "user://behavior-reliability-%d" % OS.get_process_id()
	_check(slots.write_slot("quick", saved), "Defensive slot write failed: " + slots.error)
	var loader = Restore.new()
	var loaded = await loader.restore(self, saved)
	_check(loaded.ok, "Defensive restore failed: " + loaded.get("error", ""))
	if loaded.ok:
		game = loaded.game
		tank = loader.entities[tank_id]
		target = loader.entities[target_id]
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		var health = target.hp
		paused = false
		await _frames(100)
		_check(
			not is_instance_valid(target) or target.hp < health, "Restored defense stopped firing"
		)
		behavior.set_stance(tank, "hold_fire")
	paused = false
	for file in DirAccess.get_files_at(slots.directory):
		DirAccess.remove_absolute(slots.directory.path_join(file))
	DirAccess.remove_absolute(slots.directory)


func _displaced_follower():
	var tanks = _units(game._get_human_player(), "Tank")
	var follower = tanks[0]
	var leader = tanks[1]
	behavior.set_stance(leader, "hold_fire")
	leader.position = Vector3(44, 0, 36)
	follower.position = Vector3(40, 0, 36)
	behavior.follow(follower, leader)
	await _frames(240)
	_check(follower.action._sub_action == null, "Follower did not settle beside leader")
	follower.position += Vector3(0, 0, -8)
	follower.reset_physics_interpolation()
	await _frames(300)
	_check(
		follower.position.distance_to(leader.position) < 3.0,
		"Displaced follower ignored its stationary leader"
	)
	_check(behavior.current(follower) == "follow", "Recovery lost Follow order")
	behavior.set_stance(follower, "hold_fire")


func _garrison_hold_fire():
	for unit in get_nodes_in_group("units"):
		if unit.movement_speed > 0:
			unit.position = (
				Vector3(4, 0, 4) if unit.player == game._get_human_player() else Vector3(90, 0, 90)
			)
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	game.settings.visibility = game.settings.Visibility.FULL
	var building = game.get_node("NeutralWorld").buildings.filter(func(b): return b.habitable)[0]
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var soldier = infantry_scene.instantiate()
	game._setup_and_spawn_unit(
		soldier,
		Transform3D(Basis(), building.global_position + Vector3(building.radius + .8, 0, 0)),
		human,
		false
	)
	behavior.set_stance(soldier, "hold_fire")
	soldier.manual_orders.submit(manual.target_order("garrison", building))
	await _frames(90)
	_check(soldier.has_meta("garrison_host"), "Hold Fire infantry did not enter building")
	var target = infantry_scene.instantiate()
	game._setup_and_spawn_unit(
		target,
		Transform3D(Basis(), building.global_position + Vector3(building.radius + 2.5, 0, 0)),
		enemy,
		false
	)
	target.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	var health = target.hp
	await _frames(90)
	_check(target.hp == health, "Garrison acquired a target despite Hold Fire")
	_check(
		soldier.manual_orders.submit(manual.target_order("attack", target)),
		"Explicit garrison shot rejected"
	)
	await _frames(60)
	_check(not is_instance_valid(target) or target.hp < health, "Hold Fire blocked explicit attack")
	_check(soldier.has_meta("garrison_host"), "Explicit attack evacuated the building")
