extends SceneTree

var _planner
var _failures = []
var _cases = 0


func _initialize():
	call_deferred("_run")


func _run():
	_planner = load("res://source/match/orders/FormationPlanner.gd")
	var random = RandomNumberGenerator.new()
	random.seed = 961748927
	for count in [1, 2, 3, 5, 8, 16, 32, 64, 200]:
		for trial in 6:
			var origins = PackedVector3Array()
			var targets = PackedVector3Array()
			for index in count:
				origins.append(Vector3(random.randf_range(-20, 20), 0, random.randf_range(-20, 20)))
				targets.append(Vector3(random.randf_range(-20, 20), 0, random.randf_range(-20, 20)))
			_compare(origins, targets, "random %d/%d" % [count, trial])
		var origins = PackedVector3Array()
		var targets = PackedVector3Array()
		for index in count:
			origins.append(Vector3.ZERO)
			targets.append(Vector3(index % 4, 0, index / 4))
		_compare(origins, targets, "tied %d" % count)
	_compare(
		PackedVector3Array([Vector3(1e30, 0, 1e30), Vector3(-1e30, 0, -1e30)]),
		PackedVector3Array([Vector3(-9e29, 0, -9e29), Vector3(9e29, 0, 9e29)]),
		"finite extreme coordinates"
	)
	var origins = PackedVector3Array()
	var targets = PackedVector3Array()
	for index in 200:
		origins.append(Vector3(index % 20, 0, index / 20))
		# Reversed selection and target order preserve the same true optimum.
		targets.append(Vector3((199 - index) % 20, 0, (199 - index) / 20) + Vector3(3, 0, 5))
	_compare(origins, targets, "translated200")
	var started = Time.get_ticks_usec()
	for repeat in 20:
		_planner.hungarian(origins, targets)
	print("ASSIGNMENT translated200 mean_ms=", (Time.get_ticks_usec() - started) / 20000.0)
	var solver = ClassDB.instantiate("CopperfinCrowdRuntime")
	started = Time.get_ticks_usec()
	for repeat in 20:
		solver.assign_formation(origins, targets)
	print("ASSIGNMENT resident200 mean_ms=", (Time.get_ticks_usec() - started) / 20000.0)
	solver = null
	_check(ClassDB.class_exists("CopperfinCrowdRuntime"), "Native solver did not load")
	for invalid in [
		[PackedVector3Array(), PackedVector3Array()],
		[PackedVector3Array([Vector3.ZERO]), PackedVector3Array()],
		[PackedVector3Array([Vector3.ZERO]), PackedVector3Array([Vector3.ZERO, Vector3.ONE])],
		[PackedVector3Array([Vector3.INF]), PackedVector3Array([Vector3.ZERO])],
		[PackedVector3Array([Vector3.ZERO]), PackedVector3Array([Vector3(NAN, 0, 0)])],
	]:
		_check(
			_planner.hungarian(invalid[0], invalid[1]).is_empty(), "Invalid native input accepted"
		)
		_check(
			_planner._hungarian_script(invalid[0], invalid[1]).is_empty(),
			"Invalid scripted input accepted"
		)
	for message in _failures:
		push_error(message)
	print("Formation assignment: %d cases, %d failures" % [_cases, _failures.size()])
	await root.get_node("Globals").quit_game(0 if _failures.is_empty() else 1)


func _compare(origins: PackedVector3Array, targets: PackedVector3Array, label: String):
	_cases += 1
	var actual = _planner.hungarian(origins, targets)
	var oracle = _planner._hungarian_script(origins, targets)
	_check(actual.size() == origins.size(), label + ": lost assignment")
	if actual.size() != origins.size():
		return
	var unique = {}
	for column in actual:
		_check(column >= 0 and column < targets.size(), label + ": invalid column")
		unique[column] = true
	_check(unique.size() == origins.size(), label + ": duplicate column")
	var cost = _cost(origins, targets, actual)
	var expected = _cost(origins, targets, oracle)
	_check(absf(cost - expected) < .0001, "%s: cost %.9f != %.9f" % [label, cost, expected])
	if origins.size() <= 8:
		_check(
			absf(cost - _subset_optimum(origins, targets)) < .0001,
			label + ": independent subset oracle differs"
		)


func _cost(origins, targets, assignment) -> float:
	var total = 0.0
	for row in assignment.size():
		total += _distance(origins[row], targets[assignment[row]])
	return total


func _distance(first: Vector3, second: Vector3) -> float:
	var x: float = float(first.x) - float(second.x)
	var z: float = float(first.z) - float(second.z)
	return sqrt(x * x + z * z)


func _subset_optimum(origins, targets) -> float:
	var size = 1 << origins.size()
	var values = PackedFloat64Array()
	values.resize(size)
	values.fill(INF)
	values[0] = 0.0
	for mask in size:
		var row = 0
		for column in targets.size():
			row += 1 if mask & (1 << column) else 0
		if row == origins.size():
			continue
		for column in targets.size():
			if mask & (1 << column):
				continue
			var next = mask | (1 << column)
			values[next] = minf(
				values[next], values[mask] + _distance(origins[row], targets[column])
			)
	return values[-1]


func _check(condition: bool, message: String):
	if not condition:
		_failures.append(message)
