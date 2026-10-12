extends SceneTree

var errors = []


func _initialize():
	_run.call_deferred()


func _run():
	await _test_match_settings_doctrine()
	await _test_program_telemetry_badge()
	await _test_ai_program_arming()

	print("Tier 4 programmable USP regression: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _test_match_settings_doctrine():
	var MatchSettingsScript = load("res://source/data-model/MatchSettings.gd")
	var settings = MatchSettingsScript.new()
	_check(settings.tactical_doctrine == "balanced", "Default tactical doctrine is not balanced")

	settings.tactical_doctrine = "kiting"
	_check(settings.tactical_doctrine == "kiting", "Failed to assign kiting doctrine")

	settings.tactical_doctrine = "ironclad"
	_check(settings.tactical_doctrine == "ironclad", "Failed to assign ironclad doctrine")
	print("PASS Match settings tactical doctrine data model")


func _test_program_telemetry_badge():
	var BadgeScript = load("res://source/match/hud/UnitProgramBadge3D.gd")
	var dummy_unit = Node3D.new()
	var dummy_script = GDScript.new()
	dummy_script.source_code = "extends Node3D\nvar radius = 1.5\nvar type = \"Drone\"\nsignal action_changed"
	dummy_script.reload()
	dummy_unit.set_script(dummy_script)

	var prog = load("res://source/match/programs/UnitProgram.gd").new()
	prog.name = "UnitProgram"
	dummy_unit.add_child(prog)
	root.add_child(dummy_unit)

	var badge = BadgeScript.new()
	dummy_unit.add_child(badge)
	badge.setup(dummy_unit, prog)

	prog.config = {"preset": "kite"}
	prog.mode = "Running"
	badge._update_text()
	_check(badge.text == "⚙ [KITE]", "Badge text mismatch for preset kite: got " + badge.text)

	# Simulate evaluated signal
	prog.evaluated.emit({}, {"intent": {"kind": "retreat"}})
	_check(badge.text == "⚙ [RETREAT]", "Badge text did not update on evaluated signal: got " + badge.text)

	dummy_unit.queue_free()
	print("PASS In-match 3D program telemetry badge and live evaluation updates")


func _test_ai_program_arming():
	var ai = load("res://source/match/players/skirmish-ai/SkirmishAI.gd").new()
	ai.difficulty = 1  # Normal difficulty
	ai.faction = "helix"
	root.add_child(ai)

	var combat_robot = Node3D.new()
	var dummy_script = GDScript.new()
	dummy_script.source_code = "extends Node3D\nvar radius = 1.2\nvar type = \"CombatRobot\"\nsignal action_changed"
	dummy_script.reload()
	combat_robot.set_script(dummy_script)

	var prog = load("res://source/match/programs/UnitProgram.gd").new()
	prog.name = "UnitProgram"
	combat_robot.add_child(prog)
	ai.add_child(combat_robot)

	ai._arm_units_with_programs([combat_robot])
	_check(prog.installed, "AI failed to install program chip on CombatRobot")
	_check(prog.config.get("preset", "") == "fire_support", "AI failed to configure fire_support preset on CombatRobot")

	ai.queue_free()
	print("PASS Autonomous AI unit programming and doctrine arming")


func _check(condition: bool, message: String):
	if not condition:
		errors.append(message)
		print("FAIL: " + message)
		push_error(message)
