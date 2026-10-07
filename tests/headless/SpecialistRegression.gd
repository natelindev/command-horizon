extends "res://tests/headless/ProgramRegression.gd"

var _moving
var _launches = 0


func _run():
	_moving = load("res://source/match/units/actions/Moving.gd")
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/BigArena.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "bastion" if side == 0 else "helix"
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_enemy = get_nodes_in_group("players").filter(func(player): return player != _human)[0]
	_enemy.set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(40)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	for player in [_human, _enemy]:
		_spawn("VehicleFactory", player, Vector3(12, 0, 12))
		_spawn("CommandLab", player, Vector3(18, 0, 12))
		_check(player.basic_programs_unlocked(), "Specialist fixture locked")
		await _library_and_roles(player)
		await _standoff(player)
		await _support(player)
		await _strike(player)
		await _support_roles(player)
		await _clear()
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: both-faction specialist compatibility/save/factory fallback; standoff bounds/fire; "
				+ "stationary support; one-shot strike/regroup/cooldown/pause/manual; scout/repair roles"
			)
		)
	quit(0 if _errors.is_empty() else 1)


func _active(role, player, point, preset):
	var unit = _spawn(role, player, point, true)
	var config = Library.defaults(preset)
	config.radius = 10.0
	_check(unit.program.configure(config), "Role rejected preset: " + role + "/" + preset)
	unit.program.anchor = point
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	return unit


func _opponent(player):
	return _enemy if player == _human else _human


func _library_and_roles(player):
	var library = Library.new()
	var factory = load("res://source/match/programs/FactoryProgram.gd")
	var path = "user://specialist-%d.json" % OS.get_process_id()
	for preset in Library.PRESETS:
		_check(Library.validate(Library.defaults(preset)), "Invalid shipped preset: " + preset)
	var entry = library.save_version("Strike", Library.defaults("strike_return"), path)
	_check(library.read_library(path), "Specialist library did not roundtrip")
	var pin = {"name": entry.name, "version": int(entry.version)}
	_check(
		factory.snapshot(pin, "Helicopter", path).config.preset == "strike_return",
		"Factory lost compatible preset"
	)
	var fallback = factory.snapshot(pin, "Tank", path)
	_check(
		fallback.config.preset == "hold" and not fallback.notice.is_empty(),
		"Factory did not explain incompatible fallback"
	)
	var tank = _spawn("Tank", player, Vector3(20, 0, 25), true)
	var action = tank.action
	_check(
		not tank.program.configure(Library.defaults("strike_return")),
		"Armor accepted aircraft program"
	)
	_check(tank.action == action, "Rejected program interrupted orders")
	factory.apply_to(
		tank, {"config": Library.defaults("strike_return"), "title": "Wrong", "notice": ""}
	)
	_check(tank.program.config.preset == "hold", "Queued incompatible snapshot bypassed validation")
	tank.queue_free()
	DirAccess.remove_absolute(path)
	await _frames(3)


func _standoff(player):
	var point = Vector3(30, 0, 30)
	var unit = _active("AdvancedTank", player, point, "standoff")
	var enemy = _spawn("Tank", _opponent(player), point + Vector3(2, 0, 0))
	enemy.hp_max = 10000
	enemy.hp = 10000
	await _frames(30)
	unit.program.run()
	var max_distance = 0.0
	for index in range(400):
		await process_frame
		max_distance = maxf(max_distance, unit.global_position_yless.distance_to(point))
	_check(
		(
			unit.global_position_yless.distance_to(enemy.global_position_yless)
			>= unit.attack_range * 0.65
		),
		"Standoff did not create range"
	)
	_check(enemy.hp < 10000, "Standoff never fired after repositioning")
	_check(max_distance <= 12.1, "Standoff left assigned bounds")
	unit.issue_manual_order(_moving.new(Vector3(20, 0, 32)))
	await _frames(45)
	_check(unit.program.mode == "Manual", "Standoff overrode human movement")
	unit.queue_free()
	enemy.queue_free()
	await _frames(3)


func _support(player):
	var center = Vector3(42, 0, 35)
	var unit = _active("CombatRobot", player, Vector3(40, 0, 35), "fire_support")
	unit.program.anchor = center
	var enemy = _spawn("Tank", _opponent(player), Vector3(45, 0, 35))
	enemy.hp_max = 10000
	enemy.hp = 10000
	await _frames(30)
	unit.program.run()
	await _frames(240)
	_check(
		unit.global_position_yless.distance_to(center) <= 1.0, "Fire support did not occupy anchor"
	)
	_check(enemy.hp < 10000, "Fire support did not fire at legal target")
	var position_before = unit.global_position
	enemy.global_position = Vector3(52, 0, 35)
	_game.battlefield.invalidate()
	await _frames(180)
	_check(
		unit.global_position.distance_to(position_before) < 0.3,
		"Fire support pursued escaping target"
	)
	unit.queue_free()
	enemy.queue_free()
	await _frames(3)


func _strike(player):
	var center = Vector3(32, 0, 42)
	var home = Vector3(22, 0, 42)
	var unit = _active("Helicopter", player, center, "strike_return")
	unit.attack_interval = 8.0
	await _frames(30)
	unit.program.run()
	await _frames(30)
	_check(unit.program.mode == "Waiting", "Strike launched without a regroup point")
	unit.program.safe_point = home
	unit.program.run()
	await _frames(3)
	var enemy = _spawn("Tank", _opponent(player), center + Vector3(2, 0, 0))
	enemy.hp_max = 10000
	enemy.hp = 10000
	_launches = 0
	unit.child_entered_tree.connect(
		func(child):
			if "target_unit" in child:
				_launches += 1
	)
	var visited_home = false
	var paused_checked = false
	var last_count = 0
	for frame in range(900):
		await process_frame
		if unit.global_position_yless.distance_to(home) <= 1.0:
			visited_home = true
			if not paused_checked and _launches > 0:
				var time = _game.simulation_time
				var count = _launches
				paused = true
				await _frames(45)
				_check(
					_game.simulation_time == time and _launches == count,
					"Paused sortie/cooldown advanced"
				)
				paused = false
				paused_checked = true
		if _launches > last_count:
			if last_count > 0:
				_check(visited_home, "Aircraft fired again without regrouping")
			visited_home = false
			last_count = _launches
	_check(_launches >= 2 and _launches <= 3, "Strike cycle did not respect one shot and cooldown")
	_check(paused_checked, "Aircraft never reached regroup point")
	_check(enemy.hp < 10000, "Strike projectile never damaged target")
	unit.hp = unit.hp_max * 0.2
	await _frames(240)
	_check(
		unit.global_position_yless.distance_to(home) <= 1.0, "Damaged strike unit failed to retreat"
	)
	unit.hp = unit.hp_max * 0.6
	await _frames(60)
	_check(
		unit.global_position_yless.distance_to(home) <= 1.0,
		"Strike ignored return-health hysteresis"
	)
	unit.hp = unit.hp_max
	await _frames(90)
	_check(
		unit.global_position_yless.distance_to(home) > 1.0,
		"Recovered strike unit did not resume sortie"
	)
	var count_before = _launches
	unit.issue_manual_order(_moving.new(Vector3(15, 0, 42)))
	await _frames(60)
	_check(
		unit.program.mode == "Manual" and _launches == count_before,
		"Strike continued over manual order"
	)
	unit.queue_free()
	enemy.queue_free()
	await _frames(3)


func _support_roles(player):
	var scout = _active("Drone", player, Vector3(30, 0, 50), "scout_patrol")
	scout.program.run()
	await _frames(30)
	_check(scout.program.mode == "Waiting", "Scout invented missing route")
	scout.program.route = [Vector3(32, 0, 50), Vector3(35, 0, 50)]
	scout.program.run()
	await _frames(100)
	_check(
		scout.program.mode == "Running" and scout.global_position.x > 31,
		"Named scout route did not run"
	)
	var repair = _active("RepairRobot", player, Vector3(30, 0, 55), "escort_repair")
	repair.program.run()
	await _frames(30)
	_check(repair.program.mode == "Waiting", "Repair escort invented assignment")
	var ally = _spawn("Tank", player, Vector3(32, 0, 55))
	ally.hp -= 4
	repair.program.escort = ally
	repair.program.run()
	await _frames(240)
	_check(ally.hp == ally.hp_max, "Named escort repair did not heal")
	_check(
		repair.program.configure(Library.defaults("hold_service")), "Service area preset rejected"
	)
	repair.program.anchor = Vector3(32, 0, 55)
	repair.program.run()
	ally.hp -= 4
	await _frames(240)
	_check(ally.hp == ally.hp_max, "Named service area did not heal")
	for unit in [scout, repair, ally]:
		unit.queue_free()
	await _frames(3)
