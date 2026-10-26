extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var worker_type = load("res://source/match/rendering/InfantryPoseWorker.gd")
	_check_scaled_rotation(worker_type)
	var batch = load("res://source/match/rendering/ParallelPoseBatch.gd").new()
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		var fixtures := []
		for index in 20:
			var role = ["Infantry", "RocketInfantry", "SniperInfantry", "AssaultInfantry", "Hero"][
				index % 5
			]
			var reference = _spawn(role, 0, Vector3(20, 0, 20))
			var candidate = _spawn(role, 0, Vector3(25, 0, 20))
			var direct = InfantryMotionScript.new()
			var threaded = InfantryMotionScript.new()
			direct.setup(reference, 0.0, role)
			threaded.setup(candidate, 0.0, role)
			fixtures.append([reference, candidate, direct, worker_type.new(threaded)])
		var clock := 0.0
		for step in _step_count():
			var jobs := []
			var delta := _step_delta(step)
			clock += delta
			var distance := delta * 2.4 if step % 40 < 20 else 0.0
			var aiming := 1.0 if step >= 10 else 0.0
			for fixture in fixtures:
				var worker = fixture[3]
				_configure_motion(fixture[2], worker.job.motion, step)
				worker.begin()
				fixture[2].advance(delta, distance, clock, .2, .1, aiming)
				worker.job.motion.advance(delta, distance, clock, .2, .1, aiming)
				jobs.append(worker.job)
			_solve_jobs(batch, jobs)
			for fixture in fixtures:
				var worker = fixture[3]
				worker.end()
				if step == 12:
					fixture[2].raise_for_shot()
					worker.job.motion.raise_for_shot()
				worker.publish()
				_compare_state(fixture[2], worker.job.motion, step)
				for node in worker._bindings:
					var path: NodePath = fixture[1].get_path_to(node)
					var expected: Transform3D = fixture[0].get_node(path).transform
					_check(
						node.transform.is_equal_approx(expected),
						"Worker changed gait/IK/shot pose: %s %s step=%d" % [faction, path, step]
					)
		for fixture in fixtures:
			fixture[3].release()
			_check(fixture[3].job.motion.rig is Node3D, "Fallback did not restore real rig")
		fixtures.clear()
		await _close()
	for message in _errors:
		push_error(message)
	print(
		(
			"Infantry pose worker regression: %d failures across 3 factions and 5 roles"
			% _errors.size()
		)
	)
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _step_count() -> int:
	return 40


func _step_delta(_step: int) -> float:
	return STEP


func _configure_motion(_reference, _candidate, _step: int):
	pass


func _solve_jobs(batch, jobs: Array):
	batch.solve(jobs, true, 16)


func _compare_state(_reference, _candidate, _step: int):
	pass


func _check_scaled_rotation(worker_type):
	var reference = Node3D.new()
	var proxy = worker_type.PoseTransform.new()
	for scale in [Vector3.ONE * .9, Vector3(.7, 1.3, .9), Vector3(-.7, 1.3, .9)]:
		for angles in [Vector3(.1, .7, -.2), Vector3(-.4, -.6, .3)]:
			var pose = Transform3D(Basis.from_euler(angles).scaled_local(scale), Vector3.ONE)
			reference.transform = pose
			proxy.transform = pose
			_check(proxy.rotation.is_equal_approx(reference.rotation), "Scaled proxy Euler read")
			for index in 20:
				reference.rotation.x += .02
				proxy.rotation.x += .02
				_check(
					proxy.transform.is_equal_approx(reference.transform),
					"Scaled or reflected proxy component rotation drifted"
				)
	reference.free()
