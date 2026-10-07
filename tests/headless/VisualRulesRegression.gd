extends "res://tests/headless/LuaAuthoringRegression.gd"

const Rules = preload("res://source/match/programs/VisualRules.gd")
const Runtime = preload("res://source/match/programs/LuaRuntime.gd")


func _library_records():
	super()
	_compiler_validation()
	_compiled_behavior()
	var library = Library.new()
	DirAccess.remove_absolute(_path)
	var visual = Record.visual("Visual guard", 1, Rules.starter(1), Record.ARMED)
	_check(Record.validate(visual), "Valid visual record rejected")
	var first = library.save_record(visual, _path)
	_check(first != null, "Visual source save failed: " + library.error)
	if first == null:
		return
	_check(library.read_library(_path), "Visual JSON round-trip failed: " + library.error)
	var read = library.find_version(first.name, 1)
	_check(
		read.source == visual.source and read.content_hash == visual.content_hash,
		"Saved graph/source changed"
	)
	var altered = visual.duplicate(true)
	altered.source += "\n-- hidden edit"
	Record.seal(altered)
	_check(not Record.validate(altered), "Resealed visual source bypassed compiler integrity")
	altered = visual.duplicate(true)
	altered.rules.rules[0].action = "hold"
	Record.seal(altered)
	_check(not Record.validate(altered), "Changed graph accepted stale generated source")
	var next = visual.duplicate(true)
	next = Record.visual("Visual guard", 1, Rules.starter(2), Record.ROLES)
	library.save_record(next, _path)
	var snapshot = Factory.snapshot(Record.pin(first), "Tank", _path)
	_check(snapshot.record.source == visual.source, "Factory followed newest visual graph")
	_check(
		Factory.snapshot(Record.pin(first), "Drone", _path).notice != "",
		"Visual attack program accepted unarmed role"
	)
	var invalid = Record.visual("Conflict", 1, Rules.starter(1), ["RepairRobot"])
	_check(not Record.validate(invalid), "Visual record claimed unsupported equipment")
	DirAccess.remove_absolute(_path)


func _compiler_validation():
	for index in range(Rules.STARTERS.size()):
		var doc = Rules.starter(index)
		var compiled = Rules.compile(doc)
		_check(compiled.ok, "Starter rules failed to compile")
		var parsed = JSON.parse_string(JSON.stringify(doc))
		_check(
			Rules.compile(parsed).source == compiled.source,
			"Compilation changed after JSON round-trip"
		)
		var runtime = Runtime.new()
		_check(runtime.compile_source(compiled.source).ok, "Generated Lua failed initialization")
		_check(runtime.step(_snapshot()).ok, "Generated Lua failed sample execution")
	var bad = Rules.starter(0)
	bad.parameters.recover = 35
	_check(not Rules.compile(bad).ok, "Invalid recovery accepted")
	bad = Rules.starter(0)
	bad.rules[0].action = "hold'; os.execute('bad')"
	_check(not Rules.compile(bad).ok, "Untrusted action text compiled")
	bad = Rules.starter(0)
	bad.rules[0].value = INF
	_check(not Rules.compile(bad).ok, "Nonfinite threshold compiled")
	bad = Rules.starter(0)
	bad.rules = []
	_check(not Rules.compile(bad).ok, "Empty graph compiled")
	for index in range(13):
		bad.rules.append(Rules.rule())
	_check(not Rules.compile(bad).ok, "Rule cap exceeded")
	bad = Rules.starter(0)
	bad.initial_state = "unexpected"
	_check(not Rules.compile(bad).ok, "Unknown state compiled")
	# Exercise every supported condition/action path against the actual interpreter.
	for condition in Rules.CONDITIONS:
		for action in Rules.ACTIONS:
			var doc = Rules.starter(0)
			doc.rules = [Rules.rule(condition, action, Rules.range_for(condition).x)]
			var compiled = Rules.compile(doc)
			var runtime = Runtime.new()
			_check(
				compiled.ok and runtime.compile_source(compiled.source).ok,
				"Rule combination failed: " + condition + "/" + action
			)
			_check(runtime.step(_snapshot()).ok, "Rule emitted invalid intent: " + action)


func _snapshot():
	return {
		"api_version": 1,
		"time": 0.0,
		"contacts_truncated": false,
		"self":
		{"type": "Tank", "hp": 100, "hp_max": 100, "position": {"x": 0, "z": 0}, "attack_range": 5},
		"assignments":
		{
			"anchor": {"x": 0, "z": 0},
			"safe": {"x": -5, "z": 0},
			"route_a": {"x": 0, "z": 0},
			"route_b": {"x": 10, "z": 0}
		},
		"enemies":
		[
			{"id": 1, "hp": 100, "hp_max": 100, "distance": 2, "can_attack": true},
			{"id": 2, "hp": 20, "hp_max": 100, "distance": 4, "can_attack": true}
		],
		"allies":
		[{"id": 3, "hp": 30, "hp_max": 100, "can_repair": true, "position": {"x": 1, "z": 0}}]
	}


func _compiled_behavior():
	var runtime = Runtime.new()
	var legacy = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/legacy-visual-guard.json")
	)
	_check(Record.validate(legacy), "Legacy guard record lost compiler/source compatibility")
	var document = legacy.rules.duplicate(true)
	runtime.compile_source(Rules.compile(document).source)
	var snapshot = _snapshot()
	var starter_runtime = Runtime.new()
	starter_runtime.compile_source(Rules.compile(Rules.starter(1)).source)
	_check(
		starter_runtime.step(snapshot).intent.kind == "guard",
		"New guard starter does not defend its area"
	)
	_check(
		Rules.assignments(Rules.starter(1)) == ["Safe point", "Area"],
		"Guard starter lacks explicit assignments"
	)
	var result = runtime.step(snapshot)
	_check(
		result.intent.kind == "attack" and result.intent.target == 1,
		"Guard chose wrong nearest target"
	)
	snapshot.self.hp = 20
	_check(runtime.step(snapshot).intent.assignment == "safe", "Retreat rule did not win priority")
	snapshot.self.hp = 50
	_check(
		runtime.step(snapshot).intent.assignment == "safe", "Retreat hysteresis returned too early"
	)
	snapshot.self.hp = 80
	_check(runtime.step(snapshot).intent.kind == "attack", "Recovery did not release retreat")
	snapshot.self.position.x = 8
	_check(runtime.step(snapshot).intent.assignment == "anchor", "Guard ignored distance rule")
	snapshot.assignments.erase("anchor")
	_check(
		runtime.step(snapshot).intent.assignment == "anchor", "Missing anchor guessed a destination"
	)
	snapshot = _snapshot()
	document.rules[3].action = "attack_weakest"
	runtime.compile_source(Rules.compile(document).source)
	_check(runtime.step(snapshot).intent.target == 2, "Weakest target priority failed")
	snapshot.enemies.clear()
	_check(
		runtime.step(snapshot).intent.kind == "hold", "Hidden target persisted across evaluation"
	)
	document = Rules.starter(4)
	runtime.compile_source(Rules.compile(document).source)
	snapshot.allies.append(
		{"id": 4, "hp": 1, "hp_max": 100, "can_repair": true, "position": {"x": 7, "z": 0}}
	)
	_check(runtime.step(snapshot).intent.target == 3, "Out-of-area ally blocked legal repair")
	snapshot.allies[0].position.x = 7
	_check(runtime.step(snapshot).intent.kind == "hold", "Repair rule left assigned area")
	document = Rules.starter(2)
	runtime.compile_source(Rules.compile(document).source)
	_check(runtime.step(snapshot).intent.assignment == "route_b", "Patrol did not leave start")
	snapshot.self.position.x = 10
	_check(runtime.step(snapshot).intent.assignment == "route_a", "Patrol did not switch ends")
	snapshot.assignments.erase("route_b")
	_check(runtime.step(snapshot).intent.assignment == "route_b", "Missing route point was guessed")
	# State changes affect the following tick, never fall through within one tick.
	document = Rules.starter(0)
	var enter = Rules.rule("hp_below", "move_safe", 30)
	enter.state = "normal"
	enter.next_state = "regroup"
	var wait = Rules.rule("always", "hold")
	wait.state = "regroup"
	document.rules = [enter, wait]
	runtime.compile_source(Rules.compile(document).source)
	snapshot.self.hp = 20
	_check(runtime.step(snapshot).intent.kind == "move", "State transition fell through")
	_check(runtime.step(snapshot).intent.kind == "hold", "Named state was not retained")
	runtime.resume()
	_check(runtime.step(snapshot).intent.kind == "move", "Resume did not reset visual state")
	# Reordering the same cards deliberately changes the first applicable action.
	document = Rules.starter(0)
	document.rules = [Rules.rule("always", "hold"), Rules.rule("always", "escort")]
	runtime.compile_source(Rules.compile(document).source)
	_check(runtime.step(snapshot).intent.kind == "hold", "First rule did not win")
	document.rules.reverse()
	runtime.compile_source(Rules.compile(document).source)
	_check(runtime.step(snapshot).intent.kind == "escort", "Rule order had no effect")


func _application_and_factory(player):
	await super(player)
	var tank = _spawn("Tank", player, Vector3(40, 0, 30), true)
	tank.process_mode = Node.PROCESS_MODE_INHERIT
	var visual = Record.visual("Visual guard", 1, Rules.starter(1), Record.ARMED)
	var result = Application.apply(visual, [tank], player)
	_check(
		result.ok and tank.program.saved_record.mode == "visual", "Visual Apply lost authoring mode"
	)
	await _frames(35)
	_check(
		tank.program.mode == "Waiting",
		"Unassigned visual guard did not wait: %s / %s" % [tank.program.mode, tank.program.reason]
	)
	tank.program.anchor = tank.global_position_yless
	tank.program.safe_point = Vector3(36, 0, 30)
	tank.program.run()
	await _frames(35)
	_check(tank.program.mode == "Running", "Assigned visual guard did not run")
	tank.hp = tank.hp_max * 0.2
	await _frames(35)
	_check(
		tank.program.lua_runtime.state_snapshot().get("retreating", false),
		"Live visual unit did not enter recovery"
	)
	tank.issue_manual_order(null)
	var state = tank.program.lua_runtime.state_snapshot()
	await _frames(30)
	_check(
		tank.program.mode == "Manual" and tank.program.lua_runtime.state_snapshot() == state,
		"Visual program ignored direct order"
	)
	DirAccess.remove_absolute(_path)
	var library = Library.new()
	var saved = library.save_record(visual, _path)
	var snapshot = Factory.snapshot(Record.pin(saved), "CombatRobot", _path)
	DirAccess.remove_absolute(_path)
	var robot = _spawn("CombatRobot", player, Vector3(44, 0, 30))
	robot.process_mode = Node.PROCESS_MODE_INHERIT
	Factory.apply_to(robot, snapshot)
	await _frames(35)
	_check(
		robot.program.saved_record.mode == "visual" and robot.program.mode == "Waiting",
		(
			"Factory visual inheritance lost exact graph: %s / %s"
			% [robot.program.mode, robot.program.reason]
		)
	)
	_check(robot.program.lua_source == visual.source, "Factory generated source changed")
	if _errors.is_empty():
		print(
			(
				"PASS: visual compiler/graph integrity, priorities/hysteresis/states/patrol; "
				+ "%s live Apply/manual/factory" % player.faction
			)
		)
