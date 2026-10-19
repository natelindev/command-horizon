extends SceneTree

const Progress = preload("res://source/match/campaign/CampaignProgress.gd")

var game
var errors = []
var path = ""


func _initialize():
	create_timer(600).timeout.connect(
		func():
			push_error("Campaign regression timed out")
			quit(1)
	)
	_run.call_deferred()


func _make_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = "first_orders"
	settings.map_path = "res://source/match/maps/FirstOrdersMap.tscn"
	for index in range(2):
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if index == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		side.faction = "bastion" if index == 0 else "helix"
		side.difficulty = 1
		settings.players.append(side)
	game = load("res://source/match/campaign/FirstOrders.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	game.progress_path = path
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(40)


func _run():
	path = "user://campaign-regression-%d.json" % OS.get_process_id()
	await _make_match()
	await _capture_rules()
	game.queue_free()
	await _frames(5)
	await _make_match()
	await _full_mission()
	paused = false
	game.queue_free()
	await _frames(5)
	await _make_match()
	await _defeat()
	paused = false
	game.queue_free()
	await _frames(5)
	_progress_integrity()
	DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	if errors.is_empty():
		print("PASS: First Orders preset victory; capture/contest/vision; pause/defeat/progress")
	quit(0 if errors.is_empty() else 1)


func _capture_rules():
	game.finished = true  # Isolate objective rules from mission transitions/waves.
	var human = game._get_human_player()
	var enemy = game._enemy
	var infantry = _units(human, "Infantry")[0]
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		if unit.movement_speed > 0:
			unit.global_position = Vector3(8, 0, 8) if unit.player == human else Vector3(70, 0, 55)
	var relay = game.relay
	infantry.global_position = relay.global_position + Vector3(1.5, 0, 0)
	var second_infantry = _units(human, "Infantry")[1]
	second_infantry.global_position = relay.global_position + Vector3(0, 0, 2)
	game.battlefield.invalidate()
	await _frames(300)
	_check(
		relay.captured_by == null and relay.progress > 4,
		"Relay captured too fast or made no progress"
	)
	var tank = game._spawn("Tank", enemy, relay.global_position + Vector3(0, 0, 2))
	tank.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)
	var progress = relay.progress
	await _frames(120)
	_check(
		relay.contested and abs(relay.progress - progress) < 0.05,
		"Enemy tank did not pause capture"
	)
	paused = true
	await _frames(30)
	_check(relay.progress == progress, "Capture advanced during tactical pause")
	paused = false
	tank.global_position = Vector3(70, 0, 55)
	game.battlefield.invalidate()
	await _frames(330)
	_check(relay.captured_by == human, "Infantry did not finish capture")
	infantry.global_position = Vector3(8, 0, 8)
	second_infantry.global_position = Vector3(8, 0, 8)
	tank.global_position = relay.global_position + Vector3(0, 0, relay.sight_range - .5)
	game.battlefield.invalidate()
	_check(game.battlefield.is_observed(human, tank), "Owned relay did not reveal its local area")
	tank.global_position = relay.global_position + Vector3(0, 0, relay.sight_range + 3)
	game.battlefield.invalidate()
	_check(not game.battlefield.is_observed(human, tank), "Relay revealed beyond its local sight")
	_check(
		relay not in game.battlefield.nearby_units(relay.global_position, 10),
		"Relay entered unit target snapshots"
	)
	game.phase = 2
	game.hold_seconds = 7.0
	tank.global_position = relay.global_position + Vector3(1.8, 0, 0)
	game.battlefield.invalidate()
	await _frames(3)
	game._check_outcome(1.0)
	_check(game.hold_seconds == 7.0, "Enemy armor did not pause owned-relay hold")
	_check(game.waves_warned == 1 and game.waves_sent == 0, "Response arrived without warning")
	tank.global_position = Vector3(70, 0, 55)
	infantry.global_position = Vector3(66, 0, 34)
	game.battlefield.invalidate()
	game._send_wave()
	_check(game.waves_sent == 0, "Reinforcements spawned on a defended entry")
	infantry.global_position = Vector3(8, 0, 8)
	var enemy_infantry = _units(enemy, "Infantry")[0]
	enemy_infantry.global_position = relay.global_position + Vector3(1, 0, 0)
	game.battlefield.invalidate()
	await _frames(630)
	_check(relay.captured_by == enemy, "Enemy infantry could not recapture")
	_check(not relay.is_revealing(), "Recaptured relay retained human vision")
	game._check_outcome(0.1)
	_check(game.hold_seconds == 0, "Recapture retained mission hold progress")
	# Engineers and aircraft alone cannot capture a neutral objective.
	enemy_infantry.global_position = Vector3(70, 0, 55)
	relay.captured_by = null
	relay.candidate = null
	relay.progress = 0
	_units(human, "Worker")[0].global_position = relay.global_position + Vector3(1, 0, 0)
	var drone = game._spawn("Drone", human, relay.global_position)
	drone.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	await _frames(630)
	_check(relay.captured_by == null and relay.progress == 0, "Worker/aircraft captured relay")


func _full_mission():
	var human = game._get_human_player()
	_check(
		game.phase == 0 and not human.basic_programs_unlocked(), "Mission started after lab lesson"
	)
	await _frames(120)
	_check(game.waves_sent == 0, "Learning phase spawned timed attacks")
	var lab = load("res://source/match/units/CommandLab.tscn").instantiate()
	var factions = load("res://source/match/FactionCatalog.gd")
	human.subtract_resources(factions.cost(human, "CommandLab", true))
	game._setup_and_spawn_unit(lab, Transform3D(Basis(), Vector3(23, 0, 8)), human, true)
	_units(human, "Worker")[0].issue_manual_order(
		load("res://source/match/units/actions/Constructing.gd").new(lab)
	)
	for frame in range(4500):
		await process_frame
		if game.phase == 1:
			break
	_check(lab.is_constructed() and game.phase == 1, "Actual construction did not advance tutorial")
	var repair = _units(human, "RepairRobot")[0]
	load("res://source/match/orders/UnitBehavior.gd").guard(repair, Vector3(41, 0, 38))
	await _frames(35)
	_check(game.phase == 2, "Guard did not satisfy behavior lesson")
	for unit in human.get_children():
		if "type" in unit and unit.type in ["Tank", "Infantry"]:
			unit.issue_manual_order(
				load("res://source/match/units/actions/AttackMoving.gd").new(Vector3(42, 0, 40))
			)
	for frame in range(9000):
		await process_frame
		if game.finished:
			break
	_check(
		game.finished and game.result == "Victory",
		"Built-in behavior mission did not win: " + game.objective_text()
	)
	_check(game.waves_sent == 3, "Full mission did not exercise all response waves")
	var time = game.simulation_time
	var waves = game.waves_sent
	await _frames(60)
	_check(
		game.simulation_time == time and game.waves_sent == waves,
		"Victory continued simulation or waves"
	)
	var saved = Progress.new()
	_check(
		saved.read_progress(path) and saved.complete and not saved.doctrine_badge,
		"Victory was not recorded independently of optional badge"
	)


func _defeat():
	var hq = _units(game._get_human_player(), "CommandCenter")[0]
	hq.hp = 0
	await _frames(120)
	_check(game.command_left < 60 and not game.finished, "HQ loss did not grant rebuild window")
	var left = game.command_left
	paused = true
	await _frames(40)
	_check(game.command_left == left, "HQ defeat countdown advanced while paused")
	paused = false
	var replacement = load("res://source/match/units/CommandCenter.tscn").instantiate()
	game._setup_and_spawn_unit(
		replacement, Transform3D(Basis(), Vector3(14, 0, 15)), game._get_human_player(), true
	)
	await _frames(3)
	_check(game.command_left < left, "Incomplete HQ reset defeat timer")
	replacement.construct(1.0)
	await _frames(3)
	_check(game.command_left == 60.0 and not game.finished, "Completed HQ did not restore command")
	replacement.hp = 0
	await _frames(120)
	await _frames(3550)
	_check(game.finished and game.result == "Defeat", "HQ recovery expiry did not lose")


func _progress_integrity():
	var store = Progress.new()
	_check(
		store.record_victory(true, path) and store.record_victory(false, path),
		"Badge persistence write failed"
	)
	_check(store.doctrine_badge, "Replay erased an earned badge")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken progress")
	file.close()
	_check(not store.record_victory(true, path), "Corrupt campaign progress was overwritten")
	_check(
		FileAccess.get_file_as_string(path) == "broken progress",
		"Corrupt progress was not retained"
	)


func _units(player, role):
	return player.get_children().filter(
		func(unit):
			return "type" in unit and unit.type == role and not unit.is_queued_for_deletion()
	)


func _frames(count):
	for frame in range(count):
		await process_frame


func _check(value, message):
	if not value:
		errors.append(message)
