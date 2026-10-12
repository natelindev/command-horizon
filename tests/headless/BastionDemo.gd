extends SceneTree

const Catalog = preload("res://source/match/BastionCatalog.gd")
var auto_attacking
var _failures = []
var _game = null
var _human = null


func _initialize():
	call_deferred("_run")


func _run():
	auto_attacking = load("res://source/match/units/actions/AutoAttacking.gd")
	root.get_node("FeatureFlags").handle_match_end = false
	_game = load("res://source/match/BastionDemo.tscn").instantiate()
	root.add_child(_game)
	current_scene = _game
	_human = _game._get_human_player()
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	for player in get_nodes_in_group("players"):
		if player != _human:
			player.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(60)
	for unit_type in Catalog.NAMES:
		var unit = _unit(unit_type)
		_check(unit != null, "Missing starter: " + unit_type)
		if unit == null:
			continue
		_check(unit.hp == unit.hp_max and unit.hp > 0, "Invalid HP: " + unit_type)
		_check(
			not (
				unit
				. get_node("Geometry")
				. find_children("*", "MeshInstance3D", true, false)
				. is_empty()
			),
			"No meshes: " + unit_type
		)
		var team_surfaces = 0
		for mesh in unit.get_node("Geometry").find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				if mesh.get_surface_override_material(surface) == _human.get_color_material():
					team_surfaces += 1
		_check(team_surfaces > 0, "Team colors missing: " + unit_type)
	_check(_human.population() == 10, "Starter population")
	_check(_human.power_totals() == Vector2i(32, 29), "Starter power")
	await _test_production()
	await _test_building_and_repairs()
	await _test_movement_and_combat()
	await _test_weapons()
	_test_skirmish_slots()
	_game.queue_free()
	await _frames(4)
	if _failures.is_empty():
		print(
			(
				"PASS: Bastion roster, team colors, all production, economy gates, power, construction, "
				+ "repairs, navigation, combat, pause, and skirmish slots"
			)
		)
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _test_production():
	_human.resource_a = 10000
	_human.resource_b = 10000
	var menus = _game.find_child("UnitMenus")
	var signals = root.get_node("MatchSignals")
	for producer in Catalog.PRODUCES:
		var unit = _unit(producer)
		signals.deselect_all_units.emit()
		unit.get_node("Selection").select()
		var queue = unit.production_queue
		queue.set_process(false)
		for product in Catalog.PRODUCES[producer]:
			var button = menus.find_child("Produce" + product, true, false)
			_check(
				button != null and not button.disabled, "Production button unavailable: " + product
			)
			if button != null:
				button.pressed.emit()
		_check(queue.size() == Catalog.PRODUCES[producer].size(), "Roster not queued: " + producer)
		queue._process(1000.0)
		_check(queue.size() == 0, "Queue did not finish: " + producer)
	_check(_human.population() == 18, "Every mobile unit must actually spawn")
	var factory = _unit("VehicleFactory")
	var queue = factory.production_queue
	var tank = load(Catalog.scene_path("Tank"))
	var lab = _unit("CommandLab")
	lab._construction_progress = 0.0
	_check(
		queue.produce(load(Catalog.scene_path("AdvancedTank"))) == null, "Lab prerequisite bypassed"
	)
	lab._construction_progress = 1.0
	var power = _unit("PowerPlant")
	power._construction_progress = 0.0
	var element = queue.produce(tank)
	var before = element.time_left
	queue._process(1.0)
	_check(
		is_equal_approx(element.time_left, before - 0.35), "Low power must reduce production to 35%"
	)
	power._construction_progress = 1.0
	queue.cancel_all()
	var funds = Vector2i(_human.resource_a, _human.resource_b)
	queue.produce(tank)
	queue.cancel_all()
	_check(funds == Vector2i(_human.resource_a, _human.resource_b), "Cancellation must refund")
	_human.resource_a = 0
	_human.resource_b = 0
	_check(queue.produce(tank) == null, "Unaffordable production accepted")
	_human.resource_a = 10000
	_human.resource_b = 10000
	_check(queue.produce(load(Catalog.scene_path("Worker"))) == null, "Wrong producer accepted")
	# A frame spanning two completions must consume each job's time exactly once.
	var first = queue.produce(tank)
	var second = queue.produce(tank)
	var duration = first.time_total
	queue._process(duration + 1.0)
	_check(
		queue.size() == 1 and is_equal_approx(second.time_left, duration - 1.0),
		"Queue double-spent elapsed time"
	)
	queue.cancel_all()
	var limit = Catalog.POPULATION_LIMIT - _human.population()
	for _index in range(limit):
		_check(queue.produce(tank, true) != null, "Population filled too early")
	_check(queue.produce(tank, true) == null, "Population limit exceeded")
	queue.cancel_all()
	await _frames(2)


func _test_building_and_repairs():
	var placement = _human.get_node("StructurePlacementHandler")
	for structure_type in Catalog.STRUCTURES:
		placement._start_structure_placement(load(Catalog.scene_path(structure_type)))
		_check(placement._active_blueprint_node != null, "Missing blueprint: " + structure_type)
		placement._cancel_structure_placement()
	var worker = _unit("Worker")
	worker.action = null
	var structure = load(Catalog.scene_path("PowerPlant")).instantiate()
	_game._setup_and_spawn_unit(structure, Transform3D(Basis(), Vector3(8, 0, 32)), _human)
	_check(structure.is_under_construction(), "New structure starts completed")
	worker.global_position = Vector3(8, 0, 34.4)
	worker.get_node("Movement").stop()
	worker.action = load("res://source/match/units/actions/Constructing.gd").new(structure)
	await _frames(15)
	_check(structure._construction_progress > 0, "Engineer did not construct")
	structure.construct(1.0)
	_check(structure.hp == structure.hp_max, "Completed structure lost construction HP")
	worker.action = null
	var robot = _unit("RepairRobot")
	var tank = _unit("Tank")
	tank.action = null
	robot.global_position = Vector3(19, 0, 31)
	tank.global_position = Vector3(20.5, 0, 31)
	robot.get_node("Movement").stop()
	tank.get_node("Movement").stop()
	tank.hp = 20
	_game.repair_service.service(1.0)
	_check(is_equal_approx(tank.hp, 22.0), "Idle robot did not repair")
	robot.action = load("res://source/match/units/actions/Repairing.gd").new(tank)
	robot.action._physics_process(0.6)
	_game.repair_service.service(1.0)
	_check(is_equal_approx(tank.hp, 24.0), "Manual repair did not heal")
	robot.action = null
	tank.global_position = _unit("RepairDepot").global_position + Vector3(0, 0, 3)
	_game.repair_service.service(1.0)
	_check(is_equal_approx(tank.hp, 27.2), "Depot did not heal")


func _test_movement_and_combat():
	for unit_type in ["Infantry", "Tank", "CombatRobot", "Drone", "Helicopter"]:
		var unit = _unit(unit_type)
		unit.action = null
		unit.global_position = Vector3(38, 1.5 if unit.movement_domain == 0 else 0, 15)
		var start = unit.global_position
		unit.action = load("res://source/match/units/actions/Moving.gd").new(
			start + Vector3(0, 0, 5)
		)
		await _frames(100)
		_check(
			unit.global_position.distance_to(start) > 1.0, "Desert navigation failed: " + unit_type
		)
		unit.action = null
	var tank = _unit("Tank")
	tank.global_position = Vector3(36, 0, 25)
	tank.get_node("Movement").stop()
	var enemy_player = get_nodes_in_group("players").filter(func(p): return p != _human)[0]
	var target = load(Catalog.scene_path("Worker")).instantiate()
	_game._setup_and_spawn_unit(
		target, Transform3D(Basis(), Vector3(39, 0, 25)), enemy_player, false
	)
	target.process_mode = Node.PROCESS_MODE_PAUSABLE
	target.hp = 100
	var initial_hp = target.hp
	tank.action = auto_attacking.new(target)
	await _frames(15)
	_check(target.hp < initial_hp, "Tank did not damage target")
	_check(tank.aim_target == target, "Turret target not assigned")
	var turret = tank.find_child("*TurretPivot", true, false)
	_check(abs(turret.rotation.y) > 0.2, "Turret did not turn")
	# Regression: destroying the target during an active attack must not dereference freed objects.
	target.queue_free()
	await _frames(4)
	_check(tank.aim_target == null, "Destroyed target still tracked")
	var hud_script = load("res://source/match/hud/BastionDemoHUD.gd")
	var hud = _game.get_children().filter(func(node): return node.get_script() == hud_script)[0]
	hud._toggle_pause()
	_check(paused, "Tactical pause did not pause")
	var position_before = tank.global_position
	await _frames(4)
	_check(tank.global_position.is_equal_approx(position_before), "Movement continued during pause")
	hud._toggle_pause()
	_check(not paused, "Tactical pause did not resume")


func _test_weapons():
	var enemy = get_nodes_in_group("players").filter(func(p): return p != _human)[0]
	for attacker_type in [
		"Infantry", "CombatRobot", "AdvancedTank", "Helicopter", "AntiGroundTurret", "AntiAirTurret"
	]:
		var attacker = _unit(attacker_type)
		var original_position = attacker.global_position
		attacker.global_position = Vector3(36, 1.5 if attacker_type == "Helicopter" else 0.0, 30)
		var last_shot = attacker.get_meta("next_attack_availability_time", 0)
		var target_type = "Drone" if attacker_type == "AntiAirTurret" else "Worker"
		var target = load(Catalog.scene_path(target_type)).instantiate()
		_game._setup_and_spawn_unit(target, Transform3D(Basis(), Vector3(39, 0, 30)), enemy, false)
		target.process_mode = Node.PROCESS_MODE_PAUSABLE
		target.hp = 500
		if attacker_type.begins_with("Anti"):
			attacker.action = null
		attacker.action = auto_attacking.new(target)
		await _frames(130)
		_check(target.hp < 500, "Weapon did not deal damage: " + attacker_type)
		_check(
			attacker.get_meta("next_attack_availability_time", 0) > last_shot,
			"Attacker did not fire: " + attacker_type
		)
		target.queue_free()
		attacker.global_position = original_position
		await _frames(3)
	# Regression: removing a selected producer must clear both its menu and queue UI.
	var factory = _unit("VehicleFactory")
	root.get_node("MatchSignals").deselect_all_units.emit()
	factory.get_node("Selection").select()
	factory.hp = 0
	await _frames(3)
	_check(not _game.find_child("UnitMenus").visible, "Destroyed producer menu remained visible")


func _test_skirmish_slots():
	var play = load("res://source/main-menu/Play.tscn").instantiate()
	root.add_child(play)
	var settings = play._create_match_settings()
	_check(settings.players.size() <= 2, "Hidden skirmish slots leak into two-player map")
	play.queue_free()


func _unit(unit_type):
	for unit in _human.get_children():
		if "type" in unit and unit.type == unit_type:
			return unit
	return null


func _frames(count):
	for _index in range(count):
		await physics_frame


func _check(condition, message):
	if not condition:
		_failures.append(message)
