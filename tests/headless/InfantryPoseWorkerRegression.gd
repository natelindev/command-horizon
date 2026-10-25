extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var worker_type = load("res://source/match/rendering/InfantryPoseWorker.gd")
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
		for step in 40:
			var jobs := []
			var distance := .04 if step < 20 else 0.0
			var aiming := 1.0 if step >= 10 else 0.0
			for fixture in fixtures:
				var worker = fixture[3]
				worker.begin()
				fixture[2].advance(STEP, distance, step * STEP, .2, .1, aiming)
				worker.job.motion.advance(STEP, distance, step * STEP, .2, .1, aiming)
				jobs.append(worker.job)
			batch.solve(jobs, true, 16)
			for fixture in fixtures:
				var worker = fixture[3]
				worker.end()
				if step == 12:
					fixture[2].raise_for_shot()
					worker.job.motion.raise_for_shot()
				worker.publish()
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
