extends SceneTree

var failures = 0


func _initialize():
	_run.call_deferred()


func _run():
	var native = load("res://source/match/rendering/NativePosePacker.gd").create()
	if native == null or not native.has_method("rebase_poses"):
		push_error("Pose rebasing requires the current native module")
		quit(1)
		return
	var anchor = Node3D.new()
	root.add_child(anchor)
	var random = RandomNumberGenerator.new()
	random.seed = 9921
	for index in 500:
		var pose = Transform3D(
			Basis.from_euler(Vector3(random.randf(), random.randf(), random.randf())).scaled_local(
				Vector3(1.2, .8, -1.0 if index % 2 else 1.0)
			),
			Vector3(random.randf_range(-30, 30), 2, random.randf_range(-30, 30))
		)
		var delta = Transform3D(
			Basis.from_euler(Vector3(.1, random.randf(), -.2)), Vector3(5, -3, 8)
		)
		anchor.transform = pose
		var entries = [
			{
				"anchors": [anchor],
				"offset": 1,
				"shown": true,
				"pulse": Color(.2, .3, .4, .5),
				"rebase": delta
			}
		]
		var original = native.pack_poses(entries, 4)
		var before = original.duplicate()
		var advanced = native.rebase_poses(original, entries)
		_check(original == before, "Rebase changed the previous input buffer")
		var image = Image.create_from_data(4, 4, false, Image.FORMAT_RGBAF, advanced)
		var a = image.get_pixel(0, 1)
		var b = image.get_pixel(1, 1)
		var c = image.get_pixel(2, 1)
		var actual = Transform3D(
			Basis(Vector3(a.r, b.r, c.r), Vector3(a.g, b.g, c.g), Vector3(a.b, b.b, c.b)),
			Vector3(a.a, b.a, c.a)
		)
		_check(
			actual.is_equal_approx(delta * pose),
			"Rebased translation, rotation or reflection differs"
		)
		_check(
			image.get_pixel(3, 1).is_equal_approx(entries[0].pulse), "Rebase changed the hit pulse"
		)
		entries[0].shown = false
		var hidden = native.pack_poses(entries, 4)
		_check(native.rebase_poses(hidden, entries) == hidden, "Hidden poses became visible")
		entries[0].offset = 4
		_check(
			native.rebase_poses(original, entries) == original,
			"Out-of-range rebase wrote outside its span"
		)
	anchor.free()
	print("Native pose rebase: %d failures" % failures)
	await root.get_node("Globals").quit_game(0 if failures == 0 else 1)


func _check(condition, message):
	if not condition:
		failures += 1
		if failures <= 10:
			push_error(message)
