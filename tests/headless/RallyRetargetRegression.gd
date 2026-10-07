extends "res://tests/headless/HQCountdownRegression.gd"

var factions = ["bastion", "helix", "frontier"]
var hq
var rally
var owner
var current_target
var case_label = ""


func _run():
	var manager = root.get_node("SaveManager")
	var autosaves = manager.autosaves_enabled
	manager.autosaves_enabled = false
	for faction in factions:
		case_label = faction
		await _mirror(faction)
		_bind()
		await _current_target_loss()
		await _dispose()
		await _mirror(faction)
		_bind()
		await _paid_route()
		await _dispose()
	manager.autosaves_enabled = autosaves
	for error in errors:
		push_error(error)
	print("Rally retarget: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _bind():
	owner = game._get_human_player()
	hq = _units(owner, "CommandCenter")[0]
	rally = hq.get_node("RallyPoint")
	root.get_node("MatchSignals").deselect_all_units.emit()
	hq.get_node("Selection").select()


func _target(unit):
	root.get_node("MatchSignals").unit_targeted.emit(unit)
	await _frames(2)
	_check(rally.target_unit == unit, "Rally command did not select requested target")


func _point(point):
	root.get_node("MatchSignals").terrain_targeted.emit(point)
	await _frames(2)
	_check(rally.target_unit == null and rally.global_position == point, "Point rally refused")


func _current_target_loss():
	var workers = _units(owner, "Worker")
	var previous = workers[0]
	var latest = workers[1]
	await _target(previous)
	await _target(latest)
	await _target(latest)
	game.hud._toggle_pause()
	await _frames(3)
	game.hud.pause_after_load()
	_check(
		rally.global_position.distance_to(latest.global_position) < 0.1,
		"Rally did not follow replacement"
	)
	latest.hp = 0
	await _frames(5)
	_check(typeof(rally.target_unit) == TYPE_NIL, "Destroyed replacement left a stale rally target")
	_check(rally.global_position == hq.global_position, "Lost rally did not return to producer")
	if typeof(rally.target_unit) != TYPE_NIL:
		return
	_check(rally.visible, "Selected producer lost its cleared rally marker")
	await _review("target-lost")
	# The previous live target must no longer own this point assignment.
	var destination = hq.global_position + Vector3(5, 0, -4)
	await _point(destination)
	# Preserve the accepted raycast destination exactly, including subpixel rounding.
	destination = rally.global_position
	previous.hp = 0
	await _frames(5)
	_check(rally.global_position == destination, "Old target death erased explicit point rally")
	await _point_archive(destination)
	root.get_node("MatchSignals").deselect_all_units.emit()
	_check(not rally.visible, "Deselected producer retained rally marker")


func _point_archive(destination):
	var data = Snapshot.new().capture(game)
	var file = "user://rally-point-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, data), "Point rally archive write failed")
	var loaded = await Restore.new().restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Point rally archive restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	_bind()
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(10)
	_check(
		(
			paused
			and game.simulation_time == data.simulation_time
			and rally.target_unit == null
			and rally.global_position == destination
		),
		"Paused archive erased explicit point rally"
	)
	await _review("point-restored")


func _paid_route():
	var materials = get_nodes_in_group("resource_units").filter(
		func(node): return "resource_a" in node
	)
	var electronics = get_nodes_in_group("resource_units").filter(
		func(node): return "resource_b" in node
	)
	materials.sort_custom(
		func(a, b): return hq.position.distance_to(a.position) < hq.position.distance_to(b.position)
	)
	electronics.sort_custom(
		func(a, b): return hq.position.distance_to(a.position) < hq.position.distance_to(b.position)
	)
	var previous = materials[0]
	current_target = electronics[0]
	await _target(previous)
	await _target(current_target)
	await _review("retargeted")
	previous.resource_a = 0
	await _frames(5)
	_check(rally.target_unit == current_target, "Depleted old field erased replacement rally")
	if rally.target_unit != current_target:
		return
	var before = Vector2i(owner.resource_a, owner.resource_b)
	var job = hq.production_queue.produce(load("res://source/match/units/Worker.tscn"))
	_check(job != null, "Paid rally engineer could not be queued")
	if job == null:
		return
	_check(
		(
			Vector2i(owner.resource_a, owner.resource_b)
			== before - Vector2i(job.paid_cost.resource_a, job.paid_cost.resource_b)
		),
		"Rally engineer cost not paid"
	)
	game.hud._toggle_pause()
	await _frames(60)
	game.hud.pause_after_load()
	_check(
		job.time_left > 0 and job.time_left < job.time_total,
		"Rally production did not progress normally"
	)
	await _archive()
	await _review("restored")
	var before_workers = _units(owner, "Worker")
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var seconds = game.simulation_time
	game.hud._toggle_pause()
	for frame in 7200:
		await _frames(1)
		if owner.resource_b >= funds.y + 4:
			break
	game.hud.pause_after_load()
	var created = _units(owner, "Worker").filter(func(unit): return unit not in before_workers)
	_check(created.size() == 1, "Restored paid queue did not create one engineer")
	_check(
		owner.resource_b >= funds.y + 4, "Replacement rally engineer did not deliver electronics"
	)
	_check(owner.resource_a == funds.x, "Electronics rally unexpectedly delivered materials")
	if created.size() == 1:
		_check(
			created[0].program == null or created[0].program.mode != "Running",
			"Rally lost manual authority"
		)
	print(
		"RALLY DELIVERY ",
		case_label,
		" seconds=",
		game.simulation_time - seconds,
		" income=",
		Vector2i(owner.resource_a, owner.resource_b) - funds
	)
	await _review("delivery")
	# A new target lost after restoration must clear its reference as well.
	current_target.resource_b = 0
	await _frames(5)
	_check(rally.target_unit == null, "Restored target depletion left a stale rally")
	_check(rally.global_position == hq.global_position, "Restored rally did not reset")


func _archive():
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var hq_id = builder._reference(hq)
	var target_id = builder._reference(current_target)
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	var left = hq.production_queue.get_elements()[0].time_left
	var file = "user://rally-retarget-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, data), "Rally archive write failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Rally archive restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	_bind()
	current_target = restore.entities[target_id]
	_check(
		hq == restore.entities[hq_id] and rally.target_unit == current_target,
		"Archive changed rally target identity"
	)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(10)
	_check(
		paused and game.simulation_time == data.simulation_time,
		"Paused rally archive advanced clock"
	)
	_check(
		(
			Vector2i(owner.resource_a, owner.resource_b) == funds
			and hq.production_queue.get_elements()[0].time_left == left
		),
		"Rally archive changed paid queue or funds"
	)


func _review(_stage):
	pass


func _dispose():
	paused = false
	game.queue_free()
	await _frames(5)
