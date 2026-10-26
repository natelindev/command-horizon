extends "res://tests/headless/UnitAnimationRegression.gd"


func _check_spatial_index(native):
	if not native.has_method("index_observers"):
		return
	var field = _game.battlefield
	var enabled = field._native_index
	field._native_index = false
	field.invalidate()
	field._refresh()
	var expected = [
		field._observers.duplicate(true),
		field._bodies.duplicate(true),
		field._units.duplicate(true),
		field._max_sight,
		field._max_unit_radius,
		field._max_body_step
	]
	var actual = native.index_observers(
		_game.get_observers(), field.get_physics_process_delta_time()
	)
	_check(actual == expected, "Native grid differs for live unit stats, positions or garrison")
	field._native_index = enabled
	field.invalidate()


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var native = load("res://source/match/rendering/NativePosePacker.gd").create()
	if native == null:
		push_error("Build native kernels before running NativeContactRegression")
		quit(1)
		return
	var random := RandomNumberGenerator.new()
	random.seed = 710953
	await _fixture("bastion")
	var own = _spawn("Tank", 0, Vector3(30, 0, 30))
	var movement = own.get_node("Movement")
	var neighbors = [own]
	for role in [
		"Tank", "Worker", "CombatRobot", "Infantry", "Helicopter", "Drone", "CommandCenter"
	]:
		neighbors.append(_spawn(role, 0, own.position))
	_check(native.has_method("index_observers"), "Native spatial builder is missing")
	neighbors[4].set_meta("garrison_host", neighbors[-1])
	_check_spatial_index(native)
	neighbors[4].remove_meta("garrison_host")
	for iteration in 2500:
		var origin = Vector3(
			random.randf_range(-100, 100), random.randf_range(-5, 5), random.randf_range(-100, 100)
		)
		var next = (
			origin
			+ Vector3(
				random.randf_range(-2, 2), random.randf_range(-1, 1), random.randf_range(-2, 2)
			)
		)
		if iteration % 13 == 0:
			next = origin + Vector3.UP  # Includes negligible planar movement.
		for index in neighbors.size():
			var unit = neighbors[index]
			unit.position = (
				origin
				+ Vector3(
					random.randf_range(-3, 3), random.randf_range(-2, 2), random.randf_range(-3, 3)
				)
			)
			var agent = unit.get_node_or_null("Movement")
			if agent != null:
				agent.ghosted = (index + iteration) % 11 == 0
				unit.veterancy_speed_factor = 0.0 if (index + iteration) % 17 == 0 else 1.2
		var expected: Vector4 = movement._ground_contact_script(origin, next, neighbors)
		var actual: Vector4 = native.ground_contact(
			origin,
			next,
			neighbors,
			own,
			int(movement.domain),
			float(movement.radius),
			movement.GROUND_CONTACT_MARGIN
		)
		_check(
			actual.is_equal_approx(expected),
			"Native contact differs at sample %d: %s vs %s" % [iteration, actual, expected]
		)
		if iteration % 100 == 0:
			_check_spatial_index(native)
	# Equal-time contacts must retain the first normal in the existing traversal.
	neighbors[1].position = Vector3(2.0, 0, -.3)
	neighbors[2].position = Vector3(2.0, 0, .3)
	for unit in neighbors.slice(1, 3):
		unit.get_node("Movement").ghosted = false
		unit.get_node("Movement").radius = 1.0
		unit.veterancy_speed_factor = 1.0
	var tied = neighbors.slice(1, 3)
	var expected = movement._ground_contact_script(Vector3.ZERO, Vector3.RIGHT, tied)
	_check(
		(
			native
			. ground_contact(
				Vector3.ZERO,
				Vector3.RIGHT,
				tied,
				own,
				int(movement.domain),
				float(movement.radius),
				movement.GROUND_CONTACT_MARGIN
			)
			. is_equal_approx(expected)
		),
		"Equal-time contact ordering changed"
	)
	var script_samples := []
	var native_samples := []
	var checksum := 0.0
	for repeat in 7:
		var started := Time.get_ticks_usec()
		for index in 10000:
			checksum += movement._ground_contact_script(Vector3.ZERO, Vector3.RIGHT, tied).w
		var elapsed := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		for index in 10000:
			checksum += (
				native
				. ground_contact(
					Vector3.ZERO,
					Vector3.RIGHT,
					tied,
					own,
					int(movement.domain),
					float(movement.radius),
					movement.GROUND_CONTACT_MARGIN
				)
				. w
			)
		if repeat > 0:
			script_samples.append(elapsed / 10000.0)
			native_samples.append((Time.get_ticks_usec() - started) / 10000.0)
	script_samples.sort()
	native_samples.sort()
	print(
		"CONTACT_BENCH script_us=",
		script_samples[3],
		" native_us=",
		native_samples[3],
		" checksum=",
		checksum
	)
	await _close()
	for message in _errors:
		push_error(message)
	print("Native contact regression: %d failures, 2500 live-state comparisons" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
