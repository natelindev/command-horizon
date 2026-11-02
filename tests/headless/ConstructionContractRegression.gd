extends "res://tests/headless/HQCountdownRegression.gd"

var factions = ["bastion", "helix", "frontier"]
var faction_catalog
var construction_action
var hq_scene
var workers = []
var foundation
var owner
var label = ""
var contracts = false


func _run():
	faction_catalog = load("res://source/match/FactionCatalog.gd")
	construction_action = load("res://source/match/units/actions/Constructing.gd")
	hq_scene = load("res://source/match/units/CommandCenter.tscn")
	root.get_node("SaveManager").autosaves_enabled = false
	for faction in factions:
		label = faction
		await _mirror(faction)
		await _paid_site()
		await _crew_rate()
		await _contract_reload()
		await _handoff_and_complete()
		await _refund_cases()
		await _legacy_contract()
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
	handler._start_structure_placement(hq_scene)
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
		workers[index].issue_manual_order(construction_action.new(foundation))
	contracts = foundation.has_method("construction_refund")


func _crew_rate():
	var start = game.simulation_time
	game.hud._toggle_pause()
	await _frames(600)
	game.hud.pause_after_load()
	var expected = (game.simulation_time - start) / faction_catalog.BUILD_TIMES.CommandCenter
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
		(
			absf(
				(
					foundation._construction_progress
					- before
					- 2.0 / faction_catalog.BUILD_TIMES.CommandCenter
				)
			)
			< .01
		),
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
		(
			absf(
				(
					foundation._construction_progress
					- before
					- 2.0 / faction_catalog.BUILD_TIMES.CommandCenter
				)
			)
			< .01
		),
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
	if contracts:
		var funds = Vector2i(owner.resource_a, owner.resource_b)
		_check(not foundation.cancel_construction(), "Completed HQ accepted cancellation")
		_check(
			(
				Vector2i(owner.resource_a, owner.resource_b) == funds
				and not foundation.is_queued_for_deletion()
			),
			"Completed cancellation changed resources or building"
		)


func _refund_cases():
	for progress in [0.0, .25, .5, .99]:
		var site = await _buy_refund_site()
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
		await _cancel_site(site)
		_check(
			Vector2i(owner.resource_a, owner.resource_b) == funds + expected,
			label + ": wrong unused-cost refund"
		)
		if contracts and is_instance_valid(site):
			site.cancel_construction()
			_check(
				Vector2i(owner.resource_a, owner.resource_b) == funds + expected,
				"Repeated cancellation refunded twice"
			)
		await _frames(5)
	var destroyed = hq_scene.instantiate()
	game._setup_and_spawn_unit(destroyed, Transform3D(Basis(), Vector3(46, 0, 50)), owner, true)
	await _frames(5)
	destroyed.construct(.5)
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	destroyed.hp = 0
	await _frames(5)
	_check(
		Vector2i(owner.resource_a, owner.resource_b) == funds, "Destroyed foundation refunded cost"
	)


func _buy_refund_site():
	owner.resource_a = 80
	owner.resource_b = 20
	var handler = owner.get_node("StructurePlacementHandler")
	handler._start_structure_placement(hq_scene)
	var valid = false
	for radius in [8.0, 12.0, 16.0, 20.0]:
		for index in 16:
			var angle = index * TAU / 16
			handler._active_blueprint_node.position = (
				Vector3(30, 0, 50) + Vector3(cos(angle), 0, sin(angle)) * radius
			)
			if (
				handler._calculate_blueprint_position_validity()
				== handler.BlueprintPositionValidity.VALID
			):
				valid = true
				break
		if valid:
			break
	_check(valid, "No legal paid cancellation site")
	root.get_node("MatchSignals").deselect_all_units.emit()
	handler._finish_structure_placement()
	await _frames(5)
	_check(owner.resource_a == 0 and owner.resource_b == 0, "Cancellation fixture did not pay once")
	return _units(owner, "CommandCenter").filter(func(unit): return not unit.is_constructed())[0]


func _cancel_site(site):
	site.cancel_construction()


func _review_contract(_stage):
	root.get_node("MatchSignals").deselect_all_units.emit()
	foundation.get_node("Selection").select()
	await _frames(4)
	var menus = game.find_child("UnitMenus")
	menus._refresh_buttons()
	if contracts and foundation.is_under_construction():
		var visual = foundation.get_node_or_null("ConstructionVisual")
		_check(visual != null, label + ": foundation lost construction animation after " + _stage)
		if visual != null:
			for material in visual._materials:
				_check(
					is_equal_approx(
						material.get_shader_parameter("progress"), foundation._construction_progress
					),
					label + ": visual assembly disagrees with saved construction progress"
				)
		var refund = foundation.construction_refund()
		var quote = (
			str(TranslationServer.translate("%d M / %d E")) % [refund.resource_a, refund.resource_b]
		)
		_check(
			quote in menus._stop_button.tooltip_text, "Cancellation tooltip hides the live refund"
		)
		_check(
			(
				str(
					TranslationServer.translate(
						"Refunds unused construction costs, rounded down to whole resources."
					)
				)
				in menus._stop_button.accessibility_description
			),
			"Cancellation refund lacks accessible explanation"
		)


func _legacy_contract():
	owner.set_meta("skirmish", false)
	var site = hq_scene.instantiate()
	game._setup_and_spawn_unit(site, Transform3D(Basis(), Vector3(46, 0, 50)), owner, true)
	await _frames(5)
	var crew = _units(owner, "Worker")
	for index in crew.size():
		crew[index].position = site.position + Vector3(0, 0, 3.2)
		crew[index].issue_manual_order(construction_action.new(site))
	game.hud._toggle_pause()
	await _frames(60)
	game.hud.pause_after_load()
	var speed = root.get_node("Constants").Match.Units.STRUCTURE_CONSTRUCTING_SPEED
	var builders = 1 if owner.faction == "helix" else crew.size()
	_check(
		absf(site._construction_progress - speed * builders) < .01,
		"Legacy construction changed faction worker rate"
	)
	var cost = faction_catalog.cost(owner, "CommandCenter", true)
	var funds = Vector2i(owner.resource_a, owner.resource_b)
	site.cancel_construction()
	_check(
		(
			Vector2i(owner.resource_a, owner.resource_b)
			== funds + Vector2i(cost.resource_a, cost.resource_b)
		),
		"Legacy construction lost full refund"
	)
	await _frames(5)
	owner.set_meta("skirmish", true)
