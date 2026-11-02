extends "res://tests/headless/SaveRestoreEdges.gd"

var human
var factions
var status


class FeedbackErrorLog:
	extends Logger
	var messages = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, _type, _backtraces):
		mutex.lock()
		messages.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _run():
	var logger = FeedbackErrorLog.new()
	OS.add_logger(logger)
	root.get_node("SaveManager").autosaves_enabled = false
	factions = load("res://source/match/FactionCatalog.gd")
	for faction in factions.IDS:
		await _feedback_fixture(faction)
		await _availability()
		await _coordination()
		await _notice_priority()
		await _power_and_lab_loss()
		await _lost_lab_archive()
		await _cancel_and_rebuild()
		await _completions()
		print("RESEARCH FEEDBACK VERIFIED ", faction)
		paused = false
		game.queue_free()
		await _frames(5)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("Research feedback: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _feedback_fixture(faction):
	await _skirmish(faction, "res://source/match/maps/DesertFrontier.tscn", true)
	human = game._get_human_player()
	_freeze_actors()
	game.hud._toggle_pause()
	root.get_node("MatchSignals").deselect_all_units.emit()
	_check(paused, "Research feedback fixture did not pause")
	status = game.hud.research_status


func _freeze_actors():
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED


func _availability():
	status.refresh()
	_check(status.visible, "Funded advanced base has no research choices")
	_check("1 choice" in status._button.text, "Faction research choices bypass Coordination")
	_check(not status._progress.visible, "Idle choices show a running progress bar")
	_check("Coordination · 20 M / 20 E" in status._button.tooltip_text, "Choice price is missing")
	var funds = Vector2i(human.resource_a, human.resource_b)
	human.resource_a = 0
	human.resource_b = 0
	status.refresh()
	_check(not status.visible, "Unaffordable research is advertised as available")
	human.resource_a = 20
	human.resource_b = 20
	status.refresh()
	_check("1 choice" in status._button.text, "Single affordable research choice is incorrect")
	human.resource_a = funds.x
	human.resource_b = funds.y
	status.refresh()
	await _unchanged("research choices")


func _coordination():
	var lab = _units(human, "CommandLab")[0]
	var funds = Vector2i(human.resource_a, human.resource_b)
	game.hud.open_technology()
	_check(human.start_coordination(lab), "Ordinary Coordination purchase failed")
	game.hud._close_menu()
	await _frames(20)
	_check(
		"Coordination" in _visible_text(game.hud),
		human.faction + ": paid Coordination has no visible feedback after closing Tech"
	)
	_check("30 s" in status._button.text and "paused" in status._button.text, "Paused ETA missing")
	_check(
		status._progress.visible and status._progress.value == 0, "New research progress differs"
	)
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds - Vector2i(20, 20),
		"Feedback changed the Coordination price"
	)
	await _unchanged("paid Coordination")
	var elapsed = await _advance(Engine.physics_ticks_per_second * 2)
	_check(absf(elapsed - 2.0) < .05, "Clock interval differs from two seconds")
	_check(
		is_equal_approx(30.0 - human.coordination_left, elapsed), "Normal research speed differs"
	)
	status.refresh()
	_check(status._progress.value > 6 and status._progress.value < 7, "Real progress is not shown")


func _notice_priority():
	var hud = game.hud
	var tank = _units(human, "Tank")[0]
	var action = tank.action
	var remaining = human.coordination_left
	hud.arm_signature_sector([tank])
	var instruction = hud._assignment_hint.text
	hud.show_notice("Research feedback priority check")
	await _frames(5)
	_check(not status.visible, "Research status displaced a map assignment")
	_check(hud._assignment_hint.text == instruction, "Notice overwrote assignment instructions")
	_check(hud._pending_notice == "Research feedback priority check", "Notice was not retained")
	hud.cancel_map_assignment()
	await _frames(5)
	_check(
		hud._assignment_hint.text == "Research feedback priority check" and not status.visible,
		"Queued notice did not precede research feedback"
	)
	await _frames(370)
	_check(
		not hud._assignment_hint.visible and status.visible, "Research did not return after notice"
	)
	_check(
		tank.action == action and human.coordination_left == remaining, "Messages changed gameplay"
	)
	await _unchanged("notice expiry")


func _power_and_lab_loss():
	# HQ supplies 20 power as well; suspend both sources in this controlled fixture.
	var plants = _units(human, "PowerPlant") + _units(human, "CommandCenter")
	for plant in plants:
		plant.mark_as_under_construction()
	_check(human.production_factor() == .25, "Low-power fixture still has full supply")
	status.refresh()
	_check(
		str(ceili(human.coordination_left / .25)) + " s" in status._button.text,
		"Paused low-power ETA is not scaled to current speed"
	)
	_check("25%" in status._button.tooltip_text, "Low-power explanation is missing")
	var remaining = human.coordination_left
	var elapsed = await _advance(Engine.physics_ticks_per_second * 2)
	_check(
		is_equal_approx(remaining - human.coordination_left, elapsed * .25),
		"Research low-power timing was changed"
	)
	for plant in plants:
		plant.construct(1.0)
	for lab in _units(human, "CommandLab"):
		lab.queue_free()
	await _frames(5)
	status.refresh()
	_check("rebuild lab" in status._button.text, "Lost-lab research stall is invisible")
	_check("already paid" in status._button.tooltip_text, "Paid stalled project looks unpaid")
	remaining = human.coordination_left
	await _advance(120)
	_check(human.coordination_left == remaining, "Research progressed without a completed lab")
	await _unchanged("lost lab")


func _lost_lab_archive():
	var clock = game.simulation_time
	var remaining = human.coordination_left
	var funds = Vector2i(human.resource_a, human.resource_b)
	var builder = Snapshot.new()
	var snapshot = builder.capture(game)
	_check(snapshot != null, "Feedback archive capture failed: " + builder.error)
	if snapshot == null:
		return
	var file = FileStore.new()
	var archive = "user://research-feedback-%d.json" % OS.get_process_id()
	_check(file.write_file(archive, snapshot), "Feedback archive write failed")
	var loaded = await Restore.new().restore(self, file.read_file(archive))
	DirAccess.remove_absolute(archive)
	_check(loaded.ok, "Feedback archive restore failed")
	if not loaded.ok:
		return
	game = loaded.game
	human = game._get_human_player()
	status = game.hud.research_status
	_freeze_actors()
	await _frames(20)
	_check(paused and game.simulation_time == clock, "Research feedback load advanced time")
	_check(human.coordination_left == remaining, "Loaded remaining research changed")
	_check(Vector2i(human.resource_a, human.resource_b) == funds, "Feedback load charged research")
	_check(
		not "Research complete" in game.hud._assignment_hint.text,
		"Restored pending research announced completion"
	)
	await _frames(370)
	_check(status.visible and "rebuild lab" in status._button.text, "Loaded stall has no feedback")


func _cancel_and_rebuild():
	var funds = Vector2i(human.resource_a, human.resource_b)
	status._button.pressed.emit()
	await _frames(3)
	_check(is_instance_valid(game.hud.technology_panel), "Research status did not open Tech")
	_check(game.hud._overlay == null, "Research review opened a floating overlay")
	_check(
		game.find_child("UnitMenus").is_ancestor_of(game.hud.technology_panel),
		"Research status opened outside the bottom console"
	)
	game.hud.technology_panel._cancel.pressed.emit()
	_check(human.coordination_left == -1.0, "Status review could not cancel stalled Coordination")
	_check(
		Vector2i(human.resource_a, human.resource_b) == funds + Vector2i(20, 20),
		"Stalled research refund differs"
	)
	game.hud._close_menu()
	await _frames(20)
	_check(paused and not status.visible, "Cancelled lost-lab research left stale feedback")
	var lab = load("res://source/match/units/CommandLab.tscn").instantiate()
	game._setup_and_spawn_unit(lab, Transform3D(Basis(), Vector3(31, 0, 38)), human, false)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab.mark_as_under_construction()
	await _frames(3)
	status.refresh()
	_check(not status.visible, "Unfinished lab advertises available research")
	lab.construct(1.0)
	await _frames(20)
	_check(
		status.visible and "1 choice" in status._button.text,
		"Completed lab did not restore choices"
	)


func _completions():
	var lab = _units(human, "CommandLab")[0]
	_check(human.start_coordination(lab), "Restored lab refused paid Coordination")
	await _complete_within(func(): return human.coordination_unlocked, 30.0)
	_check(human.coordination_unlocked, "Coordination did not complete on the normal clock")
	_check(
		(
			game.hud._assignment_hint.visible
			and "Research complete · Coordination" == game.hud._assignment_hint.text
		),
		"Coordination completion was not announced"
	)
	_check(not status.visible, "Active status obscures the completion notice")
	await _frames(370)
	_check(
		status.visible and not status._progress.visible, "Completed research still shows a timer"
	)
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var enemy_lab = _units(enemy, "CommandLab")[0]
	_check(enemy.start_coordination(enemy_lab), "Enemy research fixture refused payment")
	var catalog = load("res://source/match/research/TechnologyCatalog.gd")
	var branch = catalog.FACTION_TECHNOLOGIES[human.faction][0]
	var title = catalog.title(branch, human.faction)
	var item = catalog.ITEMS[branch]
	human.resource_a = 1000
	human.resource_b = 1000
	_check(human.technology.start(branch, lab), "Ordinary faction research refused payment")
	await _frames(20)
	_check(title in status._button.text, "Faction research is missing from live HUD")
	await _unchanged("paid faction research")
	await _complete_within(func(): return enemy.coordination_unlocked, 30.0)
	_check(enemy.coordination_unlocked, "Enemy research did not complete")
	_check(not game.hud._assignment_hint.visible, "Enemy research leaked a completion notice")
	_check(
		status.visible and absf(status._progress.value - 100.0 * 30.0 / item.seconds) < 1.0,
		"Faction research progress was lost"
	)
	var remaining = human.technology.left
	await _complete_within(func(): return human.technology.active == "", remaining)
	_check(branch in human.technology.completed, "Faction research did not complete")
	_check(
		game.hud._assignment_hint.text == "Research complete · " + title,
		"Existing unit-research completion notice regressed"
	)
	await _frames(370)
	var remaining_branches = catalog.FACTION_TECHNOLOGIES[human.faction].filter(
		func(id): return id not in human.technology.completed
	)
	_check(
		"%d choices" % remaining_branches.size() in status._button.text,
		"Completed or excluded branches counted as choices"
	)
	for id in remaining_branches:
		_check(
			catalog.title(id, human.faction) in status._button.tooltip_text,
			"Remaining faction upgrade is missing: " + id
		)
	human.resource_a = 0
	human.resource_b = 0
	status.refresh()
	_check(not status.visible, "Unaffordable faction branches remain advertised")
	print("RESEARCH FEEDBACK CLOCK ", human.faction, " ", game.simulation_time)


func _advance(frames):
	_check(paused, "Research clock fixture must start paused")
	var clock = game.simulation_time
	game.hud._toggle_pause()
	for frame in frames:
		await physics_frame
	await process_frame
	game.hud._toggle_pause()
	await _frames(3)
	return game.simulation_time - clock


func _complete_within(condition, duration):
	var clock = game.simulation_time
	game.hud._toggle_pause()
	for frame in ceili((duration + 1) * 60):
		await physics_frame
		if condition.call():
			break
	game.hud._toggle_pause()
	await _frames(3)
	_check(condition.call(), "Research exceeded its real-time completion bound")
	_check(
		absf(game.simulation_time - clock - duration) < .05, "Full-power research duration changed"
	)


func _authority():
	var state = [
		paused,
		game.simulation_time,
		human.resource_a,
		human.resource_b,
		human.coordination_left,
		human.coordination_unlocked,
		human.technology.capture(),
		get_nodes_in_group("selected_units")
	]
	for unit in human.get_children():
		if not unit.is_in_group("units"):
			continue
		state.append([unit, unit.position, unit.hp, unit.action])
		if unit.manual_orders != null:
			state.append(unit.manual_orders.pending.duplicate(true))
	return state


func _unchanged(label):
	var before = _authority()
	for sample in 5:
		status.refresh()
	await _frames(30)
	_check(_authority() == before, "Research feedback changed paused gameplay: " + label)


func _visible_text(node):
	var result = ""
	if (node is Label or node is Button) and node.is_visible_in_tree():
		result += node.text + "\n"
	for child in node.get_children():
		result += _visible_text(child)
	return result
