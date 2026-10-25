extends "res://tests/headless/CombatRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for index in 2:
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if index == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(player): return player != _human)[0]
	_enemy.set_process(false)
	await _frames(60)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	_game.repair_service.set_physics_process(false)
	await _pressure_rules()
	await _clear()
	await _projectile_rules()
	await _clear()
	await _permanent_armor()
	await _clear()
	_game.queue_free()
	await _frames(5)
	for error in _errors:
		push_error(error)
	print("Infantry suppression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _pressure_rules():
	var infantry = _spawn("AssaultInfantry", _human, Vector3(40, 0, 8))
	var hero = _spawn("Hero", _human, Vector3(41, 0, 8))
	var worker = _spawn("Worker", _human, Vector3(42, 0, 8))
	var enemy = _spawn("Infantry", _enemy, Vector3(45, 0, 8))
	await _frames(5)
	_check(
		hero.suppression == null and worker.suppression == null, "Hero/worker gained suppression"
	)
	var pressure = infantry.suppression
	var speed = infantry.movement_speed
	var interval = infantry.attack_interval
	pressure.add_pressure(50)
	_check(pressure.band == 1, "Suppressed threshold")
	_check(is_equal_approx(infantry.movement_speed, speed * 0.7), "Suppressed speed")
	_check(is_equal_approx(infantry.attack_interval, interval * 1.2), "Suppressed reload")
	infantry.abilities.trigger("combat_sprint")
	_check(is_equal_approx(infantry.movement_speed, speed * 0.7 * 1.5), "Sprint composition")
	pressure.add_pressure(50)
	_check(
		pressure.band == 2 and is_equal_approx(infantry.movement_speed, speed * 0.4 * 1.5),
		"Pinned replaced suppressed speed"
	)
	var before = infantry.hp
	infantry.receive_damage(enemy, 10, null, {"kind": "bullet"})
	_check(is_equal_approx(before - infantry.hp, 8.0), "Pinned direct-fire protection")
	before = infantry.hp
	infantry.receive_damage(enemy, 10, null, {"kind": "warhead"})
	_check(is_equal_approx(before - infantry.hp, 10.0), "Pinned protected from explosion")
	var state = pressure.capture()
	pressure._physics_process(2.5)
	_check(pressure.meter == 90.0 and pressure.band == 2, "Recovery delay or rate")
	pressure._physics_process(0.55)
	_check(is_equal_approx(pressure.meter, 79.0) and pressure.band == 1, "Pinned hysteresis")
	pressure._physics_process(1.65)
	_check(is_equal_approx(pressure.meter, 46.0) and pressure.band == 1, "Suppressed hysteresis")
	pressure._physics_process(0.1)
	_check(is_equal_approx(pressure.meter, 44.0) and pressure.band == 0, "Suppressed exit")
	pressure.restore(state)
	pressure._physics_process(7.0)
	_check(pressure.meter == 0.0 and pressure.band == 0, "Full recovery is not seven seconds")
	_check(pressure.add_pressure(16.0, true) == 16.0, "Near miss first contribution")
	_check(pressure.add_pressure(16.0, true) == 4.0, "Near miss rate exceeded20/s")
	_check(pressure.add_pressure(16.0, true) == 0.0, "Near miss cap bypassed")
	var capped = pressure.capture()
	pressure._physics_process(1.0)
	_check(pressure.add_pressure(16.0, true) == 16.0, "Near miss budget failed to recover")
	pressure.restore(capped)
	_check(pressure.add_pressure(16.0, true) == 0.0, "Save reset near miss cap")
	infantry.set_meta("garrison_host", hero)
	var sheltered = pressure.meter
	pressure.add_pressure(20.0)
	_check(pressure.meter == sheltered, "Shelter gained pressure")
	infantry.remove_meta("garrison_host")
	pressure.restore({})
	infantry.shields_max = 100.0
	infantry.shields = 100.0
	infantry.receive_weapon_hit(enemy)
	_check(
		pressure.meter == 6.0 and infantry.shields < 100.0, "Shield absorbed hit did not suppress"
	)
	pressure.process_mode = Node.PROCESS_MODE_ALWAYS
	pressure.set_physics_process(false)
	paused = true
	await _frames(3)
	_check(pressure.meter == 6.0, "Pause changed pressure")
	paused = false


func _projectile_rules():
	var shooter = _spawn("CombatRobot", _human, Vector3(40, 0, 8))
	var infantry = _spawn("Infantry", _enemy, Vector3(46, 0, 8))
	await _frames(5)
	var projectiles = _game.projectile_system
	var weapons = load("res://source/match/combat/WeaponCatalog.gd")
	var round = projectiles.Round.new()
	round.shot = load("res://source/match/combat/Shot.gd").from(shooter, shooter.global_position)
	round.weapon = weapons.RIFLE
	var start = infantry.global_position + Vector3(-3, 0.8, 0.9)
	var end = infantry.global_position + Vector3(3, 0.8, 0.9)
	projectiles._suppress_nearby(round, start, end)
	_check(infantry.suppression.meter == 0.0, "Rifle miss suppressed infantry")
	round.weapon = weapons.AUTOCANNON
	projectiles._suppress_nearby(round, start, end)
	_check(infantry.suppression.meter == 8.0, "Heavy swept near miss absent")
	projectiles._suppress_nearby(round, start, end)
	_check(infantry.suppression.meter == 8.0, "One round suppressed twice")
	projectiles._suppress_hit(round, infantry)
	_check(infantry.suppression.meter == 16.0, "Near miss then hit did not upgrade to16")
	infantry.suppression.restore({})
	round.suppression.clear()
	projectiles._suppress_nearby(round, start + Vector3.BACK * 4, end + Vector3.BACK * 4)
	_check(infantry.suppression.meter == 0.0, "Distant fire suppressed infantry")
	# Keep the path inside 1.5 m while a narrow wall separates it from the body.
	# Removing the wall must make this exact trajectory contribute pressure.
	var blocker = load("res://source/match/environment/DestructibleObstacle.gd").new()
	blocker.radius = 0.2
	blocker.obstacle_height = 2.0
	blocker.position = infantry.global_position + Vector3(0, 0, 0.6)
	_game.map.add_child(blocker)
	await _frames(3)
	_game.battlefield.invalidate()
	start = infantry.global_position + Vector3(-3, 0.8, 1.2)
	end = infantry.global_position + Vector3(3, 0.8, 1.2)
	projectiles._suppress_nearby(round, start, end)
	_check(infantry.suppression.meter == 0.0, "Occluded heavy fire suppressed infantry")
	blocker.queue_free()
	await _frames(3)
	_game.battlefield.invalidate()
	projectiles._suppress_nearby(round, start, end)
	_check(infantry.suppression.meter == 8.0, "Formerly occluded trajectory did not suppress")
	var terrain_model = load("res://source/match/maps/terrain/TerrainModel.gd")
	var layout = {"size": Vector2(4, 4)}
	var origin = Vector3(1.0, 0.8, 2.0)
	var destination = Vector3(2.1, 0.8, 2.0)
	_check(
		projectiles._pressure_terrain_clear(terrain_model.new(layout), origin, destination),
		"Open short terrain ray was blocked"
	)
	var wall = PackedVector2Array([Vector2(1.5, 1), Vector2(2, 1), Vector2(2, 3), Vector2(1.5, 3)])
	layout.blockers = [{"polygon": wall, "height": 2.0}]
	_check(
		not projectiles._pressure_terrain_clear(terrain_model.new(layout), origin, destination),
		"Sub-1.5 m ray passed through solid terrain"
	)
	layout.erase("blockers")
	layout.tiers = [{"polygon": wall, "height": 2.0}]
	_check(
		not projectiles._pressure_terrain_clear(terrain_model.new(layout), origin, destination),
		"Sub-1.5 m ray passed through raised ground"
	)


func _permanent_armor():
	var tank = _spawn("Tank", _human, Vector3(40, 0, 8))
	var source = _spawn("Infantry", _enemy, Vector3(45, 0, 8))
	tank.permanent_scrap_rank = 2
	tank.scrap_hardened_tiers = 2
	tank.scrap_hardened_left = 0.1
	tank._physics_process(0.2)
	_check(
		tank.scrap_hardened_tiers == 0 and tank.permanent_scrap_rank == 2,
		"Timed expiration removed permanent armor"
	)
	var before = tank.hp
	tank.receive_damage(source, 20.0)
	_check(is_equal_approx(before - tank.hp, 18.0), "Permanent armor did not reduce damage once")
