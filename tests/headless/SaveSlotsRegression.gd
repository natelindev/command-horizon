extends "res://tests/headless/SaveRestoreEdges.gd"

var manager


func _run():
	save_path = "user://slots-regression-%d.json" % OS.get_process_id()
	path = "user://slots-progress-%d.json" % OS.get_process_id()
	manager = root.get_node("SaveManager")
	manager.slots.directory = "user://slots-regression-%d" % OS.get_process_id()
	await _skirmish("helix")
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(true)
	var position = camera.position
	var time = game.simulation_time
	_check(await manager.save_slot("quick"), "Quicksave failed: " + manager.slots.error)
	_check(not paused and game.simulation_time == time, "Quicksave advanced time/kept pause")
	_check(camera.position == position and camera.can_process(), "Quicksave moved/disabled camera")
	game.hud._pause_button.grab_focus()
	var previous_focus = root.gui_get_focus_owner()
	await manager.open_dialog("save")
	var original_scene = current_scene
	_check(paused and not camera.can_process(), "Archive did not isolate paused battle input")
	await _frames(20)
	_check(game.simulation_time == time, "Open archive advanced simulation")
	_check(await manager.save_slot("manual-1"), "Manual save failed")
	_check(manager.dialog._notice.text.begins_with("Battle saved"), "Save feedback missing")
	manager.close_dialog()
	_check(not paused and camera.can_process(), "Closing archive did not restore prior state")
	_check(root.gui_get_focus_owner() == previous_focus, "Archive did not restore keyboard focus")
	game.hud._toggle_pause()
	await manager.open_dialog()
	manager.close_dialog()
	_check(paused and game.hud._pause_owned, "Archive released prior tactical pause")
	game.hud._toggle_pause()
	# Corruption is visible and cannot overwrite the previous file.
	var invalid_path = manager.slots.path_for("manual-2")
	var invalid = FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid.store_string("broken save fixture")
	invalid.close()
	await manager.open_dialog("load", "manual-2")
	_check(manager.dialog._primary.disabled, "Corrupt slot load remained enabled")
	_check(not await manager.load_slot("manual-2"), "Corrupt load succeeded")
	_check(current_scene == original_scene and paused, "Failed load replaced/released battle")
	_check(
		not manager.dialog._notice.text.is_empty() and not manager.dialog._close.disabled,
		"Failed read lost feedback or trapped dialog"
	)
	var invalid_schema = manager.slots.read_slot("manual-1")
	invalid_schema.units[0].role = "unsupported-role"
	FileStore.new().write_file(manager.slots.path_for("manual-3"), invalid_schema)
	_check(not await manager.load_slot("manual-3"), "Invalid gameplay schema was accepted")
	_check(
		current_scene == original_scene and not manager.dialog._close.disabled,
		"Preflight rejection trapped the dialog"
	)
	_check(not manager.dialog._notice.text.is_empty(), "Preflight rejection lost its error")
	_check(not await manager.save_slot("manual-2"), "Corrupt save was overwritten")
	_check(
		FileAccess.get_file_as_string(invalid_path) == "broken save fixture",
		"Corrupt source changed"
	)
	_check(await manager.load_slot("manual-1"), "Saved slot failed to load")
	game = current_scene
	_check(
		paused and manager.dialog == null and game.hud._pause_owned,
		"Successful load lost pause ownership"
	)
	game.hud._toggle_pause()
	_check(not paused, "Restored HUD cannot resume")
	await _navigation_failure()
	game.queue_free()
	await _frames(5)
	manager.autosaves_enabled = true
	await _make_match()
	for frame in range(120):
		await process_frame
		if FileAccess.file_exists(manager.slots.path_for("auto-1")) and not manager.busy:
			break
	_check(manager.slots.describe("auto-1").valid, "Mission start checkpoint missing")
	# Actual lesson transitions request checkpoints; service rotates through three slots.
	var human = game._get_human_player()
	game._spawn("CommandLab", human, Vector3(28, 0, 8))
	await _frames(100)
	_check(manager.slots.describe("auto-2").valid, "Lab checkpoint missing")
	var tank = _units(human, "Tank")[0]
	load("res://source/match/orders/UnitBehavior.gd").guard(tank, tank.position)
	await _frames(100)
	_check(manager.slots.describe("auto-3").valid, "Behavior checkpoint missing")
	game.relay.captured_by = human
	game.relay._update_presentation()
	game.relay.captured.emit(human)
	await _frames(30)
	var checkpoint = manager.slots.read_slot("auto-1")
	_check(
		checkpoint != null and checkpoint.mission.relay.owner == "player-0",
		"Relay checkpoint did not rotate"
	)
	_check(
		DirAccess.get_files_at(manager.slots.directory).size() == 7,
		"Checkpoint rotation grew extra slots"
	)
	await manager.open_dialog()
	_check(await manager.load_slot("auto-1"), "Checkpoint did not restore")
	game = current_scene
	game.progress_path = path
	var next_cursor = manager.slots._auto_cursor
	await _frames(15)
	_check(manager.slots._auto_cursor == next_cursor, "Loading immediately rewrote a checkpoint")
	manager.close_dialog()
	var damaged_auto = manager.slots.path_for("auto-2")
	var broken = FileAccess.open(damaged_auto, FileAccess.WRITE)
	broken.store_string("damaged checkpoint fixture")
	broken.close()
	game.hud._toggle_pause()
	manager.request_checkpoint(game, "Damaged-slot skip")
	await _frames(40)
	_check(
		FileAccess.get_file_as_string(damaged_auto) == "damaged checkpoint fixture",
		"Rotation overwrote damaged checkpoint"
	)
	_check(manager.slots.describe("auto-3").valid, "Rotation could not use a healthy slot")
	for id in ["auto-1", "auto-3"]:
		broken = FileAccess.open(manager.slots.path_for(id), FileAccess.WRITE)
		broken.store_string("damaged checkpoint fixture")
		broken.close()
	manager.request_checkpoint(game, "No writable slot")
	await _frames(30)
	_check(
		game.hud._assignment_hint.text.contains("retained"),
		"Blocked rotation did not report retained originals"
	)
	_check(manager.slots.describe("manual-1").valid, "Rotation modified manual saves")
	manager.autosaves_enabled = false
	for file in DirAccess.get_files_at(manager.slots.directory):
		DirAccess.remove_absolute(manager.slots.directory.path_join(file))
	DirAccess.remove_absolute(manager.slots.directory)
	print(
		(
			"PASS: quick/manual saves, modal isolation/pause, corrupt retention/load recovery; "
			+ "rotating real mission checkpoints"
		)
	)
	await _finish()


func _navigation_failure():
	await manager.open_dialog("load", "manual-1")
	var original = game
	var save_hash = FileAccess.get_sha256(manager.slots.path_for("manual-1"))
	# Hold the real navigation rebake beyond the loader's bounded wait, without a fake loader.
	var jam = func(node):
		if node.has_method("allocate_visual_seed"):
			node.ready.connect(
				func():
					node.navigation.terrain._earliest_frame_to_perform_next_rebake = 9223372036854775807
			)
	root.child_entered_tree.connect(jam)
	_check(not await manager.load_slot("manual-1"), "Navigation failure did not propagate")
	root.child_entered_tree.disconnect(jam)
	game = current_scene
	_check(
		not is_instance_valid(original) and manager.dialog.recovery_only,
		"Post-replacement failure lacks recovery UI"
	)
	_check(
		paused and not game.get_node("IsometricCamera3D").can_process(),
		"Failed replacement still accepts world input"
	)
	_check(
		FileAccess.get_sha256(manager.slots.path_for("manual-1")) == save_hash,
		"Failed replacement altered source save"
	)
	_check(
		manager.dialog._close.text == "Main menu" and manager.dialog._save_tab.disabled,
		"Unsafe partial battle can resume/save"
	)
	_check(await manager.load_slot("manual-1"), "Recovery could not retry the retained save")
	game = current_scene
	_check(
		paused and manager.dialog == null and not game.restoring, "Recovery left incomplete battle"
	)
	game.hud._toggle_pause()
	await manager.open_dialog("load", "manual-1")
	root.child_entered_tree.connect(jam)
	_check(not await manager.load_slot("manual-1"), "Second navigation fault was not injected")
	root.child_entered_tree.disconnect(jam)
	manager.dialog._back()
	await _frames(5)
	_check(
		not paused and current_scene.get_script() == load("res://source/main-menu/Main.gd"),
		"Recovery Main menu did not exit incomplete battle"
	)
	_check(
		await manager.load_slot("manual-1"),
		"Main menu could not reload retained save after failure"
	)
	game = current_scene
	game.hud._toggle_pause()
