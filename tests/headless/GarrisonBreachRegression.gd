extends "res://tests/headless/NeutralWorldRegression.gd"


func _run():
	CombatRules = load("res://source/match/combat/CombatRules.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	Manual = load("res://source/match/orders/ManualOrders.gd")
	await _create("IndustrialCrossroads")
	game.settings.visibility = game.settings.Visibility.FULL
	game.grenade_system.set_physics_process(false)
	var building = game.get_node("NeutralWorld").buildings.filter(func(item): return item.habitable)[0]
	_short_throw_terrain()
	await _restrictions_and_ai(building)
	await _breach(building)
	await _blocked_exit(building)
	await _close()
	for error in errors:
		push_error(error)
	print("Garrison breach: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _short_throw_terrain():
	var abilities = load("res://source/match/units/traits/UnitAbilities.gd").new()
	var terrain = load("res://source/match/maps/terrain/TerrainModel.gd")
	var layout = {"size": Vector2(4, 4)}
	var origin = Vector3(1.0, 0.8, 2.0)
	var destination = Vector3(2.1, 0.8, 2.0)
	_check(
		abilities._throw_terrain_clear(terrain.new(layout), origin, destination),
		"Open short throw was blocked"
	)
	var wall = PackedVector2Array([Vector2(1.5, 1), Vector2(2, 1), Vector2(2, 3), Vector2(1.5, 3)])
	layout.blockers = [{"polygon": wall, "height": 2.0}]
	_check(
		not abilities._throw_terrain_clear(terrain.new(layout), origin, destination),
		"Short grenade throw passed through solid terrain"
	)
	layout.erase("blockers")
	layout.tiers = [{"polygon": wall, "height": 2.0}]
	_check(
		not abilities._throw_terrain_clear(terrain.new(layout), origin, destination),
		"Short grenade throw passed through raised ground"
	)
	abilities.free()


func _restrictions_and_ai(building):
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var thrower = _thrower(building, enemy)
	_check(thrower != null, "No clear AI throw fixture")
	if thrower == null:
		return
	var occupant = _soldier(human, thrower.global_position + Vector3(0, 0, 0.5), 22.0)
	var exterior = _soldier(human, thrower.global_position + Vector3(0, 0, -0.5))
	var tank = load("res://source/match/units/Tank.tscn").instantiate()
	game._setup_and_spawn_unit(tank, Transform3D(Basis(), thrower.global_position), human, false)
	tank.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	game.battlefield.invalidate()
	var ability = thrower.abilities.get_ability("frag_grenade")
	_check(not ability.accepts_target_point, "Frag still allows ground targeting")
	_check(not ability.trigger(building.global_position, building), "Frag accepted empty building")
	_check(
		not ability.trigger(exterior.global_position, exterior), "Frag accepted exterior infantry"
	)
	_check(not ability.trigger(tank.global_position, tank), "Frag accepted tank")
	_check(not ability.trigger(building.global_position), "Frag accepted ground point")
	_check(
		not game.grenade_system.launch(thrower, exterior.global_position, 3.5),
		"Direct launch bypassed garrison restriction"
	)
	_check(
		ability.is_ready() and game.grenade_system.pending.is_empty(),
		"Rejected cast consumed cooldown"
	)
	var tactics = load("res://source/match/players/skirmish-ai/SkirmishTactics.gd")
	tactics._use_grenades(game, enemy, [thrower], [occupant, exterior, tank])
	_check(game.grenade_system.pending.is_empty(), "AI threw at open-ground cluster")
	_check(building.enter(occupant), "AI fixture garrison rejected")
	var teams = [human.team, enemy.team]
	human.team = 7
	enemy.team = 7
	_check(not ability.trigger(building.global_position, building), "Frag accepted allied garrison")
	human.team = teams[0]
	enemy.team = teams[1]
	var position_before = thrower.global_position
	thrower.global_position += Vector3(30, 0, 0)
	_check(not ability.trigger(building.global_position, building), "Frag exceeded throw range")
	thrower.global_position = position_before
	game.battlefield.invalidate()
	tactics._use_grenades(game, enemy, [thrower], [])
	_check(game.grenade_system.pending.size() == 1, "AI did not throw at hostile garrison")
	_check(not ability.is_ready(), "AI throw bypassed cooldown")
	var hull = building.hp
	var tank_hp = tank.hp
	game.grenade_system._physics_process(0.6)
	_check(occupant.hp == 7.0, "AI frag did not use reduced 15 damage")
	_check(not occupant.has_meta("garrison_host"), "AI frag did not evacuate survivor")
	_check(
		building.hp == hull and tank.hp == tank_hp and exterior.hp == 100,
		"AI frag caused exterior damage"
	)
	# A committed throw cannot damage soldiers who leave before impact.
	occupant.regarrison_lock_left = 0.0
	_check(building.enter(occupant), "Vacated-building fixture garrison rejected")
	thrower.abilities.restore({})
	_check(ability.trigger(building.global_position, building), "Vacated-building throw rejected")
	building.leave(occupant)
	game.grenade_system._physics_process(0.6)
	_check(
		occupant.hp == 7.0 and building.hp == hull, "Frag damaged an evacuated building or troop"
	)
	# Current-version archives can contain old ground throws; those are harmless.
	_check(building.enter(occupant), "Legacy throw fixture garrison rejected")
	thrower.abilities.restore({})
	_check(ability.trigger(building.global_position, building), "Legacy fixture throw rejected")
	var entities = {"player": enemy, "thrower": thrower, "building": building}
	var reference = func(node):
		for key in entities:
			if entities[key] == node:
				return key
		return ""
	var saved = game.grenade_system.capture(reference)
	saved.pending[0].building = ""
	game.grenade_system.restore(saved, entities)
	game.grenade_system._physics_process(0.6)
	_check(
		occupant.hp == 7.0 and exterior.hp == 100 and tank.hp == tank_hp,
		"Old ground throw caused damage"
	)
	building.leave(occupant)
	for unit in [thrower, occupant, exterior, tank]:
		unit.queue_free()
	await _frames(4)


func _soldier(player, point, health = 100.0):
	var unit = _spawn_infantry(player, point)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	unit.hp_max = health
	unit.hp = health
	return unit


func _thrower(building, player):
	for index in 32:
		var angle = index * TAU / 32.0
		var point = (
			building.global_position + Vector3(cos(angle), 0, sin(angle)) * (building.radius + 2.0)
		)
		var soldier = _soldier(player, point)
		var landing = (
			building.global_position + Vector3(cos(angle), 0, sin(angle)) * building.radius
		)
		if soldier.abilities._throw_clear(landing, building):
			return soldier
		soldier.queue_free()
	return null


func _breach(building):
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var thrower = _thrower(building, human)
	_check(thrower != null, "No unobstructed throw fixture")
	if thrower == null:
		return
	var troops = []
	for index in 8:
		var soldier = _soldier(
			enemy, building.global_position + Vector3(building.radius + 1.5, 0, index * 0.1)
		)
		troops.append(soldier)
	await _frames(20)
	for soldier in troops:
		_check(building.enter(soldier), "Breach fixture failed to garrison")
	troops[0].hp = 10.0
	troops[1].shields_max = 20.0
	troops[1].shields = 20.0
	var exterior = _soldier(enemy, thrower.global_position + Vector3(0, 0, 0.5))
	var ally = _soldier(human, thrower.global_position + Vector3(0, 0, -0.5))
	await _frames(3)
	game.battlefield.invalidate()
	var ability = thrower.abilities.get_ability("frag_grenade")
	_check(ability.trigger(building.global_position, building), "Valid hostile garrison rejected")
	_check(troops[0].hp == 10 and troops[2].hp == 100, "Grenade damaged occupants before arrival")
	game.grenade_system._physics_process(0.59)
	_check(troops[2].hp == 100, "Grenade fuse fired early")
	var entities = {"p0": human, "p1": enemy, "building": building}
	var reference = func(node):
		for key in entities:
			if entities[key] == node:
				return key
		return ""
	var flying = game.grenade_system.capture(reference)
	thrower.queue_free()
	await _frames(2)
	game.grenade_system.restore(flying, entities)
	game.grenade_system._physics_process(0.01)
	_check(building.player == enemy, "Breach changed building ownership")
	_check(
		troops[1].hp == 100 and troops[1].shields == 5.0, "Breach ignored shields or wrong damage"
	)
	_check(troops[2].hp == 85, "Breach did not deal 15 exactly once")
	_check(exterior.hp == 100 and ally.hp == 100, "Garrison grenade damaged exterior troops")
	_check(troops[2].suppression.meter == 0.0, "Breach added suppression")
	_check(building.pending_evacuations.is_empty(), "Open exits remained pending")
	for index in range(1, troops.size()):
		var soldier = troops[index]
		_check(not soldier.has_meta("garrison_host"), "Surviving occupant was not ejected")
		_check(
			soldier.regarrison_lock_left == 3.0 and not building.can_garrison(soldier),
			"Missing per-unit re-entry lock"
		)
		_check(soldier.abilities.unit_available(), "Eviction blocked abilities")
		_check(soldier.get_node("Movement").is_physics_processing(), "Eviction blocked movement")
		_check(CombatRules.can_target(soldier, ally), "Eviction blocked firing")
		for other in troops.slice(index + 1):
			_check(
				(
					soldier.global_position.distance_to(other.global_position)
					>= soldier.radius + other.radius
				),
				"Ejected positions overlap"
			)
		soldier._physics_process(3.0)
		_check(building.can_garrison(soldier), "Re-entry lock failed to expire")
	for unit in troops + [exterior, ally]:
		if is_instance_valid(unit):
			unit.queue_free()
	await _frames(5)


func _blocked_exit(building):
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var soldier = _spawn_infantry(
		enemy, building.global_position + Vector3(building.radius + 1.5, 0, 0)
	)
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(10)
	_check(
		soldier.manual_orders.submit(Manual.target_order("garrison", building), false, false),
		"Blocked-exit fixture garrison order failed"
	)
	_check(building.enter(soldier), "Blocked-exit fixture enter failed")
	var retreat = building.global_position + Vector3(building.radius + 6.0, 0, 0)
	_check(
		soldier.manual_orders.submit(Manual.point_order("move", retreat), true, false),
		"Blocked-exit fixture queued retreat failed"
	)
	var blockers = []
	for index in 16:
		var angle = index * TAU / 16.0
		var point = (
			building.global_position + Vector3(cos(angle), 0, sin(angle)) * (building.radius + 2.0)
		)
		var blocker = load("res://source/match/units/Barracks.tscn").instantiate()
		game._setup_and_spawn_unit(blocker, Transform3D(Basis(), point), human, false)
		blocker.process_mode = Node.PROCESS_MODE_DISABLED
		blockers.append(blocker)
	await _frames(20)
	game.battlefield.invalidate()
	building.evacuate_breached([soldier])
	_check(
		soldier.has_meta("breach_pending") and soldier.has_meta("garrison_host"),
		"Blocked survivor teleported out"
	)
	_check(soldier.regarrison_lock_left == 0.0, "Re-entry lock began before physical exit")
	soldier.manual_orders._physics_process(.1)
	_check(
		(
			soldier.manual_orders.pending.size() == 1
			and not soldier.get_node("Movement")._has_destination
			and (
				soldier.action == null or soldier.action.process_mode == Node.PROCESS_MODE_DISABLED
			)
		),
		"Blocked evacuation started or discarded its later move order"
	)
	_check(not CombatRules.can_target(soldier, blockers[0]), "Pending evacuee can fire")
	var saved = building.capture(func(node): return "troop" if node == soldier else "")
	_check(saved.evacuating == ["troop"], "Pending evacuation was not captured")
	paused = true
	var capture = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = capture.capture(game)
	_check(snapshot != null, "Pending evacuation snapshot failed: " + capture.error)
	if snapshot != null:
		var building_id = capture._reference(building)
		var soldier_id = capture._reference(soldier)
		var blocker_ids = blockers.map(func(unit): return capture._reference(unit))
		var entry = soldier.get_meta("garrison_entry")
		var loader = load("res://source/match/saves/MatchRestore.gd").new()
		var result = await loader.restore(self, snapshot)
		_check(result.ok, "Pending evacuation restore failed: " + result.get("error", ""))
		if result.ok:
			game = result.game
			building = loader.entities[building_id]
			soldier = loader.entities[soldier_id]
			blockers = blocker_ids.map(func(id): return loader.entities[id])
			enemy = soldier.player
			for side in get_nodes_in_group("players"):
				side.set_process(false)
			for unit in get_nodes_in_group("units"):
				unit.process_mode = Node.PROCESS_MODE_DISABLED
			_check(
				soldier in building.pending_evacuations and soldier.has_meta("breach_pending"),
				"Restored blocked survivor lost pending exit"
			)
			_check(
				soldier.regarrison_lock_left == 0.0 and soldier.get_meta("garrison_entry") == entry,
				"Restored exit changed its timer or navigation anchor"
			)
	paused = false
	for blocker in blockers:
		blocker.queue_free()
	await _frames(50)
	game.battlefield.invalidate()
	building._retry_evacuations()
	_check(
		not soldier.has_meta("garrison_host") and soldier.regarrison_lock_left == 3.0,
		"Clearance did not release pending survivor"
	)
	soldier.manual_orders._physics_process(.1)
	_check(
		(
			soldier.manual_orders.current.get("kind") == "move"
			and is_instance_valid(soldier.action)
			and soldier.action._target_position == retreat
			and soldier.get_node("Movement")._has_destination
		),
		"Queued retreat did not start from the restored physical exit"
	)
	var other = _soldier(enemy, soldier.global_position + Vector3(1, 0, 0))
	_check(building.can_garrison(other), "Breach closed building to other troops")
	soldier.queue_free()
	other.queue_free()
	await _frames(4)
