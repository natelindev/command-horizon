extends SceneTree


func _initialize():
	_run.call_deferred()


func _run():
	var status = load("res://source/match/rendering/NativePosePacker.gd").create()
	print("NATIVE_STATUS ", status)
	if not ClassDB.class_exists("CopperfinPosePacker"):
		quit(1)
		return
	var packer = ClassDB.instantiate("CopperfinPosePacker")
	var anchor := Node3D.new()
	root.add_child(anchor)
	anchor.transform = Transform3D(
		Basis.from_euler(Vector3(.3, -.7, 1.2)).scaled(Vector3(2, 3, 4)), Vector3(12, -3, 5)
	)
	var pulse := Color(.1, .2, .3, .4)
	var entries := [{"anchors": [anchor], "offset": 2, "shown": true, "pulse": pulse}]
	var bytes: PackedByteArray = packer.pack_poses(entries, 8)
	var pixels := bytes.to_float32_array()
	var expected: Transform3D = anchor.global_transform
	var actual := Transform3D(
		Basis(
			Vector3(pixels[32], pixels[36], pixels[40]),
			Vector3(pixels[33], pixels[37], pixels[41]),
			Vector3(pixels[34], pixels[38], pixels[42])
		),
		Vector3(pixels[35], pixels[39], pixels[43])
	)
	assert(actual.is_equal_approx(expected), "Native matrix layout disagrees with Godot")
	assert(Color(pixels[44], pixels[45], pixels[46], pixels[47]).is_equal_approx(pulse))
	# Array palettes must win over stale scene transforms, including mirrored scale.
	var posed := Transform3D(
		Basis.from_euler(Vector3(-.4, .2, 1.0)).scaled_local(Vector3(-2, 3, 4)), Vector3(-12, 6, 8)
	)
	entries[0].poses = [posed]
	pixels = packer.pack_poses(entries, 8).to_float32_array()
	actual = Transform3D(
		Basis(
			Vector3(pixels[32], pixels[36], pixels[40]),
			Vector3(pixels[33], pixels[37], pixels[41]),
			Vector3(pixels[34], pixels[38], pixels[42])
		),
		Vector3(pixels[35], pixels[39], pixels[43])
	)
	assert(actual.is_equal_approx(posed), "Array palette read stale node transforms")
	assert(anchor.global_transform.is_equal_approx(expected), "Packing mutated a scene node")
	anchor.hide()
	bytes = packer.pack_poses(entries, 8)
	assert(bytes.count(0) == bytes.size(), "Hidden articulated part was not cleared")
	anchor.show()
	entries[0].shown = false
	bytes = packer.pack_poses(entries, 8)
	assert(bytes.count(0) == bytes.size(), "Hidden entry was not cleared")
	anchor.free()
	entries[0].shown = true
	bytes = packer.pack_poses(entries, 8)
	assert(bytes.count(0) == bytes.size(), "Freed anchor was not safely skipped")
	assert(packer.pack_poses([], -1).is_empty())
	assert(packer.pack_poses([], 9000).is_empty())
	print("Native pose packer: PASS")
	quit()
