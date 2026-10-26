extends SceneTree

var failures := []


func _initialize():
	_run.call_deferred()


func _check(condition: bool, message: String):
	if not condition and failures.size() < 30:
		failures.append(message)


func _run():
	var packer = load("res://source/match/rendering/NativePosePacker.gd").create()
	if packer == null or not ClassDB.class_exists("CopperfinPoseRig"):
		_check(false, "Resident native pose rig is required")
	else:
		_compare(packer)
		var held = _detached_view()
		_check(held[0].get_ref() != null, "Part view lost its owning rig")
		var parent = held[1].get_parent()
		_check(parent != null and parent.index == 0, "Missing parent view could not be recreated")
		parent = null
		held[1] = null
		_check(held[0].get_ref() == null, "Native pose views retained an ownership cycle")
	for message in failures:
		push_error(message)
	print("Native pose rig: %d failures across 800 transform/hierarchy steps" % failures.size())
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _detached_view():
	var rig = ClassDB.instantiate("CopperfinPoseRig")
	rig.add_part(-1, Transform3D.IDENTITY)
	return [weakref(rig), rig.add_part(0, Transform3D.IDENTITY)]


func _compare(packer):
	var rig = ClassDB.instantiate("CopperfinPoseRig")
	var reference_proxy = (
		load("res://source/match/rendering/InfantryPoseWorker.gd").PoseTransform.new()
	)
	var nodes: Array[Node3D] = []
	var parts := []
	for index in 12:
		var node := Node3D.new()
		(root if index == 0 else nodes[(index - 1) / 2]).add_child(node)
		nodes.append(node)
		parts.append(rig.add_part(-1 if index == 0 else (index - 1) / 2, Transform3D.IDENTITY))
	var anchors := PackedInt32Array(range(12))
	_check(rig.configure_anchors(anchors), "Anchor setup failed")
	var palette: Array[Transform3D] = []
	palette.resize(12)
	var random := RandomNumberGenerator.new()
	random.seed = 787021
	for step in 800:
		var index: int = step % 12
		var rotation := Vector3(
			random.randf_range(-2, 2), random.randf_range(-3, 3), random.randf_range(-2, 2)
		)
		var position := Vector3(
			random.randf_range(-2, 2), random.randf_range(-2, 2), random.randf_range(-2, 2)
		)
		match step % 4:
			0:
				var scale := Vector3(-.8 if step % 8 == 0 else .8, 1.1, 1.2)
				var transform := Transform3D(
					Basis.from_euler(rotation).scaled_local(scale), position
				)
				nodes[index].transform = transform
				parts[index].transform = transform
			1:
				nodes[index].position = position
				parts[index].position = position
			2:
				nodes[index].rotation = rotation
				parts[index].rotation = rotation
			3:
				var basis := Basis.from_euler(rotation).scaled_local(Vector3(.7, -1.2, 1.3))
				nodes[index].basis = basis
				parts[index].basis = basis
		_check(
			parts[index].transform.is_equal_approx(nodes[index].transform),
			"Local pose differs at step %d" % step
		)
		reference_proxy.transform = nodes[index].transform
		_check(
			parts[index].rotation.is_equal_approx(reference_proxy.rotation),
			"Euler/scale decomposition differs at step %d" % step
		)
		_check(
			parts[index].scale.is_equal_approx(nodes[index].scale),
			"Reflected scale differs at step %d" % step
		)
		rig.solve_palette(palette)
		for joint in 12:
			_check(
				palette[joint].is_equal_approx(nodes[joint].global_transform),
				"World hierarchy differs at step %d joint %d" % [step, joint]
			)
		_check(
			parts[index].to_local(position).is_equal_approx(nodes[index].to_local(position)),
			"Local point conversion differs"
		)
		if step % 50 == 0:
			var entries := [
				{
					"anchors": nodes,
					"native_rig": rig,
					"offset": 0,
					"shown": true,
					"pulse": Color(.1, .2, .3, .4)
				}
			]
			var bytes: PackedByteArray = packer.pack_poses(entries, 12)
			for joint in 12:
				_check(
					is_equal_approx(bytes.decode_float(joint * 64 + 12), palette[joint].origin.x),
					"Direct palette used a stale pose"
				)
	_check(rig.statistics()[3] > 0, "Direct native palette packing did not execute")
	nodes[0].free()
