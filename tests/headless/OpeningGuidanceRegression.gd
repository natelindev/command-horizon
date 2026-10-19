extends "res://tests/headless/SupplyLineRegression.gd"

var guidance


func _load_guidance():
	guidance = load("res://source/match/campaign/OpeningGuidance.gd")


func _run():
	_load_guidance()
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://opening-guidance-%d.json" % OS.get_process_id()
	await _make_match()
	paused = true
	var truck = game.convoy[0].unit
	truck.hp = truck.hp_max * .4
	_check("Repair support" in game.convoy_guidance(), "Damaged convoy lacks repair guidance")
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
	game.phase = 2
	_check(guidance.first_orders(game).title == "CAPTURE THE RELAY", "Capture step missing")
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
	quit(0 if errors.is_empty() else 1)
