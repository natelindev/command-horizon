extends "res://tests/rendered/UnitAnimationCapture.gd"


# Close-up motion review, rendered at 60 Hz and captured at 30 Hz.
# Run without --headless, with --fixed-fps 60. JPEG frames and contact sheets
# are written under art/animation/robot-gait/. The root is moved deterministically
# to isolate animation from navigation; UnitAnimationCapture covers live orders.
func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "day_cycle": false, "time_of_day": 0, "weather": 1})
	var output = "res://art/animation/robot-gait"
	DirAccess.make_dir_recursive_absolute(output)
	for entry in [["bastion", "CombatRobot"], ["helix", "CombatRobot"], ["helix", "RepairRobot"]]:
		await _fixture(entry[0])
		_game.map.hide()
		var floor_mesh = PlaneMesh.new()
		floor_mesh.size = Vector2(200, 200)
		var floor_material = StandardMaterial3D.new()
		floor_material.albedo_color = Color("65717c")
		floor_material.roughness = .95
		var floor_node = MeshInstance3D.new()
		floor_node.mesh = floor_mesh
		floor_node.material_override = floor_material
		floor_node.position = Vector3(32, -.01, 32)
		_game.add_child(floor_node)
		for existing in get_nodes_in_group("units"):
			existing.hide()
		var unit = _spawn(entry[1], _human, Vector3(30, 0, 26))
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.action = null
		var visual = unit.get_node("BastionVisuals")
		_camera.rotation_degrees = Vector3(-23, 0, 0)
		_label.position = Vector2(28, 24)
		var name = "%s-%s" % entry
		var directory = output + "/" + name
		DirAccess.make_dir_recursive_absolute(directory)
		var sheet = Image.create(960, 720, false, Image.FORMAT_RGB8)
		var tile = 0
		for frame in range(480):
			var speed = 0.0
			var state = "Standing"
			if frame >= 60 and frame < 240:
				speed = 1.5
				state = "Walking"
			elif frame >= 240 and frame < 330:
				speed = unit.movement_speed
				unit.rotate_y(.45 / 60.0)
				state = "Full speed / turn"
			elif frame >= 330 and frame < 390:
				unit.rotate_y(.8 / 60.0)
				state = "Pivot turn"
			elif frame >= 390:
				state = "Stop / settle"
			unit.position -= unit.basis.z * speed / 60.0
			visual._process(1.0 / 60.0)
			_focus(unit.position + Vector3(0, .5, 0), 3.6)
			_label.text = "%s  /  %s\n%s" % [entry[0].to_upper(), entry[1], state]
			await process_frame
			await RenderingServer.frame_post_draw
			if frame % 2 == 0:
				var capture = root.get_texture().get_image()
				capture.save_jpg(directory + "/frame-%04d.jpg" % (frame / 2), .92)
				if frame in [100, 106, 112, 118, 124, 130, 254, 260, 266]:
					capture.resize(320, 240, Image.INTERPOLATE_LANCZOS)
					sheet.blit_rect(
						capture,
						Rect2i(0, 0, 320, 240),
						Vector2i(tile % 3, tile / 3) * Vector2i(320, 240)
					)
					tile += 1
		sheet.save_png(output + "/" + name + ".png")
		await _close()
	options.restore(original)
	print("Robot gait preview complete: ", output)
	quit()
