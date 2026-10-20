extends "res://tests/headless/SaveSnapshotRegression.gd"


func _run():
	save_path = "user://save-load-scale-%d.json" % OS.get_process_id()
	path = "user://save-load-scale-progress-%d.json" % OS.get_process_id()
	await _make_match()
	var queued = await _scale_capture()
	var service = root.get_node("SaveManager")
	service.slots.directory = "user://save-load-scale-slots-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(service.slots.directory)
	DirAccess.copy_absolute(save_path, service.slots.path_for("manual-1"))
	var before = Time.get_ticks_msec()
	await service.open_dialog()
	print("SAVE LOAD SCALE: archive open ms=", Time.get_ticks_msec() - before)
	before = Time.get_ticks_msec()
	var loaded = await service.load_slot("manual-1")
	print("SAVE LOAD SCALE: actual load ms=", Time.get_ticks_msec() - before)
	_check(loaded, "200-unit actual load failed")
	game = current_scene
	game.progress_path = path
	_check(
		game._get_human_player().population() == 100 and game._enemy.population() == 100,
		"200-unit load changed population"
	)
	var tanks = get_nodes_in_group("units").filter(func(unit): return unit.type == "Tank")
	_check(tanks.size() == queued, "200-unit load changed the tank roster")
	var intact = 0
	for unit in tanks:
		var orders = unit.manual_orders
		if orders.pending.size() + (0 if orders.current.is_empty() else 1) == SCALE_ORDERS:
			intact += 1
	_check(intact == queued, "Large order queues lost")
	await _frames(20)
	before = Time.get_ticks_msec()
	_check(await service.save_slot("manual-2"), "Loaded 200-unit army could not save")
	print("SAVE LOAD SCALE: recapture/write ms=", Time.get_ticks_msec() - before)
	service.autosaves_enabled = false
	for file in DirAccess.get_files_at(service.slots.directory):
		DirAccess.remove_absolute(service.slots.directory.path_join(file))
	DirAccess.remove_absolute(service.slots.directory)
	await _finish_checks()
