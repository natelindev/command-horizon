extends SceneTree

var failures := []
var comparisons := 0


func _initialize():
	_run.call_deferred()


func _check(condition: bool, message: String):
	if not condition and failures.size() < 20:
		failures.append(message)


func _run():
	var packer = load("res://source/match/rendering/NativePosePacker.gd").create()
	if packer == null or not ClassDB.class_exists("CopperfinPresentationBatch"):
		_check(false, "Native presentation batch is required")
	else:
		_compare(packer)
	for message in failures:
		push_error(message)
	print(
		(
			"Native presentation: %d failures across %d palette comparisons"
			% [failures.size(), comparisons]
		)
	)
	await root.get_node("Globals").quit_game(0 if failures.is_empty() else 1)


func _compare(packer):
	var batch = ClassDB.instantiate("CopperfinPresentationBatch")
	_check(batch.configure(8), "Palette capacity did not configure")
	var owners := [Node3D.new(), Node3D.new()]
	for owner in owners:
		root.add_child(owner)
	var unit := Node3D.new()
	owners[0].add_child(unit)
	var geometry := Node3D.new()
	unit.add_child(geometry)
	var first := Node3D.new()
	geometry.add_child(first)
	var second := Node3D.new()
	first.add_child(second)
	var rig = ClassDB.instantiate("CopperfinPoseRig")
	var rig_root = rig.add_part(-1, Transform3D.IDENTITY)
	var parts := [rig.add_part(0, Transform3D.IDENTITY), rig.add_part(1, Transform3D.IDENTITY)]
	_check(rig.configure_anchors(PackedInt32Array([1, 2])), "Rig anchors did not configure")
	var handle: int = batch.bind_unit(unit, geometry, [first, second], rig, 1, 3.0)
	_check(handle >= 0, "Presentation unit did not bind")
	_check(
		batch.bind_unit(unit, geometry, [first, second], rig, 1, 3.0) < 0,
		"Overlapping binding accepted"
	)
	var overlay := ShaderMaterial.new()
	overlay.shader = load("res://source/shaders/3d/material_hit.gdshader")
	var entry := {
		"anchors": [first, second],
		"offset": 1,
		"shown": true,
		"pulse": Color(0, 0, 0, 0),
		"rebase": Transform3D.IDENTITY
	}
	var last := PackedByteArray()
	last.resize(8 * 64)
	for diagonal in [0, 5, 10]:
		last.encode_float(diagonal * 4, 1.0)
	var physics := unit.global_transform
	var sampled := unit.global_transform
	var previous := Vector3.INF
	var random := RandomNumberGenerator.new()
	random.seed = 78543
	for index in 800:
		var paused := index % 17 == 0
		if not paused:
			var elapsed := 0.0
			for tick in index % 4 + 1:
				physics = unit.global_transform
				batch.capture(1.0 / 30.0)
				elapsed += 1.0 / 30.0
				unit.position += Vector3(.12, .01, -.08)
				unit.rotation.y += .025
			_check(
				is_equal_approx(batch.elapsed(handle), elapsed), "Captured pose duration differs"
			)
			batch.set_elapsed(handle, 0.0)
		if index % 43 == 0:
			unit.position += Vector3(31, 8, -29)
			_check(handle in batch.changes(), "Cell/altitude change did not publish")
		if index % 97 == 0:
			unit.reparent(owners[(index / 97 + 1) % 2], true)
			_check(handle in batch.changes(), "Capture did not invalidate presentation owner")
			var old := handle
			_check(batch.unbind(handle), "Existing presentation handle did not release")
			handle = batch.bind_unit(unit, geometry, [first, second], rig, 1, 3.0)
			_check(handle != old and not batch.unbind(old), "Stale generation handle was accepted")
			physics = unit.global_transform
			sampled = unit.global_transform
			previous = Vector3.INF
		geometry.transform = Transform3D(
			Basis.from_euler(Vector3(.1, -.15, .08)), Vector3(0, .55, 0)
		)
		first.transform = Transform3D(
			Basis.from_euler(Vector3(random.randf(), .2, .3)).scaled_local(
				Vector3(1.2, .8, -1 if index % 2 else 1)
			),
			Vector3(.1, .3, -.4)
		)
		second.transform = Transform3D(
			Basis.from_euler(Vector3(.1, random.randf(), .3)), Vector3(-.3, .8, .7)
		)
		rig_root.transform = unit.global_transform * geometry.transform
		parts[0].transform = first.transform
		parts[1].transform = second.transform
		batch.set_geometry(handle, geometry.transform, true)
		geometry.visible = index % 11 != 0
		second.visible = index % 7 != 0
		entry.shown = geometry.is_visible_in_tree()
		var color := Color(.2, .5, .9, .8)
		var strength := .4 + index % 3 * .1
		overlay.set_shader_parameter("hit_color", color)
		overlay.set_shader_parameter("hit_strength", strength)
		batch.set_pulse(handle, overlay if index % 5 else null)
		entry.pulse = color.srgb_to_linear() if index % 5 else Color(0, 0, 0, 0)
		if index % 5:
			entry.pulse.a = strength
		entry.rebase = physics * sampled.affine_inverse() if not paused else Transform3D.IDENTITY
		var current: PackedByteArray = packer.pack_poses([entry], 8)
		for diagonal in [0, 5, 10]:
			current.encode_float(diagonal * 4, 1.0)
		var before: PackedByteArray = (
			packer.rebase_poses(last, [entry]) if not paused else last.duplicate()
		)
		if unit.global_position.distance_to(previous) > 4.0:
			for offset in range(64, 192, 4):
				before.encode_float(offset, current.decode_float(offset))
		var actual: Array = batch.pack(paused)
		_compare_bytes(actual[0], current, "current", index)
		_compare_bytes(actual[1], before, "previous", index)
		last = current
		sampled = unit.global_transform
		previous = unit.global_position
	_check(
		batch.statistics()[0] == 1 and batch.statistics()[4] > 0, "Native packing never executed"
	)
	var retained: WeakRef = weakref(rig)
	parts.clear()
	rig_root = null
	rig = null
	_check(retained.get_ref() != null, "Bound rig was not retained")
	unit.free()
	_check(handle in batch.changes(), "Freed scene objects remained publishable")
	_check(batch.pack(false).size() == 2, "Freed scene objects broke palette publication")
	batch.unbind(handle)
	_check(retained.get_ref() == null, "Released binding retained its rig")
	for owner in owners:
		owner.free()


func _compare_bytes(actual: PackedByteArray, expected: PackedByteArray, label: String, step: int):
	comparisons += 1
	_check(actual.size() == expected.size(), "Palette size differs: " + label)
	for offset in range(0, mini(actual.size(), expected.size()), 4):
		var value := actual.decode_float(offset)
		var reference := expected.decode_float(offset)
		if not is_finite(value) or absf(value - reference) > .0002:
			_check(
				false,
				"%s palette step %d byte %d: %f != %f" % [label, step, offset, value, reference]
			)
			return
