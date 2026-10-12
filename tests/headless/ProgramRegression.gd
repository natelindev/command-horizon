extends SceneTree

const Catalog = preload("res://source/match/BastionCatalog.gd")
const Library = preload("res://source/match/programs/ProgramLibrary.gd")
var _game
var _human
var _enemy
var _errors = []
var _fixtures = []


func _initialize():
	call_deferred("_run")


func _run():
	_test_library()
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
	_game.repair_service.set_physics_process(false)
	await _test_progression()
	await _clear()
	await _test_authority_and_assignments()
	await _clear()
	await _test_combat_bounds()
	await _clear()
	await _test_retreat_and_blocked()
	await _clear()
	await _test_support()
	await _clear()
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: chip unlock/retrofit/production/refunds; library validation/version persistence; "
				+ "manual authority/pause; guard/escort/patrol/retreat; "
				+ "fog/fire bounds; repair; blocked recovery"
			)
		)
	quit(0 if _errors.is_empty() else 1)


func _spawn(role, player, point, chip = false):
	var unit = load(Catalog.scene_path(role)).instantiate()
	unit.set_meta("chip_installed", chip)
	_game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	_fixtures.append(unit)
	return unit


func _test_library():
	var library = Library.new()
	var path = "user://program-regression-%d.json" % OS.get_process_id()
	_check(library.read_library(path), "Empty library should load")
	var config = Library.defaults("guard")
	var first = library.save_version("Perimeter", config, path)
	config.retreat = 40
	var second = library.save_version("Perimeter", config, path)
	_check(first != null and second != null and second.version == 2, "Version numbering failed")
	var loaded = Library.new()
	_check(
		loaded.read_library(path) and loaded.versions[0].config.retreat == 30,
		"Saved versions mutated"
	)
	_check(loaded.versions[1].config.retreat == 40, "New version lost parameters")
	config["return"] = 35
	_check(not Library.validate(config), "Invalid hysteresis accepted")
	config = Library.defaults()
	config.radius = NAN
	_check(not Library.validate(config), "NaN parameter accepted")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	_check(not loaded.read_library(path), "Corrupt library accepted")
	_check(loaded.save_version("bad", Library.defaults(), path) == null, "Corrupt file overwritten")
	_check(FileAccess.get_file_as_string(path) == "corrupt", "Existing library not preserved")
	DirAccess.remove_absolute(path)


func _test_progression():
	# The current HQ supplies 8 power. Factory + depot need 9 before the
	# deliberate low-power aircraft fixtures are added below.
	_spawn("PowerPlant", _human, Vector3(5, 0, 15))
	var robot = _spawn("CombatRobot", _human, Vector3(20, 0, 20))
	_check(robot.program.installed and not robot.program.run(), "Hardware bypassed tech unlock")
	_check(
		_spawn("Infantry", _human, Vector3(25, 0, 20)).program == null, "Infantry can run programs"
	)
	var factory = _spawn("VehicleFactory", _human, Vector3(15, 0, 15))
	_check(not _human.basic_programs_unlocked(), "Factory alone unlocked programs")
	var lab = _spawn("CommandLab", _human, Vector3(10, 0, 15))
	lab._construction_progress = 0.5
	_check(not _human.basic_programs_unlocked(), "Unfinished lab unlocked programs")
	lab._construction_progress = 1.0
	_check(_human.basic_programs_unlocked(), "Completed tech path did not unlock")
	lab.queue_free()
	await _frames(2)
	_check(_human.basic_programs_unlocked(), "Lab destruction removed installed tech")
	var service = _spawn("RepairDepot", _human, Vector3(20, 0, 30))
	var tank = _spawn("Tank", _human, Vector3(23, 0, 30))
	_human.resource_b = 40
	_check(tank.program.install_at(service), "Valid retrofit rejected")
	_check(_human.resource_b == 36, "Retrofit fee not reserved")
	_check(not tank.program.install_at(service), "Duplicate retrofit charged")
	tank.issue_manual_order(null)
	_check(
		_human.resource_b == 40 and tank.program.install_left == 0,
		"Cancel did not refund exactly once"
	)
	var drains = []
	for index in range(3):
		drains.append(_spawn("AircraftFactory", _human, Vector3(5 + index * 5, 0, 40)))
	tank.program.install_at(service)
	tank.process_mode = Node.PROCESS_MODE_INHERIT
	paused = true
	await _frames(30)
	_check(tank.program.install_left == 5.0, "Chip installation advanced during pause")
	paused = false
	await _frames(120)
	_check(tank.program.install_left > 4.0, "Low power did not slow installation to 35 percent")
	tank.issue_manual_order(null)
	_check(_human.resource_b == 40, "Partially installed chip did not refund in full")
	for drain in drains:
		drain.queue_free()
	await _frames(3)
	tank.program.install_at(service)
	await _frames(340)
	_check(
		tank.program.installed and _human.resource_b == 36,
		"Retrofit did not finish after five seconds"
	)
	_check(not tank.program.install_at(service), "Installed chip purchased again")
	var doomed = _spawn("Tank", _human, Vector3(23, 0, 34))
	doomed.program.install_at(service)
	doomed.hp = 0
	await _frames(3)
	_check(_human.resource_b == 32, "Destroyed retrofit refunded fee")
	var before = _human.resource_b
	var other = _spawn("Tank", _human, Vector3(23, 0, 36))
	other.program.install_at(service)
	service.queue_free()
	other.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(4)
	_check(_human.resource_b == before, "Lost service did not cancel/refund retrofit")
	var new_lab = _spawn("CommandLab", _human, Vector3(10, 0, 15))
	_human.resource_a = 100
	_human.resource_b = 100
	factory.production_queue.fit_chips = true
	var queued = factory.production_queue.produce(load(Catalog.scene_path("Tank")))
	_check(
		queued != null and queued.time_total == 25 and queued.fitted_chip,
		"Chip factory job missing fee/time"
	)
	_check(_human.resource_b == 90, "Factory chip fee incorrect")
	factory.production_queue.cancel(queued)
	_check(_human.resource_b == 100, "Factory cancellation failed full refund")
	queued = factory.production_queue.produce(load(Catalog.scene_path("Tank")))
	queued.time_left = 0.05
	new_lab.queue_free()
	await _frames(2)
	factory.production_queue._process(1.0)
	_check(factory.production_queue.size() == 1, "Chip production ignored lost lab")
	_spawn("CommandLab", _human, Vector3(10, 0, 15))
	factory.production_queue._process(1.0)
	var produced = _human.get_children().filter(
		func(node): return "type" in node and node.type == "Tank" and node not in _fixtures
	)
	_check(
		produced.size() == 1 and produced[0].program.installed, "Produced tank lost installed chip"
	)
	for unit in produced:
		_fixtures.append(unit)


func _activate(unit, preset, point = null):
	unit.program.configure(Library.defaults(preset))
	unit.program.anchor = point
	unit.program.run()
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(35)


func _test_authority_and_assignments():
	var unit = _spawn("Tank", _human, Vector3(30, 0, 30), true)
	await _activate(unit, "guard")
	_check(unit.program.mode == "Waiting", "Unassigned guard roamed")
	_check(not unit.get_node("Movement")._has_destination, "Unassigned guard moved")
	unit.program.anchor = Vector3(35, 0, 30)
	unit.program.run()
	await _frames(30)
	unit.issue_manual_order(
		load("res://source/match/units/actions/Moving.gd").new(Vector3(30, 0, 36))
	)
	var action = unit.action
	await _frames(20)
	_check(unit.program.mode == "Manual" and unit.action == action, "Program overrode manual move")
	await _frames(240)
	_check(unit.program.mode == "Manual", "Program auto-resumed after manual completion")
	unit.program.run()
	paused = true
	var point = unit.global_position
	var tick = _game.simulation_time
	await _frames(20)
	_check(
		(
			unit.global_position == point
			and _game.simulation_time == tick
			and unit.program.mode == "Ready"
		),
		"Program ran during tactical pause"
	)
	paused = false
	await _frames(20)
	_check(unit.program.mode == "Running", "Program failed to resume after pause")
	unit.issue_manual_order(null)
	await _frames(20)
	_check(
		unit.program.mode == "Manual" and not unit.get_node("Movement")._has_destination,
		"Stop failed manual hold"
	)
	# Invalid edit preserves the running configuration and order.
	var config = Library.defaults()
	config["return"] = 20
	_check(
		not unit.program.configure(config) and unit.program.config.preset == "guard",
		"Invalid config replaced working preset"
	)


func _test_combat_bounds():
	var unit = _spawn("Tank", _human, Vector3(30, 0, 30), true)
	var target = _spawn("Tank", _enemy, Vector3(34, 0, 30))
	var original_hp = target.hp
	await _activate(unit, "guard", Vector3(30, 0, 30))
	await _frames(100)
	_check(target.hp < original_hp, "Guard did not fire at legal target")
	var injured = _spawn("Tank", _enemy, Vector3(34, 0, 32))
	injured.hp = injured.hp_max * 0.4
	unit.program.config.priority = "weakest"
	await _frames(20)
	_check(unit.action._target == injured, "Lowest-health priority ignored visible damaged target")
	injured.queue_free()
	var infantry = _spawn("Infantry", _enemy, Vector3(31, 0, 28))
	unit.program.config.priority = "armor"
	await _frames(20)
	_check(unit.action._target == target, "Armor priority chose closer infantry")
	infantry.queue_free()
	unit.program.config.priority = "nearest"
	target.global_position = Vector3(38, 0, 30)
	_game.battlefield.invalidate()
	await _frames(20)
	_check(unit.aim_target == null, "Guard pursued target outside assignment")
	_check(
		unit.global_position_yless.distance_to(Vector3(30, 0, 30)) < 2, "Guard escaped its sector"
	)
	target.global_position = Vector3(34, 0, 30)
	var blocker = _spawn("Barracks", _human, Vector3(32, 0, 30))
	await _frames(20)
	var hp = target.hp
	await _frames(100)
	_check(target.hp == hp, "Program fired through blocker")
	blocker.queue_free()
	target.global_position = Vector3(90, 0, 90)
	await _frames(30)
	_check(
		unit.aim_target == null and not unit.get_node("Movement")._has_destination,
		"Program tracked hidden target"
	)


func _test_retreat_and_blocked():
	var unit = _spawn("Tank", _human, Vector3(30, 0, 30), true)
	unit.program.safe_point = Vector3(25, 0, 30)
	unit.hp = unit.hp_max * 0.25
	await _activate(unit, "guard", Vector3(30, 0, 30))
	_check(
		unit.action._retreating and "Retreating" in unit.program.reason,
		"Low health did not retreat"
	)
	unit.hp = unit.hp_max * 0.5
	await _frames(30)
	_check(unit.action._retreating, "Retreat hysteresis oscillated at 50 percent")
	unit.hp = unit.hp_max * 0.85
	await _frames(30)
	_check(not unit.action._retreating, "Recovery failed to release retreat")
	unit.issue_manual_order(null)
	unit.program.safe_point = null
	unit.hp = unit.hp_max * 0.2
	await _activate(unit, "guard", Vector3(30, 0, 30))
	_check(
		unit.program.mode == "Waiting" and not unit.get_node("Movement")._has_destination,
		"Guessed an unassigned retreat point"
	)
	unit.hp = unit.hp_max
	unit.program.anchor = Vector3(45, 0, 30)
	unit.program.run()
	await _frames(20)
	# Freeze the actual navigation component to reproduce a five-second traffic deadlock.
	unit.get_node("Movement").process_mode = Node.PROCESS_MODE_DISABLED
	unit.get_node("Movement").avoidance_enabled = false
	# A moving destination must not reset the no-progress timeout.
	for index in range(12):
		unit.program.anchor = Vector3(45 + index, 0, 30)
		await _frames(30)
	_check(unit.program.mode == "Blocked", "No-progress timeout failed")
	_check(not unit.get_node("Movement")._has_destination, "Blocked program kept issuing movement")
	unit.program.run()
	await _frames(20)
	_check(unit.program.mode == "Running", "Explicit retry failed to reset blocked state")


func _test_support():
	var scout = _spawn("Drone", _human, Vector3(30, 0, 30))
	var leader = _spawn("Tank", _human, Vector3(35, 0, 30), true)
	scout.program.escort = leader
	await _activate(scout, "escort")
	_check(scout.program.mode == "Running", "Scout escort rejected")
	leader.queue_free()
	await _frames(25)
	_check(scout.program.mode == "Waiting", "Destroyed escort reference not handled")
	scout.program.route = [Vector3(30, 0, 30), Vector3(35, 0, 30)]
	await _activate(scout, "patrol")
	var point = scout.global_position
	await _frames(100)
	_check(scout.global_position.distance_to(point) > 1, "Scout patrol did not move")
	var repair = _spawn("RepairRobot", _human, Vector3(50, 0, 30))
	var ally = _spawn("Tank", _human, Vector3(52, 0, 30), true)
	ally.hp = ally.hp_max * 0.5
	await _activate(repair, "guard", Vector3(50, 0, 30))
	_check(repair.action.repair_target() == ally, "Repair preset failed to assign damaged ally")
	var hp = ally.hp
	_game.repair_service.service(1.0)
	_check(ally.hp > hp, "Preset service did not heal")


func _clear():
	for unit in _fixtures:
		if is_instance_valid(unit):
			unit.queue_free()
	_fixtures.clear()
	await _frames(5)


func _frames(count):
	for frame in range(count):
		await process_frame


func _check(condition, message):
	if not condition and message not in _errors:
		_errors.append(message)
