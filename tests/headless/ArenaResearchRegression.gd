extends "res://tests/headless/ArenaRegression.gd"

var session_path = "res://source/match/programs/arena/ArenaSession.gd"
var profile = {
	"coordination": true,
	"completed": ["weapons_1", "weapons_2", "armor_1", "armor_2", "service", "doctrine"]
}


func _run():
	_integrity()
	for faction in ["bastion", "helix", "frontier"]:
		for upgraded in [false, true]:
			var session = load(session_path).new()
			root.add_child(session)
			session.faction = faction
			session.role = "Tank"
			session.case_index = 4
			session.record = Record.visual("Research authority", 1, Rules.starter(0), ["Tank"])
			var expected = (
				profile.duplicate(true) if upgraded else {"coordination": false, "completed": []}
			)
			if "research" in session:
				session.research = expected.duplicate(true)
			await session.start()
			var unit = session.subject
			var factor = 1.2 if upgraded else 1.0
			_check(
				is_equal_approx(unit.hp_max, unit.base_hp_max * factor),
				faction + ": arena armor differs from research setup"
			)
			_check(
				is_equal_approx(unit.player.technology.damage_factor(unit.type), factor),
				faction + ": arena weapon research missing"
			)
			_check(unit.player.coordination_unlocked == upgraded, "Arena Coordination differs")
			var target = session._spawn(
				"Tank",
				session.game.get_node("Players").get_child(1),
				unit.position + Vector3(3, 0, 0)
			)
			target.process_mode = Node.PROCESS_MODE_DISABLED
			var damage = load("res://source/match/combat/CombatRules.gd").damage(unit, target)
			var hp = target.hp
			target.receive_weapon_hit(unit)
			_check(
				is_equal_approx(hp - target.hp, damage),
				"Arena weapon hit did not use researched damage"
			)
			var result = await session.completed
			_check(result.passed, "Researched unit lost manual authority")
			_check(result.get("research", {}) == expected, "Result omitted its research setup")
			session.role = "RepairRobot"
			session.case_index = 6
			session.record = Record.visual("Research service", 1, Rules.starter(4), ["RepairRobot"])
			await session.start()
			unit = session.partner
			unit.hp = unit.hp_max * .4
			hp = unit.hp
			session.game.repair_service.service(1.0)
			var expected_heal = unit.hp_max * .025 * (1.25 if upgraded else 1.0)
			_check(
				is_equal_approx(unit.hp - hp, expected_heal),
				"Arena service rate differs from research setup"
			)
			result = await session.completed
			_check(result.passed, "Researched repair scenario failed")
			_check(result.get("research", {}) == expected, "Restart lost research evidence")
			if "research" in session:
				session._finish_error("Test failure context")
				_check(
					session.outcome.research == expected, "Failed scenario lost research context"
				)
			session.queue_free()
			await process_frame
	for message in errors:
		push_error(message)
	print("Arena research: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check(value, message):
	if not value:
		errors.append(message)


func _integrity():
	var research = load("res://source/match/programs/arena/ArenaResearch.gd")
	_check(research.valid(profile), "Complete research setup rejected")
	for broken in [
		{"coordination": true, "completed": ["unknown"]},
		{"coordination": true, "completed": ["weapons_2"]},
		{"coordination": false, "completed": ["weapons_1", "weapons_2"]},
		{"coordination": true, "completed": ["service", "service"]},
		{"coordination": true, "completed": [], "active": "weapons_1"},
		{"coordination": "true", "completed": []},
	]:
		_check(not research.valid(broken), "Malformed arena research accepted")
	var bridge = load("res://source/match/programs/arena/ArenaBridge.gd").new()
	bridge.research = {"coordination": false, "completed": ["weapons_1"]}
	var result = {
		"passed": true,
		"checks": [{"passed": true, "text": "Observed"}],
		"research": bridge.research.duplicate(true)
	}
	_check(bridge._valid_result(result), "Captured research result refused")
	result.research = research.baseline()
	_check(bridge._valid_result(result), "Unupgraded comparison result refused")
	result.research = profile.duplicate(true)
	_check(not bridge._valid_result(result), "Result invented research absent at launch")
	result.research = {"coordination": false, "completed": ["armor_1"]}
	_check(not bridge._valid_result(result), "Result substituted another legal technology")
	bridge.free()
