extends "res://tests/headless/ProgramIssuesRegression.gd"

var captures = ""
var input_count = 0


func _run():
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			captures = argument.trim_prefix("--captures=")
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	await super()
	preferences.restore(original)


func _prepare_view():
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	game.get_node("IsometricCamera3D").set_size_safely(22)
	for unit in get_nodes_in_group("units"):
		game.get_node("Handlers/UnitVisibilityHandler")._recalculate_unit_visibility(unit)
	game.fog_of_war._physics_process(0.0)
	await _frames(8)


func _activate_issues(panel):
	await _prepare_view()
	panel.refresh()
	await _frames(5)
	var fired = [false]
	var observe = func(): fired[0] = true
	panel._programs.pressed.connect(observe)
	if input_count % 2 == 0:
		await _click_control(panel._programs)
	else:
		panel._programs.grab_focus()
		for pressed in [true, false]:
			var key = InputEventKey.new()
			key.keycode = KEY_ENTER
			key.pressed = pressed
			root.push_input(key, true)
			await _frames(2)
	_check(fired[0], "GUI input missed program issue shortcut")
	panel._programs.pressed.disconnect(observe)
	print("PROGRAM ISSUE GUI ", input_count, " activated=", fired[0])
	input_count += 1
	await _frames(6)


func _assign_and_resume(unit, point):
	var menus = game.find_child("UnitMenus")
	var panel = menus._program_panel
	var buttons = panel.find_children("*", "Button", true, false)
	var assign = buttons.filter(func(button): return button.text == "Assign area / route")[0]
	var resume = buttons.filter(func(button): return button.text == "Resume")[0]
	var started = game.simulation_time
	menus._scroll.ensure_control_visible(assign)
	await _frames(4)
	await _click_control(assign)
	_check(game.hud._assignment_kind == "anchor", "Program assignment control did not arm")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(point)
	await _frames(3)
	_check(
		not menus.get_global_rect().has_point(camera.unproject_position(point)),
		"Recovery map target is under the selection panel"
	)
	await _click(root.get_final_transform() * camera.unproject_position(point))
	print(
		"ISSUE REASSIGN ",
		unit.player.faction,
		" expected=",
		point,
		" actual=",
		unit.program.anchor,
		" armed=",
		game.hud._assignment_kind
	)
	_check(
		unit.program.anchor.distance_to(point) < .2, "Map click did not replace blocked assignment"
	)
	menus._scroll.ensure_control_visible(resume)
	await _frames(4)
	await _click_control(resume)
	_check(game.simulation_time == started, "Paused assignment input advanced simulation")


func _click_control(button):
	await _click(root.get_final_transform() * button.get_global_rect().get_center())


func _click(point):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, false)
		await _frames(2)


func _review(label):
	await _prepare_view()
	var panel = game.hud.battle_plan
	_check(
		not panel.get_global_rect().intersects(game.find_child("Minimap").get_global_rect()),
		"Program issues overlap minimap: " + label
	)
	_check(
		not panel.get_global_rect().intersects(game.find_child("UnitMenus").get_global_rect()),
		"Program issues overlap selection controls: " + label
	)
	_check(
		(
			panel._toggle.get_global_rect().end.x <= panel._programs.get_global_rect().position.x
			or not panel._programs.visible
		),
		"Header controls overlap: " + label
	)
	if captures != "":
		var motion = InputEventMouseMotion.new()
		motion.position = Vector2(650, 550)
		root.push_input(motion, false)
		await _frames(4)
		await RenderingServer.frame_post_draw
		var picture = root.get_texture().get_image()
		_check(
			picture.get_size() == Vector2i(1280, 720), "Program issue capture changed resolution"
		)
		var file = captures + "-" + label + ".png"
		_check(not FileAccess.file_exists(file), "Program issue review would overwrite evidence")
		if not FileAccess.file_exists(file):
			picture.save_png(file)
