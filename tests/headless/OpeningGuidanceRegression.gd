extends "res://tests/headless/SupplyLineRegression.gd"

var guidance


func _load_guidance():
	guidance = load("res://source/match/campaign/OpeningGuidance.gd")


func _check_localized_guidance(actual, expected, message, values = []):
	var previous_locale = TranslationServer.get_locale()
	for locale in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		var translated = TranslationServer.translate(expected)
		if not values.is_empty():
			translated = translated % values
		_check(actual.call() == translated, "%s (%s)" % [message, locale])
	TranslationServer.set_locale(previous_locale)


func _run():
	_load_guidance()
	var bindings = load("res://source/input/KeyBindings.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://opening-guidance-%d.json" % OS.get_process_id()
	await _make_match()
	paused = true
	var truck = game.convoy[0].unit
	truck.hp = truck.hp_max * .4
	_check_localized_guidance(
		func(): return game.convoy_guidance(),
		"Truck badly damaged. Select Repair support, then right-click the truck before advancing.",
		"Damaged convoy lacks repair guidance"
	)
	_check(not game.hud._repair.disabled, "Available repair support cannot be selected")
	game.hud._repair.pressed.emit()
	_check(
		get_nodes_in_group("selected_units").all(func(unit): return unit.type == "RepairRobot"),
		"Repair shortcut selects unrelated escorts"
	)
	game.queue_free()
	await _frames(5)
	paused = false
	# Create First Orders using the shared campaign fixture rather than the convoy override.
	var fixture = load("res://source/data-model/MatchSettings.gd").new()
	fixture.skirmish = true
	fixture.mission_id = "first_orders"
	fixture.map_path = "res://source/match/maps/FirstOrdersMap.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		fixture.players.append(side)
	game = load("res://source/match/campaign/FirstOrders.tscn").instantiate()
	game.settings = fixture
	game.map = load(fixture.map_path).instantiate()
	game.progress_path = path
	root.add_child(game)
	current_scene = game
	await _frames(40)
	paused = true
	var human = game._get_human_player()
	human.resource_a = 0
	_check(
		guidance.first_orders(game).title == "GATHER MATERIALS",
		"Material shortage lacks next action"
	)
	human.resource_a = 100
	human.resource_b = 0
	_check(
		guidance.first_orders(game).title == "GATHER ELECTRONICS",
		"Electronics shortage lacks next action"
	)
	human.resource_b = 100
	_check(
		guidance.first_orders(game).title == "BUILD THE COMMAND LAB",
		"Funded lab instruction missing"
	)
	var lab = load("res://source/match/units/CommandLab.tscn").instantiate()
	game._setup_and_spawn_unit(lab, Transform3D(Basis(), Vector3(12, 0, 25)), human, true)
	await _frames(3)
	_check(
		guidance.first_orders(game).title == "FINISH THE COMMAND LAB",
		"Existing foundation prompts duplicate lab"
	)
	game.phase = 1
	_check(guidance.first_orders(game).role == "Tank", "Behavior lesson selects wrong role")
	_check_localized_guidance(
		func(): return guidance.practical_tip(game),
		(
			"Direct orders take control immediately. Hold %s when choosing a destination "
			+ "to queue the next order."
		),
		"Behavior lesson omits manual-order authority",
		[bindings.label("shift_selecting")]
	)
	game.phase = 2
	_check(guidance.first_orders(game).title == "CAPTURE THE RELAY", "Capture step missing")
	_check_localized_guidance(
		func(): return guidance.practical_tip(game),
		(
			"Use Attack move (%s) for the approach so troops stop to fight. Use Move (%s) for "
			+ "a retreat that takes priority over fighting."
		),
		"Capture approach lacks attack-move guidance",
		[bindings.label("attack_move"), bindings.label("move_order")]
	)
	var tanks = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Tank"
	)
	var hurt_tank = tanks[0]
	hurt_tank.hp = hurt_tank.hp_max * .4
	_check_localized_guidance(
		func(): return guidance.practical_tip(game),
		(
			"Preserve your veterans: move wounded troops behind your line, then choose Recover health. "
			+ "Repair support restores vehicles between fights."
		),
		"Wounded troops lack contextual recovery guidance"
	)
	hurt_tank.hp = hurt_tank.hp_max
	game.relay.captured_by = human
	game.relay.contested = true
	_check(
		guidance.first_orders(game).title == "CLEAR THE RELAY", "Contested relay guidance missing"
	)
	game.relay.contested = false
	_check(guidance.first_orders(game).title == "DEFEND THE RELAY", "Hold step missing")
	game.result = "Victory"
	_check("infantry" in guidance.debrief(game), "Victory lacks a practical next step")
	game.result = "Defeat"
	_check("engineer" in guidance.debrief(game), "Defeat lacks recovery guidance")
	game.phase = 1
	for tank in tanks:
		tank.queue_free()
	await _frames(3)
	var step = guidance.first_orders(game)
	_check(
		step.title == "TRAIN A TANK" and step.role == "VehicleFactory",
		"Lost armor does not lead to its production building"
	)
	game.hud._lesson_title.text = "Previous lesson"
	game.hud._lesson_scroll.scroll_vertical = 50
	game.hud._process(.21)
	_check(
		game.hud._lesson_text.text.begins_with(TranslationServer.translate(step.text)),
		"Optional hint precedes the required lesson instruction"
	)
	_check(game.hud._lesson_scroll.scroll_vertical == 0, "New lesson retained old scroll offset")
	game.hud._find_unit()
	var selected = get_nodes_in_group("selected_units")
	_check(
		not selected.is_empty() and selected.all(func(unit): return unit.type == "VehicleFactory"),
		"Replacement armor shortcut does not select a vehicle factory"
	)
	for unit in human.get_children():
		if "type" in unit and unit.type == "VehicleFactory":
			unit.queue_free()
	await _frames(3)
	step = guidance.first_orders(game)
	_check(
		step.title == "REBUILD THE VEHICLE FACTORY" and step.role == "Worker",
		"Missing vehicle factory does not lead to an engineer"
	)
	var foundation = load("res://source/match/units/VehicleFactory.tscn").instantiate()
	game._setup_and_spawn_unit(foundation, Transform3D(Basis(), Vector3(24, 0, 15)), human, true)
	await _frames(3)
	step = guidance.first_orders(game)
	_check(
		step.title == "FINISH THE VEHICLE FACTORY" and step.role == "Worker",
		"Vehicle factory foundation incorrectly prompts training or duplicate construction"
	)
	var ready_factory = game._spawn("VehicleFactory", human, Vector3(30, 0, 15))
	game.hud._find_unit()
	_check(
		get_nodes_in_group("selected_units") == [ready_factory],
		"Training shortcut selects a foundation before an available factory"
	)
	ready_factory.queue_free()
	for unit in human.get_children():
		if "type" in unit and unit.type == "Worker":
			unit.queue_free()
	await _frames(3)
	_check(
		guidance.first_orders(game).role == "CommandCenter",
		"Lost armor and engineers do not lead to HQ training"
	)
	var before = [game.phase, game.hold_seconds, human.resource_a, human.resource_b]
	for index in 30:
		guidance.first_orders(game)
	_check(
		before == [game.phase, game.hold_seconds, human.resource_a, human.resource_b],
		"Guidance mutated mission state"
	)
	paused = false
	game.queue_free()
	await _frames(5)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	for message in errors:
		push_error(message)
	print("Opening guidance: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
