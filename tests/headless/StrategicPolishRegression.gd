extends "res://tests/headless/TerrainSightRegression.gd"

var _veteran
var _base_reload = 0.0
var _base_speed = 0.0


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	root.get_node("SaveManager").autosaves_enabled = false
	await _create_match()
	model = game.map.terrain
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_check_smooth_plateau()
	await _check_plateau_bonuses()
	await _check_experience()
	await _check_aircraft_veterancy()
	await _check_veteran_archive()
	await _close()
	for message in _errors:
		push_error(message)
	print("Strategic polish: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _check_smooth_plateau():
	var terrain = load("res://source/match/maps/terrain/TerrainModel.gd").new(
		{
			"size": Vector2(12, 12),
			"tiers":
			[
				{
					"polygon":
					PackedVector2Array(
						[Vector2(4, 4), Vector2(8, 4), Vector2(8, 8), Vector2(4, 8)]
					),
					"height": 3.0,
					"falloff": 3.0
				}
			]
		}
	)
	var navigation = load("res://source/match/TerrainNavigation.gd")
	_check(navigation.plateau_at(terrain, Vector2(6, 6)), "Smooth plateau top lacks bonus")
	_check(
		not navigation.plateau_at(terrain, Vector2(3.5, 6)),
		"Elevated smooth shoulder receives plateau bonus"
	)


func _spawn_frozen(role, side, point):
	var unit = _spawn_unit(role, side, point)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	unit.action = null
	return unit


func _check_plateau_bonuses():
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var tank = _spawn_frozen("Tank", human, Vector3(54, 3, 20))
	var target = _spawn_frozen("Tank", enemy, Vector3(54 + tank.attack_range + .4, 0, 20))
	await _frames(3)
	var rules = load("res://source/match/combat/CombatRules.gd")
	_check(tank.terrain_advantage(), "Walkable plateau lacks high-ground advantage")
	_check(not target.terrain_advantage(), "Low ground receives plateau advantage")
	_check(rules.range_for(tank, target) > tank.attack_range + .39, "Downhill range bonus missing")
	game.battlefield.invalidate()
	_check(
		game.battlefield.can_fire(tank, target),
		"Downhill target inside bonus range cannot be fired upon"
	)
	_check(
		game.battlefield.fireable_targets(tank).has(target),
		"Automatic target scan omits extended range"
	)
	var normal_sight = tank.sight_range
	_check(tank.effective_sight_range() > normal_sight, "Plateau sight range not extended")
	var fog = game.fog_of_war
	if not fog._unit_is_mapped(tank):
		fog._map_unit_to_new_circles(tank)
	fog._outline_deadline = Time.get_ticks_usec() + 1000000
	fog._sync_circles_to_unit(tank)
	for circle in fog._unit_to_circles_mapping[tank]:
		_near(
			circle.radius,
			tank.effective_sight_range() * fog.texture_units_per_world_unit,
			"Fog radius disagrees with gameplay vision"
		)
	target.position = Vector3(51, 3, 23)
	_near(
		rules.range_for(tank, target),
		tank.attack_range,
		"Equal-height target grants downhill range"
	)
	tank.position = Vector3(49, 1.5, 45)
	_check(not tank.terrain_advantage(), "Ramp receives plateau bonus")
	_near(tank.effective_sight_range(), normal_sight, "Leaving plateau retains vision bonus")
	var helicopter = _spawn_frozen("Helicopter", human, Vector3(52, 8, 20))
	_check(not helicopter.terrain_advantage(), "Aircraft altitude grants plateau bonus")
	tank.position = Vector3(54, 3, 20)
	_check(
		rules.high_ground_range_bonus(tank, helicopter) == 0.0, "High ground extends anti-air range"
	)
	var nav = game.navigation.terrain
	_check(
		not nav.has_plateau_advantage(Vector3(115.5, 0, 64.5)),
		"Solid formation grants plateau bonus"
	)
	for unit in [tank, target, helicopter]:
		unit.queue_free()
	await _frames(5)


func _check_experience():
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	_veteran = _spawn_frozen("Tank", human, Vector3(24, 3, 34))
	var victim = _spawn_frozen("Tank", enemy, Vector3(27, 3, 34))
	var ally = _spawn_frozen("Tank", human, Vector3(21, 3, 34))
	_base_reload = _veteran.attack_interval
	_base_speed = _veteran.movement_speed
	var base_damage = _veteran.attack_damage
	var hp = victim.hp_max
	victim.receive_damage(_veteran, hp * .5)
	_near(_veteran.experience, 50.0, "Damage contribution is not normalized to victim HP")
	_check(_veteran.veterancy_rank == 0, "Half a tank grants premature veterancy")
	victim.receive_damage(_veteran, hp * 20)
	_near(_veteran.experience, 125.0, "Overkill produces excess experience")
	_check(_veteran.veterancy_rank == 1, "Surviving attacker did not earn Bronze")
	_check(_veteran.get_node("VeteranBadge").visible, "Promoted unit has no rank chevrons")
	_near(_veteran.attack_interval, _base_reload * .96, "Bronze reload bonus missing")
	_near(_veteran.movement_speed, _base_speed * 1.03, "Bronze movement bonus missing")
	ally.receive_damage(_veteran, ally.hp_max * .1)
	_near(_veteran.experience, 125.0, "Friendly damage grants experience")
	_veteran.experience = 600
	_near(_veteran.attack_interval, _base_reload * .88, "Gold reload bonus incorrect")
	_near(_veteran.movement_speed, _base_speed * 1.09, "Gold movement bonus incorrect")
	for index in 20:
		_near(
			_veteran.attack_interval,
			_base_reload * .88,
			"Repeated property reads compound reload bonus"
		)
	_near(_veteran.attack_damage, base_damage, "Veterancy changes weapon damage/counters")
	_veteran.experience = 99999
	_near(_veteran.experience, 600.0, "Experience is not capped")
	_veteran.experience = 375
	_check(_veteran.veterancy_rank == 2, "Silver rank threshold incorrect")
	_near(_veteran.movement_speed, _base_speed * 1.06, "Rank decrease retains old speed bonus")
	_veteran.experience = 0
	_near(_veteran.attack_interval, _base_reload, "Recruit reset retains reload bonus")
	_near(_veteran.movement_speed, _base_speed, "Recruit reset retains movement bonus")
	_veteran.experience = 375
	var worker = _spawn_frozen("Worker", human, Vector3(18, 3, 34))
	_veteran.Veterancy.award(worker, ally, ally.hp_max, true)
	_near(worker.experience, 0.0, "Unarmed engineer gains combat rank")
	var shot = load("res://source/match/combat/Shot.gd").from(ally, ally.position)
	ally.queue_free()
	await _frames(3)
	_check(shot.shooter() == null, "Destroyed shooter retained by projectile")
	worker.receive_damage(shot.feedback_source(), 1.0)
	_near(worker.experience, 0.0, "Projectile without surviving shooter grants experience")
	worker.queue_free()
	await _frames(3)


func _check_aircraft_veterancy():
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var target = _spawn_frozen("Tank", enemy, Vector3(35, 3, 34))
	for role in ["Fighter", "Bomber"]:
		var aircraft = _spawn_frozen(role, human, Vector3(30, 12, 34))
		var flight = aircraft.get_node("Movement")
		var cruise = flight.cruise_speed
		aircraft.experience = 600
		_near(flight.cruise_speed, cruise * 1.09, role + " lacks veteran cruise speed")
		for store in aircraft.loadout():
			var spec = aircraft.loadout()[store]
			aircraft._release(store, spec, target)
			_near(aircraft._cooldowns[store], spec.interval * .88, role + " lacks veteran reload")
		aircraft.experience = 0
		_near(flight.cruise_speed, cruise, role + " retains speed after rank reset")
		aircraft.queue_free()
	target.queue_free()
	await _frames(3)


func _check_veteran_archive():
	paused = true
	var snapshotter = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = snapshotter.capture(game)
	_check(snapshot != null, "Veteran snapshot failed: " + snapshotter.error)
	if snapshot == null:
		return
	var id = snapshotter._reference(_veteran)
	var schema = load("res://source/match/saves/SnapshotSchema.gd").new()
	_check(schema.validate(snapshot), "Veteran snapshot invalid: " + schema.error)
	var invalid = snapshot.duplicate(true)
	invalid.units.filter(func(unit): return unit.id == id)[0].experience = 601.0
	_check(not schema.validate(invalid), "Out-of-range saved experience accepted")
	var file = load("res://source/match/saves/SaveFile.gd").new()
	var path = "user://veterancy-%d.json" % OS.get_process_id()
	_check(file.write_file(path, snapshot), "Could not write veteran archive")
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var restored = await restore.restore(self, file.read_file(path))
	DirAccess.remove_absolute(path)
	_check(restored.ok, "Veteran restore failed: " + restored.get("error", ""))
	if not restored.ok:
		return
	game = restored.game
	_veteran = restore.entities[id]
	_check(paused, "Restored veteran battle is not paused")
	_near(_veteran.experience, 375.0, "Saved experience changed on load")
	_near(_veteran.attack_interval, _base_reload * .92, "Reload buff changed on load")
	_near(_veteran.movement_speed, _base_speed * 1.06, "Movement buff changed on load")
	_check(_veteran.get_node("VeteranBadge").visible, "Rank chevrons not restored")
