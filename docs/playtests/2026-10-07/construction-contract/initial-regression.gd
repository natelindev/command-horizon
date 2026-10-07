extends "res://tests/headless/HQCountdownRegression.gd"

var workers = []
var foundation
var owner
var label = ""
var contracts = false


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in ["bastion", "helix", "frontier"]:
		label = faction
		await _mirror(faction)
		await _paid_site()
		await _crew_rate()
		await _contract_reload()
		await _handoff_and_complete()
		await _refund_cases()
		paused = false
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Construction contract: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _paid_site():
	owner = game._get_human_player()
	workers = _units(owner, "Worker")
	_units(owner, "CommandCenter")[0].hp = 0
	await _frames(5)
	owner.resource_a = 80
	owner.resource_b = 20
	var handler = owner.get_node("StructurePlacementHandler")
	handler._start_structure_placement(load("res://source/match/units/CommandCenter.tscn"))
	handler._active_blueprint_node.position = Vector3(30, 0, 50)
	_check(
		handler._calculate_blueprint_position_validity() == handler.BlueprintPositionValidity.VALID,
		"Construction site invalid"
	)
	root.get_node("MatchSignals").deselect_all_units.emit()
	handler._finish_structure_placement()
	await _frames(5)
	foundation = _units(owner, "CommandCenter")[0]
	_check(owner.resource_a == 0 and owner.resource_b == 0, "Foundation did not pay exact cost")
	for index in workers.size():
		var angle = index * TAU / workers.size()
		workers[index].position = foundation.position + Vector3(cos(angle), 0, sin(angle)) * 3.2
		workers[index].issue_manual_order(
			load("res://source/match/units/actions/Constructing.gd").new(foundation)
		)
	contracts = foundation.has_method("construction_refund")


func _crew_rate():
	var start = game.simulation_time
	game.hud._toggle_pause()
	await _frames(600)
	game.hud.pause_after_load()
	var expected = (game.simulation_time - start) / 45.0
	_check(
		absf(foundation._construction_progress - expected) < .015,
		label + ": four engineers changed one-engineer build rate"
	)
	_check(not foundation.is_constructed(), "HQ finished before its build duration")
	print(
		"CONSTRUCTION RATE ",
		label,
		" progress=",
		foundation._construction_progress,
		" expected=",
		expected
	)
	await _review_contract("crew")


func _contract_reload():
	var builder = Snapshot.new()
	var data = builder.capture(game)
	var id = builder._reference(foundation)
	var ids = workers.map(func(unit): return builder._reference(unit))
	var progress = foundation._construction_progress
	var timer = game._defeat_timers[owner]
	var file = "user://construction-contract-%d.json" % OS.get_process_id()
	_check(FileStore.new().write_file(file, data), "Construction save failed")
	var restore = Restore.new()
	var loaded = await restore.restore(self, FileStore.new().read_file(file))
	DirAccess.remove_absolute(file)
	_check(loaded.ok, "Construction restore failed")
	game = loaded.game
	foundation = restore.entities[id]
	workers = ids.map(func(value): return restore.entities[value])
	owner = foundation.player
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	await _frames(20)
	_check(
		paused and game.simulation_time == data.simulation_time,
		"Paused construction load advanced time"
	)
	_check(
		foundation._construction_progress == progress and game._defeat_timers[owner] == timer,
		"Construction load changed progress/deadline"
	)
	await _review_contract("restored")


func _handoff_and_complete():
	workers[0].issue_manual_order(null)
	var before = foundation._construction_progress
	game.hud._toggle_pause()
	await _frames(120)
	game.hud.pause_after_load()
	_check(
		absf(foundation._construction_progress - before - 2.0 / 45.0) < .01,
		"Manual handoff changed construction rate"
	)
	_check(
		workers[0].action == null or not "_target_unit" in workers[0].action,
		"Construction stole stopped worker"
	)
	workers[1].hp = 0
	await _frames(5)
	before = foundation._construction_progress
	game.hud._toggle_pause()
	await _frames(120)
	game.hud.pause_after_load()
	_check(
		absf(foundation._construction_progress - before - 2.0 / 45.0) < .01,
		"Death handoff changed construction rate"
	)
	game.hud._toggle_pause()
	for frame in 3000:
		await _frames(1)
		if foundation.is_constructed() or game.finished:
			break
	_check(
		foundation.is_constructed() and not game.finished,
		"Funded HQ did not complete before defeat"
	)
	await _frames(3)
	game.hud.pause_after_load()
	_check(game._defeat_timers[owner] == 60.0, "Completed HQ did not reset countdown")
	await _review_contract("completed")


func _refund_cases():
	for progress in [0.0, .25, .5, .99]:
		var site = load("res://source/match/units/CommandCenter.tscn").instantiate()
		game._setup_and_spawn_unit(site, Transform3D(Basis(), Vector3(46, 0, 50)), owner, true)
		await _frames(5)
		if progress > 0:
			site.construct(progress)
		var funds = Vector2i(owner.resource_a, owner.resource_b)
		var expected = Vector2i(floori(80 * (1.0 - progress)), floori(20 * (1.0 - progress)))
		if contracts:
			_check(
				site.construction_refund() == {"resource_a": expected.x, "resource_b": expected.y},
				"Refund quote differs from unused cost"
			)
		foundation = site
		await _review_contract("refund-%d" % roundi(progress * 100))
		site.cancel_construction()
		_check(
			Vector2i(owner.resource_a, owner.resource_b) == funds + expected,
			label + ": wrong unused-cost refund"
		)
		if contracts:
			site.cancel_construction()
			_check(
				Vector2i(owner.resource_a, owner.resource_b) == funds + expected,
				"Repeated cancellation refunded twice"
			)
		await _frames(5)
	var destroyed = load("res://source/match/units/CommandCenter.tscn").instantiate()
	game._setup_and_spawn_unit(destroyed, Transform3D(Basis(), Vector3(46, 0, 50)), owner, true)
	await _frames(5)
	destroyed.construct(.5)
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	destroyed.hp = 0
	await _frames(5)
	_check(
		Vector2i(owner.resource_a, owner.resource_b) == funds, "Destroyed foundation refunded cost"
	)


func _review_contract(_stage):
	return
