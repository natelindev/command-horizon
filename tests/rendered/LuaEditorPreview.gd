extends "res://tests/rendered/ProgramPreview.gd"


func _run():
	var original = await _prepare_720p()
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.advanced_start = true
	settings.map_path = "res://source/match/maps/BastionDesert.tscn"
	for side in range(2):
		var player = load("res://source/data-model/PlayerSettings.gd").new()
		player.controller = (
			root.get_node("Constants").PlayerType.HUMAN
			if side == 0
			else root.get_node("Constants").PlayerType.SIMPLE_CLAIRVOYANT_AI
		)
		player.faction = "helix" if side == 0 else "bastion"
		player.color = Color("38c8ce") if side == 0 else Color("e3ad48")
		settings.players.append(player)
	_game = load("res://source/match/Skirmish.tscn").instantiate()
	_game.settings = settings
	_game.map = load(settings.map_path).instantiate()
	root.add_child(_game)
	current_scene = _game
	get_nodes_in_group("players")[1].set_process(false)
	_game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(50)
	var human = _game._get_human_player()
	var tanks = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "Tank"
	)
	for tank in tanks:
		tank.get_node("Selection").select()
	await _frames(3)
	var panel = _game.find_child("UnitMenus")._program_panel
	_path = "user://lua-editor-ui-%d.json" % OS.get_process_id()
	panel.library_path = _path
	await _capture("lua-editor-entry")
	await _click(_button_named(panel, "Lua editor"))
	var editor = _game.hud.program_editor
	_check(is_instance_valid(editor), "Lua editor button did not open")
	if not is_instance_valid(editor):
		for message in _errors:
			push_error(message)
		quit(1)
		return
	_check(paused and not _game.hud._pause_owned, "Editor pause ownership failed")
	var time = _game.simulation_time
	var actions = tanks.map(func(unit): return unit.action)
	editor._starter.select(1)
	await _click(_button_named(editor, "New from starter"))
	editor._name.text = "Helix guard"
	editor._source.grab_focus()
	editor._source.set_caret_line(0)
	editor._source.set_caret_column(0)
	# Real key dispatch: typing combat/menu shortcuts must stay in the CodeEdit.
	for code in [KEY_MINUS, KEY_MINUS, KEY_F, KEY_SPACE, KEY_1]:
		_key(code, code)
	await _frames(4)
	_check(editor._source.text.begins_with("--F 1"), "Keyboard input missed Lua editor")
	_check(not _game.hud._attack_armed and _game.hud._overlay == null, "Editor leaked hotkeys")
	await _click(_button_named(editor, "Check samples"))
	_check("passed" in editor._notice.text, "Editor samples failed: " + editor._notice.text)
	_check(_game.simulation_time == time, "Sample check advanced live game")
	for index in range(tanks.size()):
		_check(tanks[index].action == actions[index], "Draft/check changed live order")
	await _click(_button_named(editor, "Save version"))
	_check(editor._loaded.get("version") == 1, "UI did not save source: " + editor._notice.text)
	_check(not editor._apply_button.disabled, "Saved valid Lua cannot apply")
	_check(panel._library.versions.size() == 1, "Selection library did not refresh after Lua save")
	_check(editor._panel.get_global_rect().end.y <= 700, "Editor overflows 720p")
	_check(editor._apply_button.get_global_rect().end.y <= 700, "Apply button clipped")
	await _capture("lua-editor-720p")
	await _click(editor._apply_button)
	_check(tanks[0].program.mode == "Ready", "Paused Apply did not queue Lua")
	var source = tanks[0].program.lua_source
	var prior = editor._loaded.duplicate(true)
	editor._source.select_all()
	editor._source.insert_text_at_caret("return function(")
	await _frames(3)
	_check(editor._apply_button.disabled, "Unsaved edit still applies old source")
	await _click(_button_named(editor, "Save version"))
	_check(
		editor._loaded == prior and tanks[0].program.lua_source == source,
		"Bad edit replaced saved/live source"
	)
	await _capture("lua-editor-error-720p")
	_key(KEY_ESCAPE)
	await _frames(4)
	_check(
		not is_instance_valid(_game.hud.program_editor) and not paused,
		"Escape failed to restore running match"
	)
	_check(_game.hud._overlay == null, "Escape also opened match menu")
	await _frames(20)
	_check(tanks[0].program.mode == "Waiting", "Unassigned guard did not request an area")
	panel = _game.find_child("UnitMenus")._program_panel
	await _click(_button_named(panel, "Assign area / route"))
	var point = tanks[0].global_position_yless + Vector3(2, 0, -2)
	var pixel = _game.get_node("IsometricCamera3D").unproject_position(point)
	var motion = InputEventMouseMotion.new()
	motion.position = pixel
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pixel
		event.pressed = pressed
		root.push_input(event, true)
	await _frames(5)
	_check(tanks[0].program.mode == "Manual", "Area reassignment did not preserve manual authority")
	await _click(_button_named(panel, "Resume"))
	await _frames(25)
	print(
		"GUARD UI ASSIGN ",
		"point=",
		point,
		" pixel=",
		pixel,
		" actual=",
		tanks[0].program.anchor,
		" mode=",
		tanks[0].program.mode,
		" reason=",
		tanks[0].program.reason
	)
	await _capture("lua-guard-assignment-720p")
	_check(
		(
			tanks[0].program.mode == "Running"
			and tanks[0].program.anchor != null
			and tanks[0].program.anchor.distance_to(point) < .1
		),
		"Assigned guard did not run"
	)
	# The unit panel can be rebuilt while the persistent draft survives on the HUD.
	_game.hud._toggle_pause()
	panel = _game.find_child("UnitMenus")._program_panel
	await _click(_button_named(panel, "Lua editor"))
	editor = _game.hud.program_editor
	_check(editor._source.text == "return function(", "Closing lost the unsaved draft")
	_check(editor._apply_button.disabled, "Unsaved restored draft became a saved version")
	editor._load_saved(1)
	await _frames(3)
	_check(
		editor._source.text == source and not editor._apply_button.disabled,
		"Reload exact source failed"
	)
	# Arbitrary saved role subsets survive loading without widening to all roles.
	var record = load("res://source/match/programs/ProgramRecord.gd")
	var subset = record.lua("Pair", 1, source, ["Tank", "Drone"], ["movement"])
	editor._show_draft(subset)
	_check(editor._draft().roles == ["Tank", "Drone"], "Editor widened a saved role group")
	editor._load_saved(1)
	root.size = Vector2i(1440, 900)
	await _frames(8)
	await _capture("lua-editor-900p")
	root.size = Vector2i(1280, 720)
	await _frames(8)
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(paused and _game.hud._pause_owned, "Editor released tactical pause")
	_game.hud._toggle_pause()
	# UI factory pins carry source integrity as well as name and version.
	root.get_node("MatchSignals").deselect_all_units.emit()
	var factories = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "VehicleFactory"
	)
	var factory = factories[0]
	factory.production_queue.program_library_path = _path
	factory.get_node("Selection").select()
	await _frames(4)
	var factory_panel = _game.find_child("UnitMenus")._factory_program_panel
	factory_panel._select(1)
	_check(
		factory.production_queue.program_pin.has("content_hash"),
		"Factory UI omitted immutable hash"
	)
	DirAccess.remove_absolute(_path)
	_game.queue_free()
	await _frames(8)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			(
				"PASS: real editor mouse/keyboard; isolated checks/save/explicit apply; "
				+ "invalid edits; retained drafts; both pause states; factory pin UI; 720p"
			)
		)
	root.get_node("Globals").options.restore(original)
	quit(0 if _errors.is_empty() else 1)


func _prepare_720p():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await _frames(8)
	_check(root.size == Vector2i(1280, 720), "Editor window did not settle at 720p")
	return original


func _button_named(node, text):
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found = _button_named(child, text)
		if found != null:
			return found
	return null


func _click(button):
	_check(is_instance_valid(button), "UI button missing")
	if not is_instance_valid(button):
		return
	var point = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
	await _frames(3)


func _key(code, unicode_value = 0):
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode_value
		event.pressed = pressed
		root.push_input(event, true)
