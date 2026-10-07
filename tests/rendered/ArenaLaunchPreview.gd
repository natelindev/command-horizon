extends "res://tests/rendered/LuaEditorPreview.gd"


func _run():
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var initial = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5})
	await create_timer(2).timeout
	create_timer(90).timeout.connect(
		func():
			push_error("Arena launch review timed out")
			quit(1)
	)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
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
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
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

	var research = load("res://source/match/programs/arena/ArenaResearch.gd")
	var profile = {
		"coordination": true, "completed": ["weapons_1", "armor_1", "service", "doctrine"]
	}
	research.apply(human, profile)
	for tank in tanks:
		human.technology.apply_unit(tank)
	var labs = human.get_children().filter(
		func(unit): return "type" in unit and unit.type == "CommandLab"
	)
	var lab = labs[0]
	human.resource_a = 100
	human.resource_b = 100
	_check(human.technology.start("armor_2", lab), "Live pending research fixture failed")
	var live_research = human.technology.capture()
	var funds = Vector2i(human.resource_a, human.resource_b)
	var time = _game.simulation_time
	var actions = tanks.map(func(unit): return unit.action)
	editor._starter.select(1)
	await _click(_button_named(editor, "New from starter"))
	var source = editor._source.text
	editor._arena_bridge = load("res://tests/rendered/ArenaTestBridge.gd").new()
	editor.add_child(editor._arena_bridge)
	editor._arena_bridge.finished.connect(editor._arena_finished)
	await _click(_button_named(editor, "Battle arena"))
	_check(
		is_instance_valid(editor._arena_bridge) and editor._arena_bridge.pid > 0,
		"Arena process did not launch"
	)
	print("ARENA_LAUNCH_READY: child driver will exercise the real startup/window")
	var bridge = editor._arena_bridge
	var directory = bridge.directory
	var request = JSON.parse_string(
		FileAccess.get_file_as_string(directory.path_join("request.json"))
	)
	_check(request.research == profile, "Arena request omitted or copied active research")
	while bridge.pid > 0:
		await process_frame
	await _frames(5)
	_check(
		"Passed" in editor._trace.text, "No passing arena result returned: " + editor._notice.text
	)
	if not editor._arena_report.has("results"):
		push_error("Arena returned no valid results: " + editor._notice.text)
		_game.queue_free()
		options.restore(initial)
		quit(1)
		return
	_check(editor._source.text == source, "Arena changed the draft")
	_check(human.technology.capture() == live_research, "Arena changed live research")
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Arena changed live funds")
	_check(
		editor._arena_report.results[0].research == profile, "Returned arena result lost research"
	)
	_check("Weapons +10%" in editor._trace.text, "Editor result hid tested research")
	_check(paused and _game.simulation_time == time, "Arena advanced the live battle")
	for index in range(tanks.size()):
		_check(tanks[index].action == actions[index], "Arena changed live orders")
	_check(not DirAccess.dir_exists_absolute(directory), "Arena workspace not cleaned")
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Editor return resolution differs")
	frame.save_png("res://art/skirmish/arena-return-editor-720p.png")
	await _click(_button_named(editor, "Save version"))
	_check(
		"retreat: expected behavior observed" in editor._loaded.test_notes,
		"Saving omitted the scenario evidence"
	)
	_check("Weapons +10%" in editor._loaded.test_notes, "Saved program notes lost tested research")
	var previous_report = editor._arena_report.duplicate(true)
	editor._source.text += "\n-- changed draft"
	editor._draft_changed()
	var cleared_trace = editor._trace.text
	editor._arena_finished(previous_report)
	_check(
		editor._trace.text == cleared_trace and "earlier draft" in editor._notice.text,
		"An earlier arena result was accepted for changed source"
	)
	# Closing an editor cancels its child process and restores the original pause state.
	await _click(_button_named(editor, "Battle arena"))
	var cancelled_bridge = editor._arena_bridge
	var cancelled_directory = cancelled_bridge.directory
	await _frames(30)
	_key(KEY_ESCAPE)
	await _frames(15)
	_check(not is_instance_valid(cancelled_bridge), "Closing editor retained the arena bridge")
	_check(
		not DirAccess.dir_exists_absolute(cancelled_directory), "Cancellation retained workspace"
	)
	_check(not paused, "Closing editor left the original battle paused")
	DirAccess.remove_absolute(_path)
	_game.queue_free()
	await _frames(5)
	for message in _errors:
		push_error(message)
	if _errors.is_empty():
		print(
			"PASS: child launch/return, matching results, order/draft/pause isolation and cancellation"
		)
	options.restore(initial)
	quit(0 if _errors.is_empty() else 1)
