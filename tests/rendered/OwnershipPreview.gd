extends "res://tests/headless/OwnershipRegression.gd"

var original_preferences
var deadline = 0


func _initialize():
	Engine.max_fps = 60
	deadline = Time.get_ticks_msec() + 240000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > deadline:
		push_error("Ownership preview timed out")
		quit(1)
	return false


func _run():
	var preferences = root.get_node("Globals").options
	original_preferences = preferences.capture()
	preferences.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix"]:
		await _ownership(faction)
	preferences.restore(original_preferences)
	for error in errors:
		push_error(error)
	print("Rendered ownership: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _review(faction, overlay, own, target):
	var preferences = root.get_node("Globals").options
	var camera = game.get_node("IsometricCamera3D")
	for scale in [1.0, 1.25, 1.5]:
		preferences.interface_scale = scale
		preferences.apply()
		await _frames(8)
		await _capture(faction, "scale-%d" % roundi(scale * 100))
	root.get_node("MatchSignals").deselect_all_units.emit()
	await _frames(4)
	var own_point = (
		root.get_final_transform()
		* camera.unproject_position(own.global_position + Vector3.UP * .4)
	)
	await _click(own_point)
	_check(own.is_in_group("selected_units"), "Ownership overlay ate world selection")
	await _key(KEY_M)
	var destination = Vector3(59, 0, 58)
	await _click(root.get_final_transform() * camera.unproject_position(destination))
	_check(
		own.manual_orders.pending.size() == 1 and own.manual_orders.pending[0].kind == "move",
		"Ownership overlay ate movement order"
	)
	var target_point = (
		root.get_final_transform()
		* camera.unproject_position(target.global_position + Vector3.UP * .4)
	)
	var hover = InputEventMouseMotion.new()
	hover.position = target_point
	hover.global_position = target_point
	root.push_input(hover, false)
	await _frames(12)
	_check(
		overlay.markers().any(func(row): return row.unit == target and row.hovered),
		"Actual pointer did not expose opponent nameplate"
	)
	var marker = overlay.markers().filter(func(row): return row.unit == target)[0]
	var label_size = (
		ThemeDB.fallback_font.get_string_size(marker.caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		+ Vector2(16, 8)
	)
	var label_rect = overlay.caption_rect(marker.point, label_size)
	_check(
		(
			label_rect.has_area()
			and not label_rect.intersects(game.find_child("UnitMenus").get_global_rect())
		),
		"Ownership nameplate hidden behind commands"
	)
	await _capture(faction, "opponent-hover")
	var dialog = root.get_node("Globals").open_settings()
	dialog.save_path = "user://ownership-preview-%d.tres" % OS.get_process_id()
	await _frames(6)
	dialog.controls.ownership_symbols.grab_focus()
	await _frames(6)
	_check(
		root.get_visible_rect().encloses(dialog.controls.ownership_symbols.get_global_rect()),
		"Ownership setting clipped at 720p/150%"
	)
	await _key(KEY_SPACE)
	_check(
		not preferences.ownership_symbols and overlay.markers().is_empty(),
		"Keyboard ownership preview failed"
	)
	await _capture(faction, "settings")
	await _click(root.get_final_transform() * dialog._cancel.get_global_rect().get_center())
	_check(preferences.ownership_symbols, "Cancel did not restore ownership symbols")
	_check(
		not overlay.markers().any(func(row): return row.hovered),
		"Closing settings restored a stale unit hover"
	)
	await _capture(faction, "restored")
	# Inspect the same-color skirmish at the larger window size too.
	root.size = Vector2i(1440, 900)
	await _capture(faction, "900p")
	root.size = Vector2i(1280, 720)


func _click(point):
	var motion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, false)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, false)
		await _frames(2)


func _key(code):
	for down in [true, false]:
		var event = InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = down
		root.push_input(event, false)
		await _frames(2)


func _capture(faction, label):
	await _frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(
		"res://art/skirmish/ownership-%s-%s.png" % [faction, label]
	)
