extends "res://tests/headless/SaveRestoreRegression.gd"

const Document = preload("res://source/scenario/ScenarioDocument.gd")


func _run():
	Engine.physics_ticks_per_second = 60
	root.get_node("SaveManager").autosaves_enabled = false
	_test_document()
	await _test_editing()
	for count in [2, 4]:
		await _test_match(count)
		paused = false
		if is_instance_valid(game):
			game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Scenario editor: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _test_document():
	var codec = Document.new()
	var data = Document.blank()
	_check(codec.validate(data), "Default document invalid: " + codec.error)
	var bad = data.duplicate(true)
	bad.items.append({"kind": "res://bad.gd", "x": 30, "z": 30, "yaw": 0, "amount": 0})
	_check(not codec.validate(bad), "Document accepted a resource/script path")
	bad = data.duplicate(true)
	bad.spawns[0].x = NAN
	_check(not codec.validate(bad), "Document accepted a nonfinite position")
	bad = data.duplicate(true)
	bad.spawns[1] = bad.spawns[0].duplicate()
	_check(not codec.validate(bad), "Document accepted overlapping headquarters")
	bad = data.duplicate(true)
	bad.size = [10000, 10000]
	_check(not codec.validate(bad), "Document accepted oversized terrain")
	bad = data.duplicate(true)
	bad.items.resize(257)
	_check(not codec.validate(bad), "Document accepted too many pieces")
	_check(not codec.write_document("../escape", data), "Document allowed path traversal")
	var filename = "regression-%d" % OS.get_process_id()
	_check(codec.write_document(filename, data), "Document save failed: " + codec.error)
	_check(codec.read_document(filename) == data, "Portable file round trip changed the map")
	data.title = "Updated battlefield"
	_check(codec.write_document(filename, data), "Atomic replacement failed")
	_check(codec.read_document(filename) == data, "Replacement lost the new map")
	DirAccess.remove_absolute(Document.DIRECTORY + filename + ".rtsmap")
	var chinese_filename = "沙漠战场-%d" % OS.get_process_id()
	_check(codec.write_document(chinese_filename, data), "Localized filename could not be saved")
	_check(codec.read_document(chinese_filename) == data, "Localized filename could not be loaded")
	DirAccess.remove_absolute(Document.DIRECTORY + chinese_filename + ".rtsmap")


func _test_editing():
	var editor = load("res://source/scenario/ScenarioEditor.tscn").instantiate()
	root.add_child(editor)
	current_scene = editor
	await _frames(3)
	var original = editor.document.duplicate(true)
	editor._select_tool("container")
	_check(editor.place_at(Vector3(40, 0, 40)), "Palette placement failed")
	_check(editor.document.items.size() == original.items.size() + 1, "Placement missing")
	editor._undo_edit()
	_check(editor.document == original, "Undo did not restore the map")
	editor._redo_edit()
	_check(editor.document.items.size() == original.items.size() + 1, "Redo failed")
	editor._select_tool("select")
	editor.place_at(Vector3(40, 0, 40))
	editor._x.value = 44
	editor._yaw.value = 90
	editor._apply_selection()
	_check(
		editor.document.items[-1].x == 44 and editor.document.items[-1].yaw == 90,
		"Selection inspector did not move and rotate the modular piece"
	)
	editor._remove_selection()
	_check(editor.document == original, "Remove did not restore the original geometry")
	editor._select_tool("granite")
	_check(not editor.place_at(Vector3(14, 0, 14)), "Placed a solid rock over the headquarters")
	_check(editor.document == original, "Rejected edit changed the document")
	editor.queue_free()
	await _frames(3)


func _test_match(count: int):
	var data = Document.blank()
	data.title = "Portable test arena"
	if count == 4:
		data.spawns.append({"x": 14, "z": 82, "yaw": 90})
		data.spawns.append({"x": 82, "z": 14, "yaw": -90})
	for kind in Document.KITS:
		var index = Document.KITS.keys().find(kind)
		data.items.append({"kind": kind, "x": 34 + index * 4, "z": 52, "yaw": 90, "amount": 0})
	data.items.append({"kind": "refinery", "x": 40, "z": 35, "yaw": 0, "amount": 0})
	data.items.append({"kind": "data_relay", "x": 56, "z": 61, "yaw": 0, "amount": 0})
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = Document.MAP
	settings.scenario = data
	settings.battlefield_events = false
	for index in count:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = 1 if index == 0 else 2
		side.spawn_index = index
		side.faction = ["bastion", "helix", "frontier"][index % 3]
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	var map = load(Document.MAP).instantiate()
	map.scenario = data.duplicate(true)
	game.map = map
	root.add_child(game)
	current_scene = game
	await _frames(90)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var human_worker = _units(game._get_human_player(), "Worker")[0]
	if "--native-unit-state" in OS.get_cmdline_user_args():
		_check(human_worker._native_state != null, "Scenario silently used script unit state")
	if "--native-crowd-runtime" in OS.get_cmdline_user_args():
		_check(
			human_worker.get_node("Movement")._native_runtime != null,
			"Scenario silently used script movement"
		)
	_check(get_nodes_in_group("players").size() == count, "Incorrect scenario player count")
	_check(game.map.size == Vector2(96, 96), "Scenario terrain size changed")
	_check(game.map.interior_obstacles.size() == Document.KITS.size(), "Modular pieces missing")
	_check(game.map.points_of_interest.size() == 2, "Capturable facilities missing")
	var navigation_rid = game.navigation.terrain.navigation_map_rid
	var path = NavigationServer3D.map_get_path(
		navigation_rid, Vector3(14, 0, 14), Vector3(82, 0, 82), true
	)
	_check(path.size() >= 2, "Scenario ground navigation did not bake")
	paused = true
	var capture = Snapshot.new()
	var saved = capture.capture(game)
	_check(saved != null, "Scenario capture failed: " + capture.error)
	if saved == null:
		return
	var restore = Restore.new()
	var corrupt = saved.duplicate(true)
	corrupt.settings.scenario.items[0].x = -500
	_check(not restore.prepare(corrupt), "Save schema accepted an invalid embedded map")
	var result = await restore.restore(self, saved)
	_check(result.ok, "Scenario restore failed: " + result.get("error", ""))
	if not result.ok:
		return
	game = result.game
	_check(game.settings.scenario == data and game.map.scenario == data, "Restore changed the map")
	_check(game.map.points_of_interest.size() == 2, "Restore lost capturable facilities")
	var second = Snapshot.new().capture(game)
	_check(second != null, "Restored custom map could not be saved again")
	if second != null:
		_check(
			second.resources == saved.resources, "Restore changed deposit IDs or resource amounts"
		)
