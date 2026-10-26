extends "res://tests/headless/UnitAnimationRegression.gd"


## Solver-only CPU timings. This is not a gameplay/FPS acceptance benchmark.
func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var native = load("res://source/match/rendering/NativePosePacker.gd").create()
	_check(native != null and native.has_method("solve_infantry_batch"), "Native solver missing")
	if not _errors.is_empty():
		await root.get_node("Globals").quit_game(1)
		return
	await _fixture("bastion")
	var worker_type = load("res://source/match/rendering/InfantryPoseWorker.gd")
	var workers := []
	var jobs := []
	for index in 100:
		var role = ["Infantry", "RocketInfantry", "SniperInfantry", "AssaultInfantry", "Hero"][
			index % 5
		]
		var unit = _spawn(role, 0, Vector3(20, 0, 20))
		var motion = InfantryMotionScript.new()
		motion.setup(unit, 0.0, role)
		var worker = worker_type.new(motion)
		workers.append(worker)
		jobs.append(worker.job)
	var batch = load("res://source/match/rendering/ParallelPoseBatch.gd").new()
	var results := {}
	for mode in ["native", "script_serial", "script_parallel"]:
		var samples := PackedFloat64Array()
		for step in 220:
			for job in jobs:
				job.configure(STEP, .04 if step % 40 < 20 else 0.0, step * STEP, .2, .1, 1.0)
			var started := Time.get_ticks_usec()
			if mode == "native":
				_check(
					native.solve_infantry_batch(jobs) == jobs.size(), "Native micro batch fell back"
				)
			else:
				batch.solve(jobs, mode == "script_parallel", 16)
			var elapsed := (Time.get_ticks_usec() - started) / 1000.0
			if step >= 20:
				samples.append(elapsed)
		var total := 0.0
		for sample in samples:
			total += sample
		results[mode] = {"mean_ms": total / samples.size()}
	print(
		"INFANTRY_SOLVER_MICRO ",
		JSON.stringify({"units": 100, "iterations": 200, "results": results})
	)
	for worker in workers:
		worker.release()
	await _close()
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)
