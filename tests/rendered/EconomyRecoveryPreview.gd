extends "res://tests/rendered/SkirmishLoopPreview.gd"


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.screen = options.Screen.WINDOW
	options.apply()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	for faction in ["bastion", "helix"]:
		await _start_loop(faction, false)
		await _refund_flow(faction)
		paused = false
		_game.queue_free()
		await _frames(5)
		await _start_loop(faction, false)
		await _field_and_hq(faction)
		paused = false
		_game.queue_free()
		await _frames(5)
	options.restore(original)
	for error in _errors:
		push_error(error)
	print("Economy recovery UI: %d failures" % _errors.size())
	quit(0 if _errors.is_empty() else 1)


func _refund_flow(faction):
	var human = _game._get_human_player()
	var plan = _game.hud.battle_plan
	var catalog = load("res://source/match/BastionCatalog.gd")
	var barracks = load(catalog.scene_path("Barracks")).instantiate()
	_game._setup_and_spawn_unit(barracks, Transform3D(Basis(), Vector3(18, 0, 18)), human, false)
	for worker in _own_role("Worker"):
		worker.queue_free()
	await _frames(5)
	_game.hud._toggle_pause()
	human.resource_a = 6
	human.resource_b = 0
	barracks.production_queue.produce(load(catalog.scene_path("Infantry")))
	plan.refresh()
	await _frames(5)
	_check("Recover funds" in plan._title.text, "Worker-loss refund guide missing")
	await _click(plan._action)
	_check(
		get_nodes_in_group("selected_units") == [barracks],
		"Refund shortcut selected wrong producer"
	)
	_check(
		human.resource_a == 0 and barracks.production_queue.size() == 1, "Guide cancelled paid work"
	)
	await _capture("recovery-%s-refund-720p" % faction)
	_layout(plan)
	var queue = _game.get_node("HUD/MarginContainer3/VBoxContainer/ProductionQueue")
	var icons = queue._queue_elements.get_children().filter(
		func(child): return not child.is_queued_for_deletion()
	)
	_check(icons.size() == 1, "Paid queue icon unavailable")
	if icons.is_empty():
		return
	if faction == "helix":
		icons[0].grab_focus()
		_key(KEY_ENTER)
		await _frames(5)
	else:
		await _click(icons[0])
	_check(
		human.resource_a == 6 and barracks.production_queue.size() == 0,
		"Actual queue click did not refund"
	)
	plan.refresh()
	await _frames(5)
	await _click(plan._action)
	var hq = _own_role("CommandCenter")[0]
	_check(get_nodes_in_group("selected_units") == [hq], "Recovery guide did not select HQ")
	var menu = _game.find_child("UnitMenus")
	var choices = menu._buttons.filter(func(entry): return entry.type == "Worker")
	_check(not choices.is_empty(), "HQ engineer button unavailable")
	if choices.is_empty():
		return
	await _click(choices[0].button)
	plan.refresh()
	await _frames(5)
	_check(
		human.resource_a == 0 and hq.production_queue.size() == 1,
		"Replacement button failed to spend refunded funds"
	)
	_check("already paid" in plan._description.text, "Pending replacement advice missing")
	_layout(plan)
	await _capture("recovery-%s-replacement-720p" % faction)
	_game.hud._toggle_pause()


func _field_and_hq(faction):
	var human = _game._get_human_player()
	var workers = _own_role("Worker")
	var harvest = load("res://source/match/units/actions/CollectingResourcesSequentially.gd")
	var waiting = harvest.new(null)
	waiting.restoring = true
	waiting._kind = 1
	waiting._field_origin = workers[0].global_position_yless
	waiting._state = harvest.State.WAITING
	waiting._waiting_reason = harvest.Wait.DEPLETED
	workers[0].issue_manual_order(waiting)
	_game.hud.show_notice("Engineer · Materials field depleted · choose a new field")
	var plan = _game.hud.battle_plan
	plan.refresh()
	await _frames(5)
	await _click(plan._action)
	_check(
		get_nodes_in_group("selected_units") == [workers[0]],
		"Expansion guide selected unaffected engineers"
	)
	_check(workers[0].action == waiting, "Expansion shortcut issued a resource order")
	_layout(plan)
	await _capture("recovery-%s-expansion-720p" % faction)
	# Real manual reassignment clears the recovery step.
	var deposit = get_nodes_in_group("resource_units")[0]
	var camera = _game.get_node("IsometricCamera3D")
	camera.set_position_safely(deposit.global_position)
	await _frames(5)
	await _right_click(camera.unproject_position(deposit.global_position + Vector3.UP * 0.5))
	_check(workers[0].action != waiting, "Expansion right-click did not replace the old assignment")
	human.resource_a = 80
	human.resource_b = 20
	_own_role("CommandCenter")[0].queue_free()
	await _frames(5)
	_game.hud._toggle_pause()
	plan.refresh()
	await _frames(5)
	_check("45 s" in plan._description.text, "HQ recovery omitted timing")
	_layout(plan)
	await _capture("recovery-%s-hq-720p" % faction)
	var before = Vector2(human.resource_a, human.resource_b)
	await _click(plan._action)
	_check(get_nodes_in_group("selected_units").size() == 1, "HQ rebuild shortcut failed")
	_check(Vector2(human.resource_a, human.resource_b) == before, "HQ guide spent funds")
	_check(_game.hud._pause_owned and paused, "Guide broke tactical pause")
	_game.hud._toggle_pause()


func _own_role(role):
	return _game._get_human_player().get_children().filter(
		func(unit): return unit.is_in_group("units") and unit.type == role
	)


func _layout(plan):
	_check(plan.get_global_rect().end.y < 500, "Recovery guide overlaps minimap at 720p")
	_check(plan.get_global_rect().end.x < 765, "Recovery guide covers unit commands")
