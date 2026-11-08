extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var batch = load("res://source/match/rendering/ParallelPoseBatch.gd").new()
	var native = load("res://source/match/rendering/NativePosePacker.gd").create()
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		_sparse_muzzles(native)
		var target = _spawn("Tank", 1, Vector3(45, 0, 35))
		var pairs := []
		var presentations := []
		for role in MOBILE_ROLES + ["AntiGroundTurret", "AntiAirTurret", "CommandLab"]:
			var seed = _game._visual_serial
			var reference = _spawn(role, 0, Vector3(30, 0, 30))
			_game._visual_serial = seed
			var candidate = _spawn(role, 0, Vector3(30, 0, 30))
			var direct = reference.get_node("BastionVisuals")
			var visual = candidate.get_node("BastionVisuals")
			if visual._track_motion != null:
				for belt in visual._track_motion.belts:
					_check(
						belt.mesh.get_instance_shader_parameter("track_travel") == 0.0,
						"Track instance shader path was not prepared before movement"
					)
			var anchors: Array[Node3D] = [candidate.get_node("Geometry")]
			for node in candidate.get_node("Geometry").find_children("*", "Node3D", true, false):
				anchors.append(node)
			direct.gpu_interpolated = true
			visual.set_gpu_interpolation(true, anchors, native)
			if "--native-presentation" in OS.get_cmdline_user_args():
				var presentation = ClassDB.instantiate("CopperfinPresentationBatch")
				_check(presentation.configure(anchors.size() + 1), "Presentation capacity rejected")
				var handle: int = presentation.bind_unit(
					candidate,
					candidate.get_node("Geometry"),
					anchors,
					visual._pose_hierarchy.job.native_rig,
					1,
					20.0
				)
				_check(handle >= 0, "Same-frame presentation candidate did not bind")
				visual.set_native_presentation(presentation, handle)
				presentations.append(presentation)
			var original := []
			for anchor in anchors:
				original.append(anchor.transform)
			var references: Array[Node3D] = [reference.get_node("Geometry")]
			for node in reference.get_node("Geometry").find_children("*", "Node3D", true, false):
				references.append(node)
			_check(references.size() == anchors.size(), "Reference model topology differs")
			pairs.append([reference, candidate, direct, visual, anchors, original, references])
		for step in 75:
			var jobs := []
			var world_jobs := []
			for pair in pairs:
				for unit in pair.slice(0, 2):
					if step < 30:
						unit.position += Vector3(.02, 0, -.04)
						unit.rotation.y += .01
					if step == 12:
						unit.aim_target = target
					if step == 50:
						unit.aim_target = null
					if step == 60:
						unit.position += Vector3(10, 0, 5)
				var direct = pair[2]
				var visual = pair[3]
				direct.prepare_gpu_pose(STEP).solve()
				direct.finish_gpu_pose(STEP)
				visual.prepare_gpu_pose(STEP).solve()
				if visual._pose_worker != null:
					visual._pose_worker.begin()
				visual.finish_gpu_pose(STEP, false)
				if visual._pose_worker != null:
					jobs.append(visual._pose_worker.job)
			batch.solve(jobs, true, 1)
			for pair in pairs:
				var visual = pair[3]
				if visual._pose_worker != null:
					visual._pose_worker.end()
				visual.publish_gpu_pose(STEP)
				if step in [18, 35]:
					pair[2].fire_recoil()
					visual.fire_recoil()
				for unit in pair.slice(0, 2):
					if unit.type == "CommandLab":
						unit.player.coordination_left = 10.0
						unit.get_node("StructureActivity").refresh(STEP)
				world_jobs.append(visual._pose_hierarchy.job)
			batch.solve(world_jobs, true, 1)
			for pair in pairs:
				var visual = pair[3]
				var hierarchy = visual._pose_hierarchy
				for index in pair[4].size():
					var anchor = pair[4][index]
					var path = pair[1].get_path_to(anchor)
					var expected: Transform3D = pair[6][index].global_transform
					_check(
						hierarchy.job.palette[index].is_equal_approx(expected),
						"World pose differs: %s %s %s step=%d" % [faction, pair[1].type, path, step]
					)
					if (
						index == 0
						and (visual._track_motion != null or not visual._scrap_plates.is_empty())
					):
						# Native deforming tracks/scrap share the model root beside the
						# rigid batch. That root must follow the published body pose.
						_check(
							anchor.global_transform.is_equal_approx(hierarchy.job.palette[0]),
							"Native detail root lost its pose: " + pair[1].type
						)
					else:
						_check(
							anchor.transform == pair[5][index],
							"Pose wrote back to SceneTree: %s %s" % [pair[1].type, path]
						)
				if visual._projectile_origin != null and (step in [18, 35] or visual._aiming):
					_check(
						visual._projectile_origin.global_transform.is_equal_approx(
							pair[2]._projectile_origin.global_transform
						),
						"Weapon socket differs: " + pair[1].type
					)
				if native != null and step == 35:
					var entries = [
						{
							"anchors": pair[4],
							"poses": hierarchy.job.palette,
							"offset": 0,
							"shown": true,
							"pulse": Color(0, 0, 0, 0)
						}
					]
					var packed: PackedByteArray = native.pack_poses(entries, pair[4].size())
					_check(
						is_equal_approx(packed.decode_float(12), hierarchy.job.palette[0].origin.x),
						"Native packing used stale node pose"
					)
		for pair in pairs:
			var expected = pair[3]._pose_hierarchy.job.palette.duplicate()
			pair[3].set_native_presentation(null, -1)
			pair[3].set_gpu_interpolation(false)
			_check(
				pair[1].get_node("Geometry").top_level == pair[0].get_node("Geometry").top_level,
				"Fallback lost the authored root transform mode"
			)
			for index in pair[4].size():
				_check(
					pair[4][index].global_transform.is_equal_approx(expected[index]),
					"Fallback lost current pose"
				)
			pair[0].queue_free()
			pair[1].queue_free()
		await _close()
		presentations.clear()
	for message in _errors:
		push_error(message)
	print("Decoupled pose regression: %d failures across 3 factions and 15 roles" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _sparse_muzzles(native):
	# Production palettes contain mesh anchors, not every descendant socket.
	# Alternating weapons must bind both sockets even when neither is an anchor.
	for role in MOBILE_ROLES:
		var reference = _spawn(role, 0, Vector3(30, 0, 30))
		var candidate = _spawn(role, 0, Vector3(30, 0, 30))
		var direct = reference.get_node("BastionVisuals")
		var visual = candidate.get_node("BastionVisuals")
		if visual._paired_muzzles.is_empty():
			reference.free()
			candidate.free()
			continue
		var anchors: Array[Node3D] = [candidate.get_node("Geometry")]
		visual.set_gpu_interpolation(true, anchors, native)
		var bound := true
		for muzzle in visual._paired_muzzles:
			bound = bound and visual._pose_hierarchy._bindings.has(muzzle)
		_check(bound, "Sparse palette omitted an alternating muzzle: " + role)
		if bound:
			for shot in 4:
				reference.rotation.y = shot * .3
				candidate.rotation.y = reference.rotation.y
				direct.fire_recoil()
				visual.fire_recoil()
				_check(
					visual._projectile_origin.global_transform.is_equal_approx(
						direct._projectile_origin.global_transform
					),
					"Sparse palette changed an alternating shot origin: " + role
				)
		visual.set_gpu_interpolation(false)
		reference.free()
		candidate.free()
