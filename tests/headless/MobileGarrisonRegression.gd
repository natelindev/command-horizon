extends "res://tests/headless/CampaignRegression.gd"

var _manual
var _rig
var _passengers = []
var _target
var _snapshot_script
var _restore_script


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_manual = load("res://source/match/orders/ManualOrders.gd")
	_snapshot_script = load("res://source/match/saves/MatchSnapshot.gd")
	_restore_script = load("res://source/match/saves/MatchRestore.gd")
	await _make_match()
	await _embark_and_fire()
	await _archive()
	await _blocked_unload_archive()
	await _unload_and_destroy()
	paused = false
	game.queue_free()
	await _frames(5)
	for message in errors:
		push_error(message)
	print("Mobile garrison: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _make_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/PlainAndSimple.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "frontier" if index == 0 else "bastion"
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game
	await _frames(45)
	game.settings.visibility = game.settings.Visibility.FULL
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED


func _spawn(role, side, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), side, false)
	return unit


func _embark_and_fire():
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	_rig = _spawn("AdvancedTank", human, Vector3(24, 0, 25))
	_rig.stance = _rig.Stance.HOLD_FIRE
	_target = _spawn("Tank", enemy, Vector3(26, 0, 31))
	_target.process_mode = Node.PROCESS_MODE_DISABLED
	for index in 5:
		var infantry = _spawn(
			"RocketInfantry" if index == 0 else "Infantry",
			human,
			_rig.global_position + Vector3(2.0 + index * 0.25, 0, 0)
		)
		_passengers.append(infantry)
		if index > 0:
			infantry.stance = infantry.Stance.HOLD_FIRE
	await _frames(5)
	_check(_rig.garrison_mount != null, "Frontier advanced vehicle has no garrison trait")
	if "--native-unit-state" in OS.get_cmdline_user_args():
		_check(
			_rig._native_state != null and _passengers[0]._native_state != null,
			"Native garrison run silently used script unit state"
		)
	if "--native-crowd-runtime" in OS.get_cmdline_user_args():
		_check(
			_rig.get_node("Movement")._native_runtime != null,
			"Native garrison run silently used script movement"
		)
	_check(not _target.can_garrison(_passengers[0]), "Other factions gained mobile garrisons")
	_check(not _rig.can_garrison(_target), "Vehicle accepted enemy armor as a passenger")
	var distant = _spawn("Infantry", human, Vector3(12, 0, 25))
	_check(not _rig.enter(distant), "Carrier embarked remote infantry without an approach")
	distant.queue_free()
	for infantry in _passengers:
		infantry.manual_orders.submit(_manual.target_order("garrison", _rig))
	await _frames(120)
	_check(_rig.occupants.size() == 4, "Rig did not embark exactly four infantry")
	_check(not _passengers[4].has_meta("garrison_host"), "Rig overfilled its firing mounts")
	_passengers[4].queue_free()
	_passengers.resize(4)
	var rocket = _passengers[0]
	for infantry in _rig.occupants:
		_check(not infantry.visible, "Embarked infantry remained visible")
		_check(
			not infantry.get_node("Geometry").is_visible_in_tree(), "Embarked model still renders"
		)
	var visibility = game.get_node("Handlers/UnitVisibilityHandler")
	visibility._update_unit_visibility(rocket, true)
	_check(not rocket.visible, "Visibility handler revealed mounted infantry")
	_check(rocket.is_revealing(), "Hidden mounted infantry lost carrier-context vision")
	_check(
		game.battlefield.can_observe(rocket, _target),
		"Hidden passenger cannot observe from its rig"
	)
	_check(
		not load("res://source/match/combat/CombatRules.gd").can_target(_target, rocket),
		"Embarked passenger remained an individually targetable body"
	)
	var hp = _target.hp
	_check(
		rocket.manual_orders.submit(_manual.target_order("attack", _target)),
		"Mounted rocket infantry rejected a legal attack"
	)
	var start = _rig.global_position
	_rig.manual_orders.submit(_manual.point_order("move", Vector3(29, 0, 25)))
	await _frames(170)
	_check(_rig.global_position.distance_to(start) > 2.0, "Carrier did not move during firing")
	_check(_target.hp < hp, "Mounted infantry could not fire while carrier moved")
	_check(
		(
			rocket.has_meta("garrison_host")
			and rocket.global_position.distance_to(_rig.global_position) < 3.0
		),
		"Passenger did not follow its moving carrier"
	)


func _archive():
	paused = true
	var snapshot = _snapshot_script.new()
	var data = snapshot.capture(game)
	_check(data != null, "Mounted capture failed: " + snapshot.error)
	if data == null:
		return
	var rig_id = snapshot._reference(_rig)
	var target_id = snapshot._reference(_target)
	var passenger_ids = _passengers.map(func(unit): return snapshot._reference(unit))
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(data), "Mounted schema rejected valid state: " + schema.error)
	var corrupt = data.duplicate(true)
	var bad_rig = corrupt.units.filter(func(unit): return unit.id == rig_id)[0]
	bad_rig.garrison_mount.slots[1] = bad_rig.garrison_mount.slots[0]
	_check(not schema.validate(corrupt), "Snapshot accepted duplicate firing mount slots")
	corrupt = data.duplicate(true)
	bad_rig = corrupt.units.filter(func(unit): return unit.id == rig_id)[0]
	bad_rig.garrison_mount.occupants[1] = target_id
	_check(not schema.validate(corrupt), "Snapshot accepted an enemy vehicle passenger")
	corrupt = data.duplicate(true)
	var bad_passenger = corrupt.units.filter(func(unit): return unit.id == passenger_ids[0])[0]
	bad_passenger.action.state._capture_elapsed = 1.0
	_check(not schema.validate(corrupt), "Snapshot accepted capture progress on a friendly carrier")
	var loader = _restore_script.new()
	var result = await loader.restore(self, data)
	_check(result.ok, "Mounted restore failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	_rig = loader.entities[rig_id]
	_target = loader.entities[target_id]
	_passengers = passenger_ids.map(func(id): return loader.entities[id])
	_check(_rig.occupants.size() == 4, "Restore lost mounted passengers")
	var again = snapshot.capture(game)
	var saved_rig = data.units.filter(func(unit): return unit.id == rig_id)[0]
	var restored_rig = again.units.filter(func(unit): return unit.id == rig_id)[0]
	_check(restored_rig.garrison_mount == saved_rig.garrison_mount, "Restore changed mount state")
	for infantry in _passengers:
		_check(
			(
				infantry.has_meta("garrison_host")
				and infantry.get_meta("garrison_host") == _rig
				and not infantry.get_node("Movement").is_physics_processing()
			),
			"Restored passenger lost movement ownership"
		)
		_check(not infantry.visible, "Restored mounted infantry became visible")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	_target.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false


func _blocked_unload_archive():
	# A large occupied footprint surrounds all bounded unloading candidates.
	var blockers = [_spawn("CommandCenter", _rig.player, _rig.global_position)]
	for step in 12:
		var angle = step * TAU / 12.0
		blockers.append(
			_spawn(
				"CommandCenter",
				_rig.player,
				_rig.global_position + Vector3(cos(angle), 0, sin(angle)) * 3.8
			)
		)
	await _frames(30)
	var passenger = _passengers[1]
	var destination = _rig.global_position + Vector3(0, 0, -10)
	passenger.manual_orders.submit(_manual.point_order("move", destination))
	await _frames(5)
	_check(
		passenger.has_meta("breach_pending") and passenger in _rig.occupants,
		"Blocked unloading did not retain passenger safely"
	)
	paused = true
	var snapshot = _snapshot_script.new()
	var data = snapshot.capture(game)
	var passenger_id = snapshot._reference(passenger)
	var rig_id = snapshot._reference(_rig)
	var target_id = snapshot._reference(_target)
	var blocker_ids = blockers.map(func(unit): return snapshot._reference(unit))
	var passenger_ids = _passengers.map(func(unit): return snapshot._reference(unit))
	var loader = _restore_script.new()
	var result = await loader.restore(self, data)
	_check(result.ok, "Blocked unload save failed: " + result.get("error", ""))
	if not result.ok:
		paused = false
		for blocker in blockers:
			blocker.queue_free()
		return
	game = result.game
	_rig = loader.entities[rig_id]
	_target = loader.entities[target_id]
	_target.process_mode = Node.PROCESS_MODE_DISABLED
	_passengers = passenger_ids.map(func(id): return loader.entities[id])
	passenger = loader.entities[passenger_id]
	_check(passenger.has_meta("breach_pending"), "Restore lost pending unload")
	_check(not passenger.visible, "Pending unload restored visible infantry inside its carrier")
	for id in blocker_ids:
		loader.entities[id].queue_free()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	paused = false
	# Removal schedules a deferred bake; movement time starts after it finishes.
	await _frames(2)
	await game.navigation.wait_until_synchronized(passenger.movement_domain)
	for frame in 360:
		if (
			not passenger.has_meta("garrison_host")
			and passenger.global_position.distance_to(destination) < 2.0
		):
			break
		await process_frame
	_check(not passenger.has_meta("garrison_host"), "Unblocked passenger did not unload")
	_check(passenger.visible, "Unblocked passenger stayed hidden after unloading")
	_check(
		passenger.global_position.distance_to(destination) < 2.0,
		(
			"Blocked unload lost the queued movement order: %s -> %s (%s)"
			% [passenger.global_position, destination, passenger.manual_orders.status]
		)
	)


func _unload_and_destroy():
	var infantry = _passengers[0]
	var destination = _rig.global_position + Vector3(0, 0, -7)
	var started = Engine.get_physics_frames()
	infantry.manual_orders.submit(_manual.point_order("move", destination))
	# A legal exit may be on the far side of the moving rig. Verify the whole
	# navigation result using simulation time, rather than an assumed number of
	# rendered frames or a distance from a carrier that is still moving.
	for tick in Engine.physics_ticks_per_second * 6:
		if (
			not infantry.has_meta("garrison_host")
			and infantry.global_position.distance_to(destination) < 1.5
		):
			break
		await physics_frame
	print(
		(
			"Unloaded navigation: ticks=%d physics_hz=%d distance=%.3f"
			% [
				Engine.get_physics_frames() - started,
				Engine.physics_ticks_per_second,
				infantry.global_position.distance_to(destination)
			]
		)
	)
	_check(
		infantry.global_position.distance_to(destination) < 1.5,
		"Unloaded passenger failed to reach its movement destination within six seconds"
	)
	_check(not infantry.has_meta("garrison_host"), "Move order did not unload passenger")
	_check(infantry.visible, "Unloaded passenger stayed hidden")
	_check(
		infantry.global_position.distance_to(_rig.global_position) > _rig.radius + 2.0,
		(
			(
				"Unloaded passenger could not resume navigation: unit=%s rig=%s target=%s "
				+ "active=%s status=%s synchronized=%s moving=%s"
			)
			% [
				infantry.global_position,
				_rig.global_position,
				infantry.get_node("Movement").target_position,
				infantry.action,
				infantry.manual_orders.status,
				infantry.get_node("Movement")._synchronized,
				infantry.get_node("Movement")._has_destination
			]
		)
	)
	var survivors = _rig.occupants.duplicate()
	var health = survivors.map(func(unit): return unit.hp)
	_rig.hp = 0
	await _frames(5)
	for index in survivors.size():
		var survivor = survivors[index]
		_check(not survivor.has_meta("garrison_host"), "Destroyed carrier retained passenger")
		_check(survivor.visible, "Wreck survivor stayed hidden")
		_check(
			survivor.hp < health[index] and survivor.hp > 0,
			"Carrier wreck omitted passenger damage"
		)
		_check(survivor.get_node("Movement").is_physics_processing(), "Wreck survivor cannot move")
	var carrier = _spawn("AdvancedTank", game._get_human_player(), Vector3(20, 0, 25))
	var rider = _spawn("Infantry", carrier.player, carrier.global_position + Vector3(2, 0, 0))
	rider.manual_orders.submit(_manual.target_order("garrison", carrier))
	await _frames(60)
	_check(rider.has_meta("garrison_host"), "Removed carrier fixture did not embark")
	_check(not rider.visible, "Removed carrier fixture did not hide its passenger")
	carrier.queue_free()
	await _frames(5)
	_check(not rider.has_meta("garrison_host"), "Removed carrier orphaned passenger")
	_check(rider.visible, "Removed carrier left its passenger hidden")
	_check(
		rider.get_node("Movement").is_physics_processing(), "Removed carrier left passenger frozen"
	)
