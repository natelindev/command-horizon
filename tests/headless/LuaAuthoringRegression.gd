extends "res://tests/headless/ProgramRegression.gd"

const Record = preload("res://source/match/programs/ProgramRecord.gd")
const Application = preload("res://source/match/programs/ProgramApplication.gd")
const Factory = preload("res://source/match/programs/FactoryProgram.gd")
const HOLD = (
	"return function(s, state) state.ticks = (state.ticks or 0) + 1; "
	+ "return {intent = {kind = 'hold'}, state = state} end"
)
var _path = "user://lua-authoring-%d.json" % OS.get_process_id()


func _run():
	_library_records()
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
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
		await _application_and_factory(player)
		await _clear()
	DirAccess.remove_absolute(_path)
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: Lua record migration/integrity/version isolation; "
				+ "both-faction atomic apply/manual/pause; exact factory source/fallback/rally; "
				+ "isolated sample checks"
			)
		)
	quit(0 if _errors.is_empty() else 1)


func _write(data):
	var file = FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _library_records():
	DirAccess.remove_absolute(_path)
	var library = Library.new()
	_write(
		{
			"schema": 1,
			"versions": [{"name": "Legacy", "version": 1, "config": Library.defaults("guard")}]
		}
	)
	var original = FileAccess.get_file_as_bytes(_path)
	_check(library.read_library(_path), "Legacy library failed to load")
	_check(
		library.versions.size() == 1 and Record.validate(library.versions[0]),
		"Legacy migration lost metadata"
	)
	_check(FileAccess.get_file_as_bytes(_path) == original, "Read modified legacy file")
	var draft = Record.lua("Watch", 1, HOLD, Record.ROLES, ["movement"])
	_check(Record.validate(draft), "Valid Lua record rejected")
	var first = library.save_record(draft, _path)
	_check(first != null and first.version == 1, "Lua save failed: " + library.error)
	if first == null:
		return
	var other = Library.new()
	other.read_library(_path)
	var changed = draft.duplicate(true)
	changed.source += "\n-- second"
	Record.seal(changed)
	var second = library.save_record(changed, _path)
	var third = other.save_record(draft, _path)
	_check(second.version == 2 and third.version == 3, "Concurrent editor lost version")
	_check(other.versions.size() == 4, "Migration lost existing preset")
	_check(other.find_version("Watch", 1).source == HOLD, "Earlier source changed")
	_check(
		first.id == second.id and first.source_hash != second.source_hash,
		"Unstable identity or source hash"
	)
	var copy = other.find_version("Watch", 1)
	copy.roles.clear()
	_check(not other.find_version("Watch", 1).roles.is_empty(), "Lookup aliases library")
	_check(
		Factory.snapshot(Record.pin(first), "Drone", _path).record.source == HOLD,
		"Factory followed latest source"
	)
	var corrupt = first.duplicate(true)
	corrupt.source += "\n-- tampered"
	_check(not Record.validate(corrupt), "Changed source accepted")
	_write({"schema": 2, "versions": [corrupt]})
	original = FileAccess.get_file_as_bytes(_path)
	_check(not library.read_library(_path), "Corrupt record accepted")
	_check(library.save_record(draft, _path) == null, "Bad library overwritten")
	_check(FileAccess.get_file_as_bytes(_path) == original, "Corrupt file not preserved")
	for field in ["api_version", "version", "roles", "requirements", "parameter_schema"]:
		var bad = first.duplicate(true)
		bad[field] = {
			"api_version": 1.5,
			"version": 2.5,
			"roles": ["Worker"],
			"requirements": ["repair"],
			"parameter_schema": {"hidden": "data"}
		}[field]
		Record.seal(bad)
		_check(not Record.validate(bad), "Invalid field accepted: " + field)
	var oversized = Record.lua("Too big", 1, "x".repeat(32769), Record.ROLES, ["movement"])
	_check(not Record.validate(oversized), "Oversized source accepted")
	_write({"schema": 2, "versions": [first, first]})
	_check(not library.read_library(_path), "Duplicate exact version accepted")
	DirAccess.remove_absolute(_path)
	library.save_record(first, _path)
	var altered = first.duplicate(true)
	altered.source += "\n-- external replacement with valid hash"
	Record.seal(altered)
	_write({"schema": 2, "versions": [altered]})
	_check(
		Factory.snapshot(Record.pin(first), "Tank", _path).notice != "",
		"Pinned hash mismatch followed changed file"
	)
	DirAccess.remove_absolute(_path)
	for kind in ["hold", "guard", "repair"]:
		var source = FileAccess.get_file_as_string("res://assets/programs/%s.lua" % kind)
		var check = load("res://source/match/programs/LuaDraftCheck.gd").check(
			source, "RepairRobot" if kind == "repair" else "Tank"
		)
		_check(check.ok, "Starter failed samples: " + kind)


func _application_and_factory(player):
	var factories = player.get_children().filter(
		func(unit): return "type" in unit and unit.type == "VehicleFactory"
	)
	var factory = factories[0]
	var tank = _spawn("Tank", player, Vector3(30, 0, 30), true)
	var second = _spawn("Tank", player, Vector3(33, 0, 30), true)
	var scout = _spawn("Drone", player, Vector3(35, 0, 30))
	var no_chip = _spawn("Tank", player, Vector3(37, 0, 30))
	var foreign = _spawn("Tank", _enemy if player == _human else _human, Vector3(60, 0, 60), true)
	var selection = [tank, second, scout, no_chip, foreign]
	for unit in selection:
		unit.issue_manual_order(
			load("res://source/match/units/actions/Moving.gd").new(Vector3(31, 0, 35))
		)
	var actions = selection.map(func(unit): return unit.action)
	var params = [
		{"name": "threshold", "label": "Threshold", "value": 30, "min": 1, "max": 90, "step": 1}
	]
	var prefix = load("res://source/match/programs/llm/DraftResponse.gd").parameter_prefix(params)
	var draft = Record.lua("Combat watch", 1, prefix + HOLD, Record.ARMED, ["movement", "attack"])
	draft.parameter_schema = load("res://source/match/programs/LuaParameters.gd").schema(params)
	Record.seal(draft)
	var preview = Application.preview(draft, selection, player)
	_check(
		preview.eligible.size() == 2 and preview.incompatible == 2 and preview.unready == 1,
		"Wrong mixed-role preview"
	)
	var bad = draft.duplicate(true)
	bad.source = "while true do end"
	Record.seal(bad)
	var rejected = Application.apply(bad, selection, player)
	_check(not rejected.ok, "Faulty initialization applied")
	for index in range(selection.size()):
		_check(selection[index].action == actions[index], "Bad draft changed order")
	paused = true
	var applied = Application.apply(draft, selection, player)
	_check(applied.ok and applied.applied == 2 and applied.skipped == 3, "Mixed apply failed")
	for index in range(2, selection.size()):
		_check(selection[index].action == actions[index], "Ineligible unit lost manual order")
	tank.process_mode = Node.PROCESS_MODE_INHERIT
	second.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(10)
	_check(
		tank.program.mode == "Ready" and tank.program.lua_runtime.state_snapshot().is_empty(),
		"Paused application executed"
	)
	paused = false
	await _frames(30)
	_check(
		(
			tank.program.mode == "Running"
			and tank.program.lua_runtime.state_snapshot().get("ticks", 0) > 0
		),
		"Applied program never ran"
	)
	_check(tank.program.lua_runtime != second.program.lua_runtime, "Units share a VM")
	tank.issue_manual_order(null)
	await _frames(20)
	_check(tank.program.mode == "Manual", "Lua ignored manual hold")
	_check(not tank.program.saved_record.has("anchor"), "Record captured live assignment")
	DirAccess.remove_absolute(_path)
	var library = Library.new()
	var saved = library.save_record(draft, _path)
	var queue = factory.production_queue
	queue.program_library_path = _path
	queue.program_pin = Record.pin(saved)
	player.resource_a = 1000
	player.resource_b = 1000
	var job = queue.produce(load(Catalog.scene_path("CombatRobot")))
	_check(
		job != null and job.program_snapshot.record.source == draft.source,
		"Queue did not capture Lua"
	)
	var replacement = draft.duplicate(true)
	replacement.source += "\n-- later version"
	Record.seal(replacement)
	var later = library.save_record(replacement, _path)
	queue.program_pin = Record.pin(later)
	DirAccess.remove_absolute(_path)
	job.time_left = 0
	queue._process(0.1)
	await _frames(30)
	var produced = player.get_children().filter(
		func(unit): return "type" in unit and unit.type == "CombatRobot" and unit not in _fixtures
	)
	_check(
		produced.size() == 1 and produced[0].program.lua_source == draft.source,
		"Factory lost queued source after deletion"
	)
	if produced.size() == 1:
		_check(produced[0].program.saved_record.version == 1, "Factory followed later version")
		_check(
			(
				Record._canonical(produced[0].program.saved_record.parameter_schema)
				== Record._canonical(draft.parameter_schema)
			),
			"Factory lost parameter schema"
		)
		_check(produced[0].program.anchor == null, "Factory invented an assignment")
		_fixtures.append(produced[0])
	var stale = Factory.snapshot(Record.pin(saved), "Tank", _path)
	_check(stale.config.preset == "hold" and stale.notice != "", "Missing source has no fallback")
	var queued = {"title": "Invalid", "config": Library.defaults(), "notice": "", "record": bad}
	Factory.apply_to(second, queued)
	_check(
		second.program.lua_source.is_empty() and second.has_meta("program_fallback_reason"),
		"Compile fault has no Hold fallback"
	)

	DirAccess.remove_absolute(_path)
	library.save_record(draft, _path)
	queue.program_pin = Record.pin(draft)
	factory.get_node("RallyPoint").global_position = factory.global_position + Vector3(8, 0, 5)
	var before_rally = player.get_children()
	job = queue.produce(load(Catalog.scene_path("CombatRobot")))
	job.time_left = 0
	queue._process(0.1)
	await _frames(30)
	var rallied = player.get_children().filter(
		func(unit): return unit not in before_rally and "type" in unit
	)
	_check(rallied.size() == 1, "Rally job did not create a unit")
	if rallied.size() == 1:
		_check(
			rallied[0].program.lua_source == draft.source and rallied[0].program.mode == "Manual",
			"Queued Lua overrode rally order"
		)
		_check(
			rallied[0].program.lua_runtime.state_snapshot().is_empty(), "Lua ticked ahead of rally"
		)
		_fixtures.append(rallied[0])
