extends "res://tests/rendered/PaidProgressionPreview.gd"


func _earned_interface():
	_check(interactive, "Research feedback preview requires --interactive native input")
	_check(
		paused and human.technology.active == "weapons_1",
		"Archive lacks paused paid weapon research"
	)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(25)
	camera.set_position_safely(lab.position)
	root.get_node("MatchSignals").deselect_all_units.emit()
	# The ordinary load notice owns the message slot first.
	await _frames(400)
	var status = game.hud.research_status
	status.refresh()
	_check(status.visible, "Earned research has no visible live status")
	_check("Weapon systems I" in status._button.text, "Live status names the wrong project")
	await _layout("earned-paused")
	var before = _authority()
	await _wait_input(
		func(): return is_instance_valid(game.hud.technology_panel), "click live research status"
	)
	_check(_authority() == before, "Reviewing live research changed paused gameplay")
	await _capture("overview")
	await _wait_input(func(): return game.hud.technology_panel == null, "close Tech with Escape")
	_check(_authority() == before, "Closing research lost paused authority")
	var remaining = human.technology.left
	var clock = game.simulation_time
	game.hud._toggle_pause()
	await create_timer(2.0).timeout
	game.hud._toggle_pause()
	await _frames(20)
	_check(human.technology.left < remaining, "Research status did not follow the normal clock")
	_check(absf(game.simulation_time - clock - 2.0) < .2, "Native clock interval changed")
	print(
		"FEEDBACK EARNED CLOCK elapsed=",
		game.simulation_time - clock,
		" left=",
		human.technology.left
	)
	await _layout("earned-progress")
	var tanks = _units(human, "Tank")
	_check(not tanks.is_empty(), "Earned archive lacks a tank for keyboard review")
	if tanks.is_empty():
		return
	tank = tanks[0]
	tank.get_node("Selection").select()
	await _frames(15)
	before = _authority()
	await _wait_input(
		func(): return game.hud.direct_orders.kind == "move", "press M to choose a move destination"
	)
	await _frames(2)
	_check(
		not status.visible and game.hud._assignment_hint.visible,
		"Research displaced direct-order instructions"
	)
	await _capture("move-instructions")
	await _wait_input(
		func(): return game.hud.direct_orders.kind == "", "cancel destination choice with Escape"
	)
	await _frames(20)
	_check(_authority() == before, "Cancelled destination choice changed army orders or research")
	_check(status.visible, "Research status did not return after cancelling input")
	await _layout("after-cancel")
	# A controlled lab-loss extension of the earned state checks the ordinary refund UI.
	for owned_lab in _units(human, "CommandLab"):
		owned_lab.queue_free()
	await _frames(20)
	status.refresh()
	_check("rebuild lab" in status._button.text, "Native lost-lab interruption is missing")
	await _layout("lab-lost")
	var funds = Vector2i(human.resource_a, human.resource_b)
	var paid = human.technology.paid.duplicate()
	before = _authority()
	await _wait_input(
		func(): return is_instance_valid(game.hud.technology_panel), "click stalled research status"
	)
	_check(_authority() == before, "Opening stalled research changed gameplay")
	await _capture("stalled-overview")
	await _wait_input(func(): return human.technology.active == "", "click Cancel & refund")
	_check(
		(
			Vector2i(human.resource_a, human.resource_b)
			== funds + Vector2i(paid.resource_a, paid.resource_b)
		),
		"Native refund differs from the paid project"
	)
	await _capture("refunded")
	await _wait_input(
		func(): return game.hud.technology_panel == null, "close refunded project with Escape"
	)
	await _frames(20)
	_check(paused and not status.visible, "Cancelled project retained stale live status")
	await _layout("back-to-battle")


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
		if not unit.is_in_group("units") or unit.is_queued_for_deletion():
			continue
		state.append([unit, unit.position, unit.hp, unit.action])
		if unit.manual_orders != null:
			state.append(unit.manual_orders.pending.duplicate(true))
	return state


func _layout(label):
	await _frames(8)
	var hud = game.hud
	var command = hud.get_child(0)
	_check(command.size.y <= 170, "Research grew the fixed message space: " + label)
	_check(
		not command.get_global_rect().intersects(game.find_child("Minimap").get_global_rect()),
		"Research command panel overlaps minimap"
	)
	_check(
		not hud.battle_plan.get_global_rect().intersects(
			game.find_child("Minimap").get_global_rect()
		),
		"Research pushed battle plan into minimap"
	)
	_check(
		not hud.battle_plan.get_global_rect().intersects(
			game.find_child("UnitMenus").get_global_rect()
		),
		"Research pushed advice into selected-unit controls"
	)
	await _capture(label)
