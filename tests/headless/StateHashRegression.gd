extends SceneTree

const Values = preload("res://source/match/saves/SaveValue.gd")
const Protocol = preload("res://source/match/network/NetworkProtocol.gd")
var _frame
var _native
var _errors = []


func _initialize():
	_run.call_deferred()


func _run():
	_frame = load("res://source/match/network/AuthoritativeFrame.gd")
	# Packet helpers must prepare the backend on the main thread even on a Mac
	# with no experimental simulation/render flags, before their first worker job.
	var builder = load("res://source/match/network/PacketBuilder.gd").new()
	var reader = load("res://source/match/network/PacketReader.gd").new()
	_native = builder._native_hasher
	_check(
		(reader._native_hasher != null) == (_native != null), "Reader backend differs from builder"
	)
	if "--enable-native-kernels" in OS.get_cmdline_user_args():
		_check(_native != null, "Native state hasher did not activate")
	var controls = ""
	for code in range(1, 32):
		controls += String.chr(code)
	var state = {
		"camera": {"invalid_but_ignored": Vector2.INF},
		"unicode": '中文 🛰 é é / \\"\n' + controls,
		"values":
		[
			null,
			true,
			false,
			0,
			-1,
			9223372036854775807,
			-9223372036854775807 - 1,
			0.0,
			-0.0,
			1.0,
			1.0e-300,
			1.0e300,
			PI,
			Vector3(-0.0, .1, -9.25),
			Color(.1, .2, .3, .4),
			[],
			{},
			""
		],
		"nested": {&"z": 9, "A": 2, &"a": [{"camera": 3}], "中": 1, "😀": 4}
	}
	_compare(state, "all supported values")
	var hash_value = _frame.hash_state(state)
	state.camera = null
	_check(_frame.hash_state(state) == hash_value, "Root camera changed the checksum")
	state.nested.a[0].camera = 4
	_check(_frame.hash_state(state) != hash_value, "Nested camera was omitted")
	state.nested.a[0].camera = 3
	var reordered = {}
	var keys = state.keys()
	keys.reverse()
	for key in keys:
		reordered[StringName(key)] = state[key]
	_compare(reordered, "reordered StringName keys")
	var typed_names: Dictionary[StringName, int] = {&"z": 1, &"a": 2}
	var typed_strings: Dictionary[String, int] = {"z": 1, "a": 2}
	_compare({"typed": typed_names}, "typed StringName keys")
	_compare({"typed": typed_strings}, "typed String keys")
	_check(_frame.hash_state(reordered) == hash_value, "Key representation/order changed hash")
	_check(_frame.hash_state({"n": 1}) != _frame.hash_state({"n": 1.0}), "Number types collided")
	# GDScript can deduplicate equal +0/-0 constants; construct the IEEE bits.
	var negative_zero = "0000000000000080".hex_decode().decode_double(0)
	_check(
		_frame.hash_state({"n": 0.0}) != _frame.hash_state({"n": negative_zero}),
		"Signed zero was normalized"
	)
	_compare({"n": negative_zero}, "signed zero bits")
	_check(
		_frame.hash_state({"list": [1, 2]}) != _frame.hash_state({"list": [2, 1]}),
		"Array order was normalized"
	)
	var random = RandomNumberGenerator.new()
	random.seed = 912714
	for index in 100:
		var sample = {}
		for item in 25:
			sample["key_%d" % random.randi_range(0, 100)] = [
				random.randi(),
				random.randf_range(-10000, 10000),
				Vector3(random.randf(), random.randf(), random.randf()),
				{&"nested": item}
			]
		_compare(sample, "random sample %d" % index)
	for invalid in [INF, NAN, Vector3.INF, Color(INF, 0, 0), Vector2.ZERO, &"value", {1: 2}]:
		_invalid({"bad": invalid}, "unsupported/nonfinite value")
	_invalid({"large": "x".repeat(Values.MAX_STRING_BYTES + 1)}, "oversized string")
	_invalid({"x".repeat(Values.MAX_STRING_BYTES + 1): 1}, "oversized key")
	var nested = []
	for depth in Values.MAX_DEPTH + 1:
		nested = [nested]
	_invalid({"nested": nested}, "excessive nesting")
	var cycle = []
	cycle.append(cycle)
	_invalid({"cycle": cycle}, "cyclic input")
	cycle.clear()
	var many = []
	many.resize(Values.MAX_NODES)
	_invalid({"many": many}, "excessive item count")
	state.make_read_only()
	_compare(state, "read-only input")
	var tasks = []
	var jobs = []
	for index in 4:
		var job = {"state": state.duplicate(true), "expected": hash_value, "ok": false}
		jobs.append(job)
		tasks.append(WorkerThreadPool.add_task(_worker.bind(job)))
	for task in tasks:
		while not WorkerThreadPool.is_task_completed(task):
			await process_frame
		WorkerThreadPool.wait_for_task_completion(task)
	for job in jobs:
		_check(job.ok, "Concurrent detached worker hashing changed results")
	for message in _errors:
		push_error(message)
	print(
		(
			"State hash parity, bounds and workers: %d failures; native=%s"
			% [_errors.size(), _native != null]
		)
	)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _worker(job):
	job.ok = true
	for iteration in 20:
		if _frame.hash_state(job.state) != job.expected:
			job.ok = false


func _compare(state, label):
	var before = var_to_bytes(state)
	var comparable = state.duplicate(true)
	comparable.erase("camera")
	# Keep the original three-pass implementation as an independent oracle.
	var expected = Protocol.canonical_hash(Values.new().encode(_canonical(comparable)))
	var values = Values.new()
	var encoded = values.encode_canonical(state, "camera")
	_check(values.error.is_empty(), label + ": portable encoder failed")
	_check(Protocol.canonical_hash(encoded) == expected, label + ": portable hash changed")
	if _native != null:
		_check(_native.hash_state(state) == expected, label + ": native hash changed")
	_check(_frame.hash_state(state) == expected, label + ": dispatch hash changed")
	_check(var_to_bytes(state) == before, label + ": hashing mutated input")


func _canonical(value):
	if value is Dictionary:
		var keys = value.keys().map(func(key): return str(key))
		keys.sort()
		var result = {}
		for key in keys:
			result[key] = _canonical(value[key])
		return result
	if value is Array:
		return value.map(_canonical)
	return value


func _invalid(state, label):
	if _native != null:
		_check(_native.hash_state(state).is_empty(), label + ": native accepted invalid input")
	var values = Values.new()
	values.encode_canonical(state, "camera")
	_check(not values.error.is_empty(), label + ": portable encoder accepted invalid input")
	_check(_frame.hash_state(state).is_empty(), label + ": invalid input produced a checksum")


func _check(condition, message):
	if not condition:
		_errors.append(message)
