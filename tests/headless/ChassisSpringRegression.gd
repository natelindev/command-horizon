extends SceneTree

const Chassis = preload("res://source/match/units/traits/ChassisMotion.gd")
const Profile = preload("res://source/match/units/traits/UnitMotionProfile.gd")
var failures := []


func _initialize():
	_run.call_deferred()


func _run():
	for kind in Chassis.Kind.values():
		var reference = _sample(kind, 240)
		for fps in [15, 30, 60, 144]:
			var actual = _sample(kind, fps)
			for index in actual.size():
				_check(
					is_finite(actual[index]) and absf(actual[index] - reference[index]) < .00001,
					(
						"Spring depends on display cadence: kind=%d fps=%d component=%d"
						% [kind, fps, index]
					)
				)
		var single = _motion(kind)
		single._smoothing(.5)
		single._integrate(.5)
		var split = _motion(kind)
		for step in 30:
			split._smoothing(1.0 / 60.0)
			split._integrate(1.0 / 60.0)
		var one = _state(single)
		var many = _state(split)
		for index in one.size():
			_check(absf(one[index] - many[index]) < .00001, "Long frame changed spring response")
		_check(
			absf(single.pitch) + absf(single.roll) + absf(single.heave) > .0001,
			"Impulse animation was lost"
		)
		var before = _state(single)
		single.advance(0.0, Transform3D.IDENTITY)
		single.advance(-.01, Transform3D.IDENTITY)
		_check(before == _state(single), "Nonpositive time changed the pose")
	for message in failures:
		push_error(message)
	print(
		"Chassis spring cadence, long-frame and impulse regression: ", failures.size(), " failures"
	)
	quit(0 if failures.is_empty() else 1)


func _motion(kind):
	var motion = Chassis.new()
	motion.configure(kind, Profile.new(712), 4.0, 2.0)
	motion.reset(Transform3D.IDENTITY)
	motion._root_yaw = .25
	motion.accel = Vector2(.25, -.3)
	motion.forward_speed = 2.0
	motion.impulse(Vector3(.3, 0, .5), 1.0)
	return motion


func _sample(kind, fps):
	var motion = _motion(kind)
	for frame in fps:
		motion._smoothing(1.0 / fps)
		motion._integrate(1.0 / fps)
	return _state(motion)


func _state(motion):
	return [
		motion.yaw_lag,
		motion._visual_rate,
		motion.pitch,
		motion.pitch_velocity,
		motion.roll,
		motion.roll_velocity,
		motion.heave,
		motion.heave_velocity
	]


func _check(condition, message):
	if not condition:
		failures.append(message)
