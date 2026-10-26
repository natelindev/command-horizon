extends "res://tests/headless/InfantryPoseWorkerRegression.gd"

var _native: RefCounted


func _run():
	_native = load("res://source/match/rendering/NativePosePacker.gd").create()
	if _native == null or not _native.has_method("solve_infantry_batch"):
		push_error("Native infantry pose kernel is required for this regression")
		await root.get_node("Globals").quit_game(1)
		return
	_check(_native.solve_infantry_batch([null, 1, {}]) == 0, "Invalid jobs were accepted")
	await super._run()


func _step_count() -> int:
	return 160


func _step_delta(step: int) -> float:
	return [1.0 / 120.0, STEP, 1.0 / 30.0, .1, .35][step % 5]


func _configure_motion(reference, candidate, step: int):
	for motion in [reference, candidate]:
		motion.lean = Vector2(sin(step * .1), cos(step * .2)) * .07
		motion.flinch = Vector3(.01, -.03, .02) * sin(step * .17)
		motion.turn_lead = sin(step * .13) * .8
		motion.fidget = step % 4
		motion.lead_foot = (step / 40) % 2
		if step == 0:
			motion.head.transform.basis = motion.head.transform.basis.scaled_local(
				Vector3(-1, 1, 1)
			)
		if motion._unit.suppression != null:
			motion._unit.suppression.band = 2 if step >= 80 else (1 if step >= 40 else 0)


func _solve_jobs(_batch, jobs: Array):
	var count: int = _native.solve_infantry_batch(jobs)
	_check(count == jobs.size(), "Native batch fell back: %d / %d" % [count, jobs.size()])
	for job in jobs:
		_check(job.native_solved, "Native batch did not publish a solved job")


func _compare_state(reference, candidate, step: int):
	for property in [
		"phase",
		"speed",
		"blend",
		"aim",
		"brace",
		"_start_mix",
		"_settle_time",
		"_hip_height",
		"_travel_idle",
		"_suppressed_pose",
		"_pinned_pose",
	]:
		var expected: float = reference.get(property)
		var actual: float = candidate.get(property)
		_check(
			is_equal_approx(expected, actual) or (is_inf(expected) and expected == actual),
			(
				"Native motion state changed %s at step %d: %s / %s"
				% [property, step, expected, actual]
			)
		)
	for property in ["_moving", "_settle_foot"]:
		_check(
			reference.get(property) == candidate.get(property), "Native discrete gait state changed"
		)
	for property in ["_feet", "_stance", "_start_feet", "_posed_feet"]:
		for index in 2:
			_check(
				reference.get(property)[index].is_equal_approx(candidate.get(property)[index]),
				"Native feet changed %s at step %d" % [property, step]
			)
