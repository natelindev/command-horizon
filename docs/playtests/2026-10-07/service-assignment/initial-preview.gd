extends "res://tests/headless/ServiceAssignmentRegression.gd"

var captures = ""
var clicks = 0


func _run():
	Engine.max_fps = 60
	factions = ["helix"]
	roles = ["Tank"]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	preferences.restore(original)


func _prepare(point):
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(22)
	camera.set_position_safely(point)
	for unit in get_nodes_in_group("units"):
		game.get_node("Handlers/UnitVisibilityHandler")._recalculate_unit_visibility(unit)
	game.fog_of_war._physics_process(0.0)
	await _frames(5)


func _select(units):
	root.get_node("MatchSignals").deselect_all_units.emit()
	for unit in units:
		unit.get_node("Selection").select()
	await _frames(3)


func _assign_point(kind, units, point):
	await _select(units)
	game.hud.arm_program_assignment(kind, units)
	await _prepare(point)
	var camera = game.get_node("IsometricCamera3D")
	var pixel = root.get_final_transform() * camera.unproject_position(point)
	var motion = InputEventMouseMotion.new()
	motion.position = pixel
	motion.global_position = pixel
	root.push_input(motion, false)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pixel
		event.global_position = pixel
		root.push_input(event, false)
		await _frames(2)
	clicks += 1
	print(
		"SERVICE GUI ",
		clicks,
		" kind=",
		kind,
		" armed=",
		game.hud._assignment_kind,
		" hint=",
		game.hud._assignment_hint.text
	)
	return game.hud._assignment_kind == ""


func _rejected_points(unit, service):
	await super(unit, service)
	# Repeat the unsuitable-HQ click for an actual visible rejection capture.
	var hq = _units(unit.player, "CommandCenter")[0]
	await _assign_point("safe", [unit], hq.global_position_yless)
	await _review_service_assignment(unit, service, "unsuitable")
	game.hud.cancel_map_assignment()


func _review_service_assignment(unit, service, stage):
	await _select([unit])
	await _prepare(service.global_position_yless)
	var hint = game.hud._assignment_hint
	if hint.visible:
		_check(
			game.hud._notice_slot.get_global_rect().encloses(hint.get_global_rect()),
			"Recovery assignment feedback clipped"
		)
	if captures != "":
		var motion = InputEventMouseMotion.new()
		motion.position = Vector2(650, 550)
		root.push_input(motion, false)
		await _frames(4)
		await RenderingServer.frame_post_draw
		var picture = root.get_texture().get_image()
		_check(picture.get_size() == Vector2i(1280, 720), "Service assignment capture size changed")
		var file = captures + "-" + case_label + "-" + stage + ".png"
		_check(
			not FileAccess.file_exists(file), "Service assignment capture would overwrite evidence"
		)
		if not FileAccess.file_exists(file):
			picture.save_png(file)
