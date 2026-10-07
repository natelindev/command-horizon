extends SceneTree

const Runtime = preload("res://source/match/programs/LuaRuntime.gd")
const HOLD = """return function(s,m)
    m.ticks=(m.ticks or 0)+1
    return {intent={kind='hold'},state=m}
end"""
var _errors = []


func _initialize():
	call_deferred("_run")


func _run():
	_check(Runtime.available(), "Native Lua class not loaded")
	if not Runtime.available():
		quit(1)
		return
	var first = Runtime.new()
	var second = Runtime.new()
	_check(first.compile_source(HOLD).ok and second.compile_source(HOLD).ok, "Compile failed")
	for _i in range(3):
		_check(first.step({}).ok, "State step failed")
	_check(second.step({}).ok, "Second VM failed")
	_check(first.state_snapshot().ticks == 3, "Explicit state not retained")
	_check(second.state_snapshot().ticks == 1, "Unit states not isolated")
	var copy = first.state_snapshot()
	copy.ticks = 99
	_check(first.state_snapshot().ticks == 3, "State leaked by reference")
	_check(not first.compile_source("return function(").ok, "Bad edit accepted")
	_check(first.step({}).ok and first.state_snapshot().ticks == 4, "Bad edit replaced runtime")
	_check(first.resume().ok and first.step({}).ok, "Clean Resume failed")
	_check(first.state_snapshot().ticks == 1, "Resume retained old memory")
	var mutation = Runtime.new()
	_check(
		(
			mutation
			. compile_source(
				"return function(s,m) s.self.hp=0; return {intent={kind='hold'},state=s} end"
			)
			. ok
		),
		"Snapshot mutation fixture failed"
	)
	var snapshot = {"self": {"hp": 100}}
	_check(mutation.step(snapshot).ok and snapshot.self.hp == 100, "Script mutated engine input")
	_fault("return function() while true do end end", "budget")
	_fault("return function() local t={} for i=1,100000 do t[i]=i end return t end", "memory")
	_fault(
		"return function() return {intent={kind='move',assignment='enemy_hq'},state={}} end", "Move"
	)
	_fault("return function() return {intent={kind='build'},state={}} end", "Intent")
	_fault(
		"return function() return {intent={kind='attack',target=1.5},state={}} end", "contact ID"
	)
	_fault(
		"return function() return {intent={kind='hold',path='/tmp'},state={}} end", "Unsupported"
	)
	_fault("return function() local t={} t.a=t return {intent={kind='hold'},state=t} end", "Cyclic")
	_fault("return function() return {intent={kind='hold'},state={x=1/0}} end", "finite")
	_fault(
		"return function() return {intent={kind='hold'},state={x=function() end}} end", "function"
	)
	_fault(
		"""return function()
    local s='a'; for i=1,11 do s=s..s end
    local m={} for i=1,10 do m[i]=s end
    return {intent={kind='hold'},state={m=m}}
end""",
		"16 KiB"
	)
	_fault("return function() return {intent={kind='hold'},state={bad='\\255'}} end", "UTF-8")
	_fault("return function() return {intent={kind='hold'},state={bad='a\\0b'}} end", "NUL")
	var native = ClassDB.instantiate("RtsLuaSandbox")
	_check(not native.compile_source("a".repeat(32769)).ok, "Oversized source accepted")
	_check(native.compile_source(HOLD).ok, "Input guard fixture failed")
	var object = RefCounted.new()
	_check(not native.step({"engine": object}, {}).ok, "Engine object crossed input bridge")
	_check(native.compile_source(HOLD).ok, "Input cycle fixture failed")
	var cyclic = {}
	cyclic.self = cyclic
	_check(not native.step(cyclic, {}).ok, "Input cycle accepted")
	cyclic.clear()
	_check(
		native.compile_source("return function() return {x={3,1,2},unicode='指令 🤖'} end").ok,
		"Array fixture failed"
	)
	var output = native.step({}, {})
	_check(
		output.ok and output.value.x == [3, 1, 2] and output.value.unicode == "指令 🤖",
		"Array or UTF-8 bridge broken"
	)
	await _benchmark()
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			"PASS: Lua engine bridge, isolation, immutable input, budgets, result guards, clean Resume"
		)
	quit(0 if _errors.is_empty() else 1)


func _fault(source, expected):
	var runtime = Runtime.new()
	var compiled = runtime.compile_source(source)
	_check(compiled.ok, "Fixture did not compile: " + source)
	if not compiled.ok:
		return
	var result = runtime.step({})
	_check(not result.ok and expected in result.get("error", ""), "Expected fault: " + expected)
	_check(runtime.suspended and not runtime.step({}).ok, "Fault auto-restarted")


func _benchmark():
	var runtimes = []
	var source = """return function(s,m)
    local best=nil
    for _,e in ipairs(s.enemies) do
        if best==nil or e.hp<best.hp then best=e end
    end
    m.ticks=(m.ticks or 0)+1
    return {intent={kind='attack',target=best.id},state=m}
end"""
	for _index in range(200):
		var runtime = Runtime.new()
		_check(runtime.compile_source(source).ok, "Benchmark compile failed")
		runtimes.append(runtime)
	var snapshot = {"enemies": []}
	for index in range(32):
		snapshot.enemies.append({"id": index + 1, "hp": 100 - index, "x": index, "z": 0})
	var start = Time.get_ticks_usec()
	var peak = 0
	for _step in range(5):
		for runtime in runtimes:
			var result = runtime.step(snapshot)
			_check(result.ok and result.intent.target == 32, "Benchmark targeting failed")
			peak = maxi(peak, runtime.metrics.get("peak_memory_bytes", 0))
	var elapsed = (Time.get_ticks_usec() - start) / 1000.0
	print(
		"LUA BENCH: 200 VMs x 5 evaluations, 32 contacts; total_ms=",
		elapsed,
		" peak_VM_bytes=",
		peak
	)
	await process_frame


func _check(condition, message):
	if not condition:
		_errors.append(message)
