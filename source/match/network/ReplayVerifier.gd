# gdlint: disable=max-returns
extends Node

signal completed

## This verifier starts from the recording once, then runs actual gameplay
## commands against the fixed server tick. It never feeds recorded state back
## into the simulation. Floating navigation differences are reported explicitly.
const Archive = preload("res://source/match/network/ReplayFile.gd")
const Frame = preload("res://source/match/network/AuthoritativeFrame.gd")
const Values = preload("res://source/match/saves/SaveValue.gd")

var report = {}
var _session
var _commands = {}
var _frames = {}
var _tick = 0
var _end = 0
var _running = false
var _archive
var _expected_state = {}


func verify(tree: SceneTree, path: String) -> Dictionary:
	_commands.clear()
	_frames.clear()
	_expected_state.clear()
	_running = false
	var archive = Archive.new()
	_archive = archive
	report = {
		"ok": false,
		"commands": 0,
		"frames": 0,
		"divergences": 0,
		"first_divergence": {},
		"error": ""
	}
	if (
		not archive.open_read(path)
		or archive.header.get("protocol") != 1
		or archive.header.get("tick_rate") != 60
	):
		report.error = (
			archive.error if archive.error != "" else "Unsupported replay simulation contract."
		)
		archive.close()
		return report
	var initial = Values.new().decode(archive.header.get("initial"))
	if not initial is Dictionary or not Frame.new().validate(initial):
		report.error = "Invalid initial simulation state."
		archive.close()
		return report
	for index in archive.records.size():
		var entry = archive.records[index]
		if entry.kind == Archive.COMMAND:
			var command = archive.read_record(index)
			if (
				not command.get("slot") is int
				or not command.get("result") is bool
				or not load("res://source/match/network/NetworkProtocol.gd").new().valid_intent(
					command.get("intent")
				)
			):
				report.error = "Invalid recorded command."
				archive.close()
				return report
			if not _commands.has(entry.tick):
				_commands[entry.tick] = []
			_commands[entry.tick].append(command)
		elif entry.kind == Archive.FRAME:
			_frames[entry.tick] = index
	_end = archive.footer.tick
	_expected_state = initial
	_session = load("res://source/match/network/NetworkSession.gd").create(tree)
	_session.use_fixed_clock()
	_session.set_physics_process(false)
	var restore = load("res://source/match/saves/MatchRestore.gd").new()
	var loaded = await restore.restore(tree, initial)
	if not loaded.ok:
		report.error = loaded.error
		_session.shutdown()
		_session.queue_free()
		archive.close()
		return report
	_session.authority = true
	_session.local_slot = 0
	_session.game = loaded.game
	_session.set_physics_process(false)
	loaded.game.set_meta("network_session", _session)
	for id in restore.entities:
		var entity = restore.entities[id]
		if id.begins_with("unit-") or id.begins_with("resource-") or id.begins_with("obstacle-"):
			entity.set_meta("network_id", id)
	_session.registry.entities = restore.entities.duplicate()
	for timer in loaded.game.find_children("*", "Timer", true, false):
		timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	for side in loaded.game.get_cached_group("players"):
		if side != loaded.game._get_human_player():
			side.set_process(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100001
	_tick = 0
	_compare()
	_running = true
	var initial_time = loaded.game.simulation_time
	tree.paused = false
	await completed
	tree.paused = true
	report.physics_hz = Engine.physics_ticks_per_second
	report.authority_hz = _session.boundary.TICKS_PER_SECOND
	report.clock_ticks = _tick
	report.simulation_seconds = loaded.game.simulation_time - initial_time
	if (
		report.physics_hz != report.authority_hz
		or absf(report.simulation_seconds - _tick / 60.0) > .001
	):
		report.error = "Input re-simulation world and authority clocks differ."
	report.ok = report.divergences == 0 and report.error.is_empty()
	archive.close()
	report.final_hash = Frame.hash_state(_session.registry.capture(loaded.game))
	_session.shutdown()
	loaded.game.queue_free()
	_session.queue_free()
	await tree.process_frame
	return report


func _physics_process(_delta):
	if not _running:
		return
	_tick += 1
	for command in _commands.get(_tick, []):
		var result = _session.router.apply(command.slot, command.intent)
		report.commands += 1
		if result != command.result:
			_divergence("command", str(command.result), str(result))
	if _frames.has(_tick):
		_compare()
	if _tick >= _end:
		_running = false
		completed.emit()


func _compare():
	if not _frames.has(_tick):
		return
	var packet = _archive.read_record(_frames[_tick])
	var data = Values.new().decode(packet.state)
	_expected_state = data if packet.full else Frame.apply_delta(_expected_state, data)
	var snapshot = _session.registry.capture(_session.game)
	var actual = Frame.hash_state(snapshot)
	report.frames += 1
	if actual != packet.hash:
		_divergence("state", packet.hash, actual)
		if not report.first_divergence.has("field"):
			report.first_divergence.field = _difference(_expected_state, snapshot, "")


func _divergence(kind: String, expected: String, actual: String):
	report.divergences += 1
	if report.first_divergence.is_empty():
		report.first_divergence = {
			"tick": _tick, "kind": kind, "expected": expected, "actual": actual
		}


func _difference(expected, actual, path: String) -> String:
	if typeof(expected) != typeof(actual):
		return path + " type " + str(typeof(expected)) + " / " + str(typeof(actual))
	if expected is Dictionary:
		for key in expected:
			if key == "camera":
				continue
			if not actual.has(key):
				return path + "." + key + " missing"
			var difference = _difference(expected[key], actual[key], path + "." + key)
			if not difference.is_empty():
				return difference
		return ""
	if expected is Array:
		if expected.size() != actual.size():
			return path + " size " + str(expected.size()) + " / " + str(actual.size())
		for index in expected.size():
			var difference = _difference(expected[index], actual[index], path + "[%d]" % index)
			if not difference.is_empty():
				return difference
		return ""
	return "" if expected == actual else path + " " + str(expected) + " / " + str(actual)
