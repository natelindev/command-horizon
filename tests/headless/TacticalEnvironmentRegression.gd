extends "res://tests/headless/TerrainSightRegression.gd"

var rules
var human
var opponent
var controller_script
var orders_script
var obstacle_script


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	constants = root.get_node("Constants")
	rules = load("res://source/match/combat/CombatRules.gd")
	controller_script = load("res://source/match/players/human/UnitActionsController.gd")
	orders_script = load("res://source/match/orders/ManualOrders.gd")
	obstacle_script = load("res://source/match/environment/DestructibleObstacle.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	await _create_match()
	model = game.map.terrain
	human = game._get_human_player()
	opponent = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	for unit in get_nodes_in_group("units"):
		unit.stance = unit.Stance.HOLD_FIRE
	await _check_high_ground()
	await _check_aircraft_visibility()
	await _elevation_bonuses()
	await _breaching()
	await _scavenging()
	await _field_dismantle()
	await _persistence()
	await _close()
	for message in _errors:
		push_error(message)
	print("Tactical environment: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _create_match():
	var settings = _settings("frontier", "helix", false)
	settings.map_path = MAP
	settings.players[1].spawn_index_offset = 0
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(MAP).instantiate()
	var authored = obstacle_script.new()
	authored.name = "AuthoredBarrier"
	authored.position = Vector3(140, 0, 100)
	authored.radius = 2.0
	authored.light_barricade = false
	game.map.add_child(authored)
	root.add_child(game)
	current_scene = game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(90)


func _held(role, side, point):
	var unit = _spawn_unit(role, side, point)
	unit.stance = unit.Stance.HOLD_FIRE
	return unit


func _elevation_bonuses():
	var high = _held("Tank", human, Vector3(54.5, 3, 20))
	var low = _held("Tank", opponent, Vector3(62, 0, 20))
	await _frames(10)
	for unit in [high, low]:
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	high.position = Vector3(54.5, 3, 20)
	low.position = Vector3(62, 0, 20)
	_check(high.terrain_advantage(), "Plateau fixture lacks terrain advantage")
	_near(high.effective_sight_range(), high.sight_range * 1.3, "High ground sight +30%")
	_near(
		high.effective_sight_range(high.position),
		high.sight_range,
		"Level sight gained downhill bonus"
	)
	_near(rules.range_for(high, low), high.attack_range * 1.25, "Downhill attack range +25%")
	_near(rules.range_for(low, high), low.attack_range * 0.8, "Uphill attack range -20%")
	var centre = Vector2(high.position.x, high.position.z)
	var reach = high.effective_sight_range()
	var outline = Sight.reveal_triangles(model, centre, reach, high.sight_range)
	var downhill = centre + Vector2(high.sight_range * 1.15, 0)
	var level = centre - Vector2(high.sight_range * 1.15, 0)
	_check(
		game.battlefield.can_observe_point(high, _eye(downhill.x, downhill.y)),
		"Downhill sight bonus did not reveal distant ground"
	)
	_check(
		not game.battlefield.can_observe_point(high, _eye(level.x, level.y)),
		"Sight bonus revealed distant ground on the same tier"
	)
	_check(_revealed(outline, centre, downhill, reach), "Fog lost downhill sight bonus")
	_check(
		not _revealed(outline, centre, level, reach), "Fog extends sight bonus onto the same tier"
	)
	var damage = rules.damage(high, low)
	var shot = load("res://source/match/combat/Shot.gd").from(high, high.global_position)
	_near(rules.damage_from(shot, low), damage, "Projectile lost downhill damage")
	high.position.y = 0
	_near(damage, rules.damage(high, low) * 1.15, "Downhill damage +15%")
	_near(rules.damage_from(shot, low), damage, "Projectile uses moving shooter's height")
	# A deterministic two-tier fixture exercises the exact contact threshold.
	var terrain = load("res://source/match/maps/terrain/TerrainModel.gd").new(
		{
			"size": Vector2(10, 10),
			"tiers":
			[
				{
					"height": 3.0,
					"polygon":
					PackedVector2Array(
						[Vector2(5, 0), Vector2(10, 0), Vector2(10, 10), Vector2(5, 10)]
					)
				}
			]
		}
	)
	_check(
		not Sight.high_ground_hidden(terrain, Vector2(4.25, 5), Vector2(5.75, 5)),
		"1.5 m close contact hidden"
	)
	_check(
		Sight.high_ground_hidden(terrain, Vector2(4, 5), Vector2(6, 5)),
		"Low ground sees plateau beyond contact"
	)
	for unit in [high, low]:
		unit.queue_free()
	await _frames(4)


func _barrier(point, light = true, size = 2.0):
	var barrier = obstacle_script.new()
	barrier.position = point
	barrier.radius = size
	barrier.light_barricade = light
	game.map.add_child(barrier)
	return barrier


func _navigation_settled():
	for index in 2000:
		if index > 5 and game.navigation.terrain.is_synchronized():
			return
		await process_frame
	_check(false, "Navigation rebake did not synchronize")


func _breaching():
	var barrier = game.map.get_node("AuthoredBarrier")
	await _navigation_settled()
	var navmap = game.navigation.terrain.navigation_map_rid
	var point = barrier.position + Vector3.UP * 0.5
	var blocked = NavigationServer3D.map_get_closest_point(navmap, point)
	_check((blocked - point).length() > 1.0, "Barrier did not block navigation")
	var from = point + Vector3(-5, 0.3, 0)
	var to = point + Vector3(5, 0.3, 0)
	_check(not game.battlefield.line_clear(from, to), "Barrier did not block sight")
	var tank = _held("Tank", human, Vector3(135, 0, 100))
	await _frames(5)
	tank.process_mode = Node.PROCESS_MODE_DISABLED
	_check(not rules.can_target(tank, barrier), "Idle army automatically targets barriers")
	_check(rules.can_force_target(tank, barrier), "Barrier is not a force-attack target")
	var controller = controller_script
	_check(
		controller.context_kind(tank, barrier) == "force_attack",
		"Right-click cannot attack barrier"
	)
	barrier.receive_damage(tank, 30.0)
	_near(barrier.hp, 50.0, "Barrier damage")
	tank.action = load("res://source/match/units/actions/AutoAttacking.gd").new(barrier, true)
	game.projectile_system.launch(tank, barrier)
	await _frames(60)
	_check(barrier.hp < 50.0, "Physical force-attack projectile did not damage barrier")
	_check(not barrier.crush_by(tank), "Tank crushed a concrete obstacle")
	var effects_before = game.combat_effects.deaths_emitted
	barrier.receive_damage(tank, 100.0)
	barrier.receive_damage(tank, 100.0)
	_check(
		game.combat_effects.deaths_emitted == effects_before + 1, "Breach FX emitted more than once"
	)
	_check(
		barrier.hp == 0.0 and barrier.collision_layer == 0, "Destroyed barrier retains collision"
	)
	_check(game.battlefield.line_clear(from, to), "Breached barrier still blocks sight")
	await _navigation_settled()
	var open = NavigationServer3D.map_get_closest_point(navmap, point)
	_check(open.distance_to(point) < 0.2, "Breached choke point did not reopen navigation")
	var light = _barrier(Vector3(135, 0, 104), true, 0.7)
	tank.position = Vector3(135, 0, 102.6)
	_check(light.crush_by(tank) and light.hp == 0.0, "Heavy tank cannot crush light barricade")
	var driving = _barrier(Vector3(128, 0, 100), true, 0.7)
	var driver = _held("AdvancedTank", human, Vector3(126.4, 0, 100))
	await _frames(5)
	driver.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(Vector3(134, 0, 100))
	)
	await _frames(120)
	_check(driving.hp == 0.0, "Moving heavy vehicle did not crush contacted barricade")
	var grenade_barrier = _barrier(Vector3(145, 0, 100), true, 0.7)
	var infantry = _held("Infantry", human, Vector3(142, 0, 100))
	await _frames(5)
	_check(
		not infantry.abilities.trigger(
			"frag_grenade", grenade_barrier.global_position, grenade_barrier
		),
		"Frag grenade accepted an ungarrisoned obstacle"
	)
	_near(grenade_barrier.hp, 80.0, "Rejected frag grenade damaged obstacle")
	for node in [barrier, light, driving, driver, grenade_barrier, tank, infantry]:
		node.queue_free()
	await _frames(5)


func _wreck(point, amount = 7):
	var wreck = load("res://source/match/units/non-player/Wreck.tscn").instantiate()
	wreck.position = point
	wreck.resource_a = amount
	game.map.get_node("Resources").add_child(wreck)
	return wreck


func _scavenging():
	var salvage = load("res://source/match/economy/SalvageRules.gd")
	var costs = load("res://source/match/FactionRules.gd")
	for faction in ["bastion", "helix", "frontier"]:
		_near(
			salvage.amount(faction, "Tank"),
			floori(costs.unit_costs(faction).Tank[0] * 0.35),
			"35% wreck retention"
		)
	for role in ["Tank", "AntiAirVehicle", "AdvancedTank"]:
		var tank = _held(role, human, Vector3(140, 0, 110))
		await _frames(5)
		tank.hp = tank.hp_max * 0.2
		var damage = tank.attack_damage
		var speed = tank.movement_speed
		var funds = human.resource_a
		var remote = _wreck(tank.global_position + Vector3(0, 0, 5))
		_check(not tank.scavenge(remote), "Scavenge consumed distant wreck")
		remote.queue_free()
		for tier in [1, 2, 2]:
			var wreck = _wreck(tank.global_position + Vector3(0, 0, 1))
			_check(
				controller_script.context_kind(tank, wreck) == "scavenge",
				"Right-click did not select vehicle scavenging"
			)
			var previous = tank.hp
			_check(tank.scavenge(wreck), role + " cannot scavenge")
			_near(tank.hp, minf(tank.hp_max, previous + tank.hp_max * 0.35), "Scavenge repair")
			_check(not tank.scavenge(wreck), "Wreck consumed twice")
			_check(tank.scrap_hardened_tiers == tier, "Incorrect Scrap Hardened tier")
			_near(tank.attack_damage, damage * (1.0 + tier * 0.15), "Scrap weapon bonus")
			_near(tank.movement_speed, speed * (1.0 + tier * 0.1), "Scrap speed bonus")
		_near(human.resource_a, funds, "Vehicle scavenge also granted materials")
		paused = true
		await _frames(3)
		_near(tank.scrap_hardened_left, 60.0, "Pause advanced Scrap Hardened")
		paused = false
		tank._physics_process(60.0)
		_check(tank.scrap_hardened_tiers == 0, "Scrap Hardened did not expire")
		_near(tank.attack_damage, damage, "Expired scrap damage remains")
		_near(tank.movement_speed, speed, "Expired scrap speed remains")
		tank.queue_free()
		await _frames(3)
	var enemy = _held("Tank", opponent, Vector3(140, 0, 110))
	await _frames(5)
	var wreck = _wreck(enemy.global_position + Vector3(0, 0, 1))
	_check(not enemy.scavenge(wreck), "Non-Frontier tank scavenged wreck")
	for node in [enemy, wreck]:
		node.queue_free()
	await _frames(3)


func _field_dismantle():
	var worker = _held("Worker", human, Vector3(140, 0, 110))
	await _frames(5)
	worker.resource_a = 2
	var wreck = _wreck(worker.global_position + Vector3(0, 0, 0.9), 11)
	var funds = human.resource_a
	worker.manual_orders.submit(orders_script.target_order("gather", wreck), false, false)
	await _frames(30)
	_check(not is_instance_valid(wreck), "Frontier worker did not dismantle wreck")
	_near(human.resource_a, funds + 11, "Field dismantle requires HQ delivery")
	_near(worker.resource_a, 2, "Dismantle changed existing worker cargo")
	worker.queue_free()
	await _frames(3)


func _persistence():
	var tank = _held("Tank", human, Vector3(140, 0, 100))
	await _frames(5)
	var wreck = _wreck(tank.global_position + Vector3(0, 0, 1))
	_check(tank.scavenge(wreck), "Persistence fixture cannot scavenge")
	var next_wreck = _wreck(Vector3(146, 0, 100))
	var orders = orders_script
	tank.manual_orders.submit(orders.target_order("scavenge", next_wreck), false, false)
	var barrier = _barrier(Vector3(150, 0, 100))
	barrier.receive_damage(tank, 20.0)
	var breached = _barrier(Vector3(155, 0, 100))
	breached.receive_damage(tank, 80.0)
	await _frames(2)
	paused = true
	var round = game.projectile_system.launch(tank, barrier)
	round.shot.force_attack = true
	var builder = load("res://source/match/saves/MatchSnapshot.gd").new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Tactical save capture failed: " + builder.error)
	if snapshot == null:
		paused = false
		return
	var id = builder._reference(tank)
	var restorer = load("res://source/match/saves/MatchRestore.gd").new()
	_check(restorer.prepare(snapshot), "Tactical save rejected: " + restorer.error)
	if not restorer.error.is_empty():
		paused = false
		return
	var bad = snapshot.duplicate(true)
	bad.units.filter(func(unit): return unit.id == id)[0].scrap_hardened.tiers = 3
	_check(not restorer.prepare(bad), "Save accepted excess Scrap Hardened tiers")
	var restored = await restorer.restore(self, snapshot)
	_check(restored.ok, "Tactical save restore failed: " + restored.get("error", ""))
	if not restored.ok:
		paused = false
		return
	game = restored.game
	tank = restorer.entities[id]
	_check(tank.scrap_hardened_tiers == 1, "Saved Scrap Hardened tier lost")
	var obstacle_target_preserved = false
	for shot in game.projectile_system._rounds:
		if is_instance_valid(shot.target) and shot.target.is_in_group("destructible_obstacles"):
			obstacle_target_preserved = true
	_check(obstacle_target_preserved, "Saved projectile lost obstacle target")
	_check(
		tank.action != null and tank.action.get_script().resource_path.ends_with("Scavenging.gd"),
		"Saved scavenge order lost"
	)
	var barriers = get_nodes_in_group("destructible_obstacles")
	_check(barriers.size() == 2, "Saved barriers lost")
	_check(barriers.any(func(node): return node.hp == 60.0), "Saved barrier damage lost")
	_check(
		barriers.any(func(node): return node.hp == 0.0 and node.collision_layer == 0),
		"Saved breach became solid"
	)
	paused = false
	await _frames(240)
	_check(tank.scrap_hardened_tiers == 2, "Restored scavenge order did not complete")
