extends "res://tests/headless/EconomyAssignmentsRegression.gd"

var captures = "res://docs/playtests/2026-10-07/economy-assignments/verified-preview"
var activations = 0


func _run():
	Engine.max_fps = 60
	faction_ids = ["helix"]
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await super()
	options.restore(original)


func _activate(_kind, button):
	await _viewport_size()
	activations += 1
	bar._refresh()
	await _frames(4)
	if activations == 2:
		button.grab_focus()
		for pressed in [true, false]:
			var event = InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			root.push_input(event, false)
			await _frames(2)
	else:
		var point = root.get_final_transform() * button.get_global_rect().get_center()
		var motion = InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, false)
		for pressed in [true, false]:
			var event = InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, false)
			await _frames(3)
	print("ALLOCATION INPUT ", activations, " keyboard=", activations == 2)


func _review_assignments(label):
	await _viewport_size()
	for unit in get_nodes_in_group("units"):
		game.get_node("Handlers/UnitVisibilityHandler")._recalculate_unit_visibility(unit)
	game.fog_of_war._physics_process(0)
	bar._refresh()
	await _frames(5)
	for button in bar._assignment_buttons.values():
		_check(
			bar.get_global_rect().encloses(button.get_global_rect()),
			"Resource assignment control clipped"
		)
	_check(
		not bar.get_global_rect().intersects(game.hud.get_child(0).get_global_rect()),
		"Resource bar overlaps battle controls"
	)
	_check(
		not bar.get_global_rect().intersects(game.hud.alert_panel.toggle.get_global_rect()),
		"Resource bar overlaps alerts"
	)
	var motion = InputEventMouseMotion.new()
	motion.position = Vector2(800, 600)
	root.push_input(motion, false)
	await _frames(3)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Allocation preview resolution changed")
	var path = captures + "-" + label + ".png"
	_check(not FileAccess.file_exists(path), "Allocation preview would overwrite evidence")
	if not FileAccess.file_exists(path):
		frame.save_png(path)
	print("ALLOCATION CAPTURE ", path)


func _delivery(faction):
	for worker in workers:
		if worker != carrier:
			worker.issue_manual_order(null)
	var cargo = carrier.resource_a
	var clock = game.simulation_time
	var snapshotter = Snapshot.new()
	var data = snapshotter.capture(game)
	var id = snapshotter._reference(carrier)
	var path = "user://economy-assignments-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(path, data), "Assignment archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(path))
	DirAccess.remove_absolute(path)
	_check(loaded.ok, "Assignment archive restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	owner = game._get_human_player()
	carrier = restore.entities[id]
	_bind()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	await _frames(5)
	_check(
		game.simulation_time == clock and carrier.resource_a == cargo,
		"Paused restore changed queued cargo"
	)
	_check(_count(1) == 0 and _count(2) == 1, "Archive lost planned allocation")
	await _controls(faction + "-restored")


func _viewport_size():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(6)
	print("ALLOCATION VIEWPORT ", root.size, " image=", root.get_texture().get_size())
