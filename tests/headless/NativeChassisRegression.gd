extends SceneTree

const SCALARS = [
	"forward_speed",
	"yaw_lag",
	"pitch",
	"pitch_velocity",
	"roll",
	"roll_velocity",
	"heave",
	"heave_velocity",
	"engine",
	"idle",
	"clock",
	"max_speed",
	"length",
	"_recoil_age",
	"_recoil_strength",
	"_root_yaw",
	"_root_rate",
	"_visual_yaw",
	"_visual_rate",
	"_step",
	"_velocity_weight",
	"_accel_weight",
	"_rate_weight",
	"_body_decay",
	"_body_cos",
	"_body_sin",
	"_heave_cos",
	"_heave_sin"
]
const VECTORS = ["velocity", "accel", "_recoil_direction", "_drift"]
const EXACT = ["kind", "damage_band", "damage_faction", "_started", "_floating", "_engine_driven"]
var failures := []
var comparisons := 0
var chassis_script
var profile_script
var batch_script


func _initialize():
	_run.call_deferred()


func _check(condition: bool, message: String):
	if not condition and failures.size() < 20:
		failures.append(message)


func _run():
	chassis_script = load("res://source/match/units/traits/ChassisMotion.gd")
	profile_script = load("res://source/match/units/traits/UnitMotionProfile.gd")
	batch_script = load("res://source/match/rendering/ParallelPoseBatch.gd")
	var loader = load("res://source/match/rendering/NativePosePacker.gd").create()
	if loader == null or not ClassDB.class_exists("CopperfinChassisMotion"):
		_check(false, "Native chassis implementation is required")
	else:
		if "--native-chassis-poses" in OS.get_cmdline_user_args():
			_check(
				chassis_script.create().get_class() == "CopperfinChassisMotion",
				"Requested native chassis factory fell back to script"
			)
		for kind in chassis_script.Kind.values():
			for faction in ["bastion", "helix", "frontier"]:
				_compare_motion(kind, faction)
		_compare_batch()
	for message in failures:
		push_error(message)
	print("Native chassis: %d failures across %d comparisons" % [failures.size(), comparisons])
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _motion(kind: int, native: bool):
	var motion = ClassDB.instantiate("CopperfinChassisMotion") if native else chassis_script.new()
	motion.configure(kind, profile_script.new(712 + kind), 4.0, 2.0)
	return motion


func _compare_motion(kind: int, faction: String):
	var expected = _motion(kind, false)
	var actual = _motion(kind, true)
	var poses = [expected, actual]
	_check(actual.Kind == chassis_script.Kind, "Motion kind constants differ")
	_check(actual.CANNON_RECOVERY == chassis_script.CANNON_RECOVERY, "Recoil duration differs")
	var root_pose := Transform3D.IDENTITY
	var random := RandomNumberGenerator.new()
	random.seed = 4512 + kind
	for step in 480:
		var delta: float = [1.0 / 30.0, 1.0 / 144.0, 1.0 / 15.0, .5, 0.0, -.1][step % 6]
		if step % 80 < 60:
			root_pose.origin += Vector3(random.randf_range(-.08, .08), .005, -.06)
			root_pose.basis = Basis(Vector3.UP, step * .012 + (PI if step % 120 > 60 else 0))
		if step % 101 == 0:
			root_pose.origin += Vector3(13, 5, -17)
		var impulse := Vector3(random.randf_range(-1, 1), 0, random.randf_range(-1, 1))
		for motion in poses:
			motion.damage_faction = faction
			motion.damage_band = (step / 47) % 3
			motion.idle = .7 if step % 80 > 65 else 0.0
			if step % 37 == 0:
				motion.impulse(impulse, .8)
			if step % 71 == 0:
				motion.cannon_recoil(impulse if step % 142 == 0 else Vector3.ZERO, .9)
			if step % 97 == 0:
				motion.clamp_lag(.2)
			if step % 127 == 0:
				motion.reset(root_pose)
			if step % 149 == 0:
				motion.settle()
			if step == 240:
				motion.configure(kind, profile_script.new(941 + kind), .2, 3.5)
			motion.advance(delta, root_pose)
		_compare_state(expected, actual, "%s/%d/%d" % [faction, kind, step])
		_check(
			expected.offset_rotation(.07).distance_to(actual.offset_rotation(.07)) < .00005,
			"Recoil offset rotation differs"
		)
	# Exercise writable spring state and the closed-form direct integration API.
	for motion in poses:
		motion.accel = Vector2(.25, -.3)
		motion._root_yaw = .25
		motion.forward_speed = 2.0
		motion.impulse(Vector3(.3, 0, .5), 1.0)
		motion._smoothing(.5)
		motion._integrate(.5)
	_compare_state(expected, actual, "direct spring")


func _compare_state(expected, actual, label: String):
	for field in SCALARS:
		comparisons += 1
		var value: float = actual.get(field)
		var reference: float = expected.get(field)
		_check(
			is_finite(value) and absf(value - reference) < .00005,
			"%s %s: %.9f != %.9f" % [label, field, value, reference]
		)
	for field in VECTORS:
		comparisons += 1
		_check(actual.get(field).distance_to(expected.get(field)) < .00005, label + " " + field)
	for field in EXACT:
		comparisons += 1
		_check(actual.get(field) == expected.get(field), label + " " + field)
	comparisons += 5
	_check(actual._tuning == expected._tuning, label + " tuning")
	_check(actual._previous == expected._previous, label + " previous root")
	_check(actual.is_settled() == expected.is_settled(), label + " settled state")
	_check(
		actual.offset_position().distance_to(expected.offset_position()) < .00005,
		label + " offset position"
	)
	_check(
		actual.offset_rotation().distance_to(expected.offset_rotation()) < .00005,
		label + " offset rotation"
	)


func _compare_batch():
	var actual := []
	var expected := []
	for index in 128:
		for jobs in [actual, expected]:
			var job = batch_script.Job.new()
			job.chassis = _motion(index % 6, is_same(jobs, actual) and index % 5 != 1)
			jobs.append(job)
	var batch = batch_script.new()
	for step in 120:
		for index in actual.size():
			for jobs in [actual, expected]:
				var job = jobs[index]
				job.root.origin += Vector3(.03, 0, -.04)
				job.root.basis = Basis(Vector3.UP, step * .015)
				job.delta = 1.0 / 30.0
				job.mode = 1 if step == 0 else ((index + step) % 4)
		batch.solve(expected, false)
		batch.solve(actual, true)
		for index in actual.size():
			_compare_state(
				expected[index].chassis, actual[index].chassis, "batch/%d/%d" % [step, index]
			)
	_check(batch.last_worker_count == 0, "Small scripted remainder dispatched unnecessary workers")
	# A script-first mixed batch uses the existing worker path. Native bodies
	# must remain identical when their methods run on disjoint workers.
	actual.push_front(actual.pop_at(1))
	expected.push_front(expected.pop_at(1))
	batch.solve(expected, false)
	batch.solve(actual, true)
	for index in actual.size():
		_compare_state(expected[index].chassis, actual[index].chassis, "mixed workers/%d" % index)
