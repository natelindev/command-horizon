extends "res://tests/headless/AmbientLifeRegression.gd"

var CombatRules
var Manual


func _run():
	CombatRules = load("res://source/match/combat/CombatRules.gd")
	Manual = load("res://source/match/orders/ManualOrders.gd")
	path = "user://neutral-world-%d.json" % OS.get_process_id()
	root.get_node("SaveManager").autosaves_enabled = false
	await _create("IndustrialCrossroads")
	game.settings.visibility = game.settings.Visibility.FULL
	await _active_target_archive()
	await _interaction()
	await _close()
	await _create("CoastalFoundry")
	await _coastal_deaths()
	await _close()
	for message in errors:
		push_error(message)
	print("Neutral world: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _create(map_name):
	await super(map_name)
	for side in get_nodes_in_group("players"):
		for role in ["Tank", "CombatRobot"]:
			var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
			game._setup_and_spawn_unit(unit, Transform3D(Basis(), Vector3(4, 0, 4)), side, false)
	await _frames(5)
	_freeze_units()


func _spawn_infantry(player, point):
	var unit = load("res://source/match/units/Infantry.tscn").instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit


func _active_target_archive():
	var tank = _units(game._get_human_player(), "Tank")[0]
	var actor = game.map.get_node("AmbientLife").actors[0]
	tank.position = actor.position + Vector3(0, 0, 3)
	tank.process_mode = Node.PROCESS_MODE_INHERIT
	tank.manual_orders.submit(Manual.target_order("attack", actor))
	await _frames(5)
	paused = true
	var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = snapshot.capture(game)
	var tank_id = snapshot._reference(tank)
	var target_id = snapshot._reference(actor)
	var loader = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await loader.restore(self, data)
	_check(result.ok, "Live neutral attack archive failed: " + result.get("error", ""))
	if result.ok:
		game = result.game
		tank = loader.entities[tank_id]
		actor = loader.entities[target_id]
		_check(tank.action._target_unit == actor, "Restored attack lost neutral target identity")
		var previous_hp = actor.hp
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		paused = false
		await _frames(150)
		_check(
			actor.hp < previous_hp, "Restored projectile/attack failed to resume against neutral"
		)
		_freeze_units()
		tank.action = null
		tank.manual_orders.cancel()
	paused = false


func _interaction():
	var player = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != player)[0]
	var tank = _units(player, "Tank")[0]
	var life = game.map.get_node("AmbientLife")
	var world = game.get_node("NeutralWorld")
	_check(world.buildings.size() == 6, "Industrial buildings were not made interactive")
	var building = world.buildings[0]
	var car = life.actors.filter(func(actor): return actor.entry.kind == "car")[0]
	tank.position = car.position + Vector3(0, 0, 3)
	game.battlefield.invalidate()
	_check(CombatRules.can_target(tank, car), "Car cannot be explicitly attacked")
	_check(
		not game.battlefield.fireable_targets(tank).has(car),
		"Army automatically attacks unowned civilians"
	)
	tank.get_node("Selection").select()
	game.hud.direct_orders.arm("attack")
	_check(
		game.hud.direct_orders.commit(null, car, false),
		"Explicit Attack command rejects neutral car"
	)
	tank.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(90)
	_check(car.hp < car.hp_max, "Actual attack order/projectile failed to damage car")
	_check(car.panic_left > 0, "Hit car did not react")
	tank.action = null
	tank.manual_orders.cancel()
	tank.process_mode = Node.PROCESS_MODE_DISABLED
	# Every authored land actor dies through the normal weapon damage path.
	for actor in life.actors:
		actor._match = game
		var limit = 0
		while actor.hp > 0 and limit < 100:
			actor.receive_weapon_hit(tank)
			limit += 1
		_check(actor.hp == 0 and actor.collision_layer == 0, "Dead neutral remains a target")
		_check(not CombatRules.can_target(tank, actor), "Dead neutral can still be attacked")
	await _frames(75)
	for actor in life.actors:
		_check(actor.death_age > 0 and actor._model.rotation.z != 0, "Missing neutral death motion")
	var before = life.capture()
	paused = true
	await _frames(5)
	_check(life.capture() == before, "Pause advanced neutral death animation")
	paused = false
	# Contextual right-click enters; enemy occupants and over-capacity are rejected.
	var troops = []
	for index in 9:
		var soldier = _spawn_infantry(
			player, building.global_position + Vector3(building.radius + 2 + index, 0, 0)
		)
		troops.append(soldier)
	await _frames(20)
	for soldier in troops:
		player.get_node("UnitActionsController")._navigate_unit_towards_unit(soldier, building)
	await _frames(1250)
	_check(building.occupants.size() == 8, "Eight infantry did not enter/capacity was not enforced")
	_check(building.player == player, "Garrison ownership missing")
	for soldier in building.occupants:
		_check(
			soldier.has_meta("garrison_host") and not soldier.get_node("Geometry").visible,
			"Garrisoned infantry remains outside"
		)
		_check(
			not CombatRules.can_target(_units(enemy, "Tank")[0], soldier),
			"Protected occupant remains individually targetable"
		)
	for soldier in troops:
		if not soldier.has_meta("garrison_host"):
			soldier.position = Vector3(4, 0, 4)
			soldier.process_mode = Node.PROCESS_MODE_DISABLED
	var enemy_soldier = _spawn_infantry(
		enemy, building.global_position + Vector3(building.radius + 2, 0, 0)
	)
	enemy_soldier.process_mode = Node.PROCESS_MODE_DISABLED
	_check(not building.can_garrison(enemy_soldier), "Enemy entered occupied building")
	game.battlefield.invalidate()
	_check(
		game.battlefield.fireable_targets(enemy_soldier).has(building),
		"Occupied hostile building is not auto-acquired"
	)
	var hostile_tank = _units(enemy, "Tank")[0]
	hostile_tank.position = building.global_position + Vector3(12, 0, 0)
	hostile_tank.issue_manual_order(
		load("res://source/match/units/actions/WaitingForTargets.gd").new()
	)
	hostile_tank.process_mode = Node.PROCESS_MODE_INHERIT
	var building_hp = building.hp
	var old_hp = enemy_soldier.hp
	await _frames(90)
	_check(
		not is_instance_valid(enemy_soldier) or enemy_soldier.hp < old_hp,
		"Garrison cannot shoot through its own firing ports"
	)
	_check(building.hp < building_hp, "Enemy army did not fire at occupied building")
	hostile_tank.process_mode = Node.PROCESS_MODE_DISABLED
	await _archive_garrison()
	world = game.get_node("NeutralWorld")
	building = world.buildings[0]
	if building.occupants.is_empty():
		return
	var soldier = building.occupants[0]
	soldier.process_mode = Node.PROCESS_MODE_INHERIT
	soldier.manual_orders.submit(
		Manual.point_order("move", building.global_position + Vector3(15, 0, 0))
	)
	var exit_point = soldier.global_position
	await _frames(30)
	_check(
		not soldier.has_meta("garrison_host") and soldier.get_node("Geometry").visible,
		"Move order did not release occupant"
	)
	_check(building.occupants.size() == 7, "Garrison count not updated on exit")
	await _frames(120)
	_check(
		soldier.global_position.distance_to(exit_point) > 2.0,
		"Restored occupant became stuck after its move order released it"
	)
	_check("7 / 8" in building._label.text, "World occupancy indicator did not update on exit")
	var departing = building.occupants[0]
	root.get_node("MatchSignals").deselect_all_units.emit()
	departing.get_node("Selection").select()
	await _frames(8)
	var panel = game.find_child("UnitMenus")._orders_panel
	_check(
		is_instance_valid(panel) and panel._eject.visible, "Garrison Leave building button missing"
	)
	_check(
		is_instance_valid(panel) and "7 / 8" in panel._status.text,
		"Selected shelter occupancy is missing"
	)
	if is_instance_valid(panel):
		panel._eject.pressed.emit()
	_check(
		not departing.has_meta("garrison_host"), "Leave building button did not evacuate infantry"
	)
	var survivors = building.occupants.duplicate()
	var attacker = _units(
		get_nodes_in_group("players").filter(func(side): return side != game._get_human_player())[0],
		"Tank"
	)[0]
	for hit in 100:
		if building.hp <= 0:
			break
		building.receive_weapon_hit(attacker)
	await _frames(75)
	_check(
		building.occupants.is_empty() and building.player == null,
		"Destroyed building retains garrison ownership"
	)
	_check(building._model.scale.y < building._model_scale.y * .2, "Building did not collapse")
	for survivor in survivors:
		_check(
			(
				is_instance_valid(survivor)
				and not survivor.has_meta("garrison_host")
				and survivor.hp < survivor.hp_max
			),
			"Collapse failed to evacuate/damage occupant"
		)
	_check(not building.can_garrison(soldier), "Infantry entered destroyed building")
	await _archive_garrison()


func _archive_garrison():
	paused = true
	var snapshot = load("res://source/match/saves/MatchSnapshot.gd").new()
	var data = snapshot.capture(game)
	_check(data != null, "Neutral snapshot failed: " + snapshot.error)
	if data == null:
		paused = false
		return
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(data), "Neutral snapshot invalid: " + schema.error)
	var malformed = data.duplicate(true)
	# Authored battlefields carry no ambient life.
	if not malformed.ambient.is_empty():
		malformed.ambient[0].combat.hp = -1
		_check(not schema.validate(malformed), "Negative neutral health accepted")
	malformed = data.duplicate(true)
	malformed.neutral_buildings[0].occupants.append("unit-missing")
	_check(not schema.validate(malformed), "Missing garrison occupant accepted")
	malformed = data.duplicate(true)
	if not malformed.neutral_buildings[0].slots.is_empty():
		malformed.neutral_buildings[0].slots[0] = 8
		_check(not schema.validate(malformed), "Invalid garrison firing slot accepted")
	var loader = load("res://source/match/saves/MatchRestore.gd").new()
	var result = await loader.restore(self, data)
	_check(result.ok, "Neutral restore failed: " + result.get("error", ""))
	if result.ok:
		game = result.game
		var after = snapshot.capture(game)
		_check(after.ambient == data.ambient, "Neutral death/health/pose state changed on load")
		_check(
			after.neutral_buildings == data.neutral_buildings, "Garrison/collapse changed on load"
		)
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		for unit in get_nodes_in_group("units"):
			if not unit.has_meta("garrison_host"):
				unit.process_mode = Node.PROCESS_MODE_DISABLED
	paused = false


func _coastal_deaths():
	var tank = _units(game._get_human_player(), "Tank")[0]
	var robot = _units(game._get_human_player(), "CombatRobot")[0]
	for actor in game.map.get_node("AmbientLife").actors:
		var weapon = robot if actor.entry.kind == "gull" else tank
		_check(CombatRules.can_target(weapon, actor), "No valid weapon for coastal actor")
		for hit in 100:
			if actor.hp <= 0:
				break
			actor.receive_weapon_hit(weapon)
	await _frames(90)
	for actor in game.map.get_node("AmbientLife").actors:
		_check(actor.death_age > 0, "Coastal death animation missing")
		if actor.entry.kind in ["tug", "gull"]:
			_check(actor._model.position.y < 0, "Tug/gull did not sink/fall")
	await _archive_garrison()
