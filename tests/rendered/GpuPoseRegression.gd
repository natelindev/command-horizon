extends SceneTree

var failures := 0


func _initialize():
	_run.call_deferred()


func _run():
	var packer = load("res://source/match/rendering/NativePosePacker.gd").create()
	if packer == null or RenderingServer.get_rendering_device() == null:
		push_error("GPU pose regression requires the native module and a rendered window")
		quit(1)
		return
	var anchor := Node3D.new()
	root.add_child(anchor)
	var entries := [
		{"anchors": [anchor], "offset": 1, "shown": true, "pulse": Color(.1, .2, .3, .4)}
	]
	for mirrored in [false, true]:
		var scale := Vector3(2, 3, -4 if mirrored else 4)
		var old_pose := Transform3D(Basis(Vector3.UP, -.8).scaled_local(scale), Vector3(2, 3, 4))
		var new_pose := Transform3D(Basis(Vector3.UP, 1.1).scaled_local(scale), Vector3(12, -5, 7))
		anchor.transform = old_pose
		var old := ImageTexture.create_from_image(
			Image.create_from_data(4, 8, false, Image.FORMAT_RGBAF, packer.pack_poses(entries, 8))
		)
		anchor.transform = new_pose
		# Hit/belt-state column is discrete, including at interpolation fraction0.
		entries[0].pulse = Color(.001, .4, .8, .2)
		var current := ImageTexture.create_from_image(
			Image.create_from_data(4, 8, false, Image.FORMAT_RGBAF, packer.pack_poses(entries, 8))
		)
		var compute = load("res://source/match/rendering/ComputePosePalette.gd").new()
		compute.setup(old, current, 8)
		for weight in [0.0, .5, 1.0]:
			compute.dispatch(weight, 2)
			await RenderingServer.frame_post_draw
			var pixels: Image = compute.texture.get_image()
			var a := pixels.get_pixel(0, 1)
			var b := pixels.get_pixel(1, 1)
			var c := pixels.get_pixel(2, 1)
			var actual := Transform3D(
				Basis(Vector3(a.r, b.r, c.r), Vector3(a.g, b.g, c.g), Vector3(a.b, b.b, c.b)),
				Vector3(a.a, b.a, c.a)
			)
			var expected := Transform3D(
				Basis(Vector3.UP, lerpf(-.8, 1.1, weight)).scaled_local(scale),
				old_pose.origin.lerp(new_pose.origin, weight)
			)
			_check(
				actual.is_equal_approx(expected),
				"GPU rotation/scale/translation disagrees at %s mirror=%s" % [weight, mirrored]
			)
			_check(
				pixels.get_pixel(3, 1).is_equal_approx(entries[0].pulse), "GPU hit pulse changed"
			)
		entries[0].shown = false
		current.update(
			Image.create_from_data(4, 8, false, Image.FORMAT_RGBAF, packer.pack_poses(entries, 8))
		)
		compute.dispatch(.5, 2)
		await RenderingServer.frame_post_draw
		_check(
			compute.texture.get_image().get_pixel(0, 1).r == 0.0, "Hidden pose retained geometry"
		)
		entries[0].shown = true
		compute.release()
		await RenderingServer.frame_post_draw
	anchor.free()
	print("GPU pose regression: %d failures" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition, message):
	if not condition:
		failures += 1
		push_error(message)
