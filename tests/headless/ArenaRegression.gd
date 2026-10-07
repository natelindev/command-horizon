extends SceneTree

const Record = preload("res://source/match/programs/ProgramRecord.gd")
const Rules = preload("res://source/match/programs/VisualRules.gd")
var errors = []


func _initialize():
	create_timer(450).timeout.connect(
		func():
			push_error("Arena test timed out")
			quit(1)
	)
	_run.call_deferred()


func _run():
	_report_integrity()
	var session = load("res://source/match/programs/arena/ArenaSession.gd").new()
	root.add_child(session)
	for faction in ["bastion", "helix", "frontier"]:
		for index in range(7):
			session.faction = faction
			session.role = "RepairRobot" if index == 6 else "Tank"
			session.case_index = index
			var doc = Rules.starter(4 if index == 6 else (3 if index == 1 else 1))
			if index in [3, 5]:
				doc.rules = [Rules.rule("always", "move_anchor")]
			session.record = Record.visual("Arena fixture", 1, doc, [session.role])
			session.start()
			var result = await session.completed
			if session.game.subtitles != null:
				errors.append("Voiceless arena attached battle subtitles")
			print(
				"ARENA ",
				faction,
				" ",
				index,
				" ",
				JSON.stringify(result.checks),
				" ",
				result.get("error")
			)
			if not result.passed:
				errors.append("Scenario failed: %s %d" % [faction, index])
	# A working but behaviorally wrong script must fail, not receive a blanket approval.
	session.case_index = 0
	session.role = "Tank"
	session.record = Record.visual("Wrong behavior", 1, Rules.starter(0), ["Tank"])
	session.start()
	var wrong = await session.completed
	if wrong.passed:
		errors.append("Hold incorrectly passed retreat scenario")
	# Every programmable body must accept manual takeover, including air navigation.
	for unit_role in Record.ROLES:
		session.case_index = 4
		session.role = unit_role
		session.record = Record.visual("Role authority", 1, Rules.starter(0), [unit_role])
		session.start()
		var authority = await session.completed
		if not authority.passed:
			errors.append("Manual scenario failed for " + unit_role)
	# Runtime-only faults must produce a failed, bounded result and still allow takeover.
	session.role = "Tank"
	session.record = Record.lua(
		"Fault", 1, "return function(s,m) while true do end end", ["Tank"], ["movement"]
	)
	session.start()
	var fault = await session.completed
	if fault.passed or not "budget" in fault.error or fault.trace.size() > 180:
		errors.append("Runtime fault missing from arena result")
	if not fault.checks[2].passed or not fault.checks[3].passed:
		errors.append("Faulting arena program prevented manual takeover")
	# A stale handle is safely rejected by the host, but still fails the behavior test.
	session.case_index = 2
	session.record = Record.lua(
		"Stale target",
		1,
		(
			"return function(s,m) if #s.enemies>0 then m.id=s.enemies[1].id end "
			+ "return {intent=m.id and {kind='attack',target=m.id} or {kind='hold'},state=m} end"
		),
		["Tank"],
		["movement", "attack"]
	)
	session.start()
	var stale = await session.completed
	if stale.passed or not session.facts.get("stale_attack", false):
		errors.append("Stale attack request incorrectly passed")
	session.queue_free()
	await process_frame
	for message in errors:
		push_error(message)
	if errors.is_empty():
		print(
			"PASS: seven arena cases, three factions; all-role authority; wrong/stale/faulting programs fail"
		)
	quit(0 if errors.is_empty() else 1)


func _report_integrity():
	var bridge = load("res://source/match/programs/arena/ArenaBridge.gd").new()
	bridge.directory = ProjectSettings.globalize_path(
		"user://arena-report-%d" % OS.get_process_id()
	)
	bridge.token = "fixture-token"
	bridge.content_hash = "fixture-hash"
	DirAccess.make_dir_recursive_absolute(bridge.directory)
	if bridge._read_report().ok:
		errors.append("Missing report accepted")
	var report = {
		"token": bridge.token,
		"content_hash": bridge.content_hash,
		"results": [{"passed": true, "error": "", "checks": [{"passed": true, "text": "Observed"}]}]
	}
	var candidates = [
		report.duplicate(true),
		report.duplicate(true),
		report.duplicate(true),
		report.duplicate(true)
	]
	candidates[1].token = "another run"
	candidates[2].content_hash = "another draft"
	candidates[3].results[0].checks = ["malformed check"]
	for index in range(candidates.size()):
		var file = FileAccess.open(bridge.directory.path_join("report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(candidates[index]))
		file.close()
		if bridge._read_report().ok != (index == 0):
			errors.append("Report identity/shape validation failed: %d" % index)
	bridge.cleanup()
	bridge.free()
