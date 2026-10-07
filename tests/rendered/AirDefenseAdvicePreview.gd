extends "res://tests/headless/AirDefenseAdviceRegression.gd"

var preview_deadline = 0
var capture_prefix = ""
var reviews = ["bastion-construction", "helix-interception", "frontier-mobile"]


func _initialize():
	Engine.max_fps = 60
	preview_deadline = Time.get_ticks_msec() + 300000
	_run.call_deferred()


func _process(_delta):
	if Time.get_ticks_msec() > preview_deadline:
		push_error("Native air-defense review timed out")
		quit(1)
	return false


func _run():
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
		if argument.begins_with("--reviews="):
			reviews = Array(argument.trim_prefix("--reviews=").split(","))
	if capture_prefix == "":
		push_error("Supply a new --captures=<image prefix>; native selection input is required")
		quit(2)
		return
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1920, 1080)
	await super()
	options.restore(original)


func _review_air_advice(player, label):
	if label not in reviews:
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var panel = game.hud.battle_plan
	if not panel._body.visible:
		panel._toggle_body()
	panel.refresh()
	root.get_node("MatchSignals").deselect_all_units.emit()
	var step = plan_rules.next_step(player)
	var before = _gameplay_state(player)
	print("NATIVE AIR INPUT ", label, " · ", step.action)
	await _wait_input(func(): return _native_selected(step.units), label + " selection")
	_check(_gameplay_state(player) == before, "Selection changed gameplay: " + label)
	_check(
		not panel.get_global_rect().intersects(game.find_child("Minimap").get_global_rect()),
		"Air advice overlaps minimap: " + label
	)
	_check(
		not panel.get_global_rect().intersects(game.find_child("UnitMenus").get_global_rect()),
		"Air advice overlaps selection controls: " + label
	)
	await _capture(label)
	if label != "helix-interception":
		return
	var walker = step.units[0]
	var action = walker.action
	var orders = walker.manual_orders.pending.duplicate(true)
	var funds = Vector2i(player.resource_a, player.resource_b)
	var clock = game.simulation_time
	var modes = game.find_child("UnitMenus")._weapon_modes
	_check(
		is_instance_valid(modes) and not modes._interception.disabled,
		"Advice did not expose Interception"
	)
	print("NATIVE AIR INPUT choose Interception")
	await _wait_input(
		func(): return walker.pending_weapon_mode == "interception", "explicit Interception"
	)
	_check(
		walker.weapon_mode == "precision" and walker.weapon_switch_left == 2.0,
		"Paused stance did not retain its full switch"
	)
	_check(
		walker.action == action and walker.manual_orders.pending == orders,
		"Stance changed army orders"
	)
	_check(
		Vector2i(player.resource_a, player.resource_b) == funds and game.simulation_time == clock,
		"Stance changed paused time or funds"
	)
	await _capture(label + "-switching")


func _gameplay_state(player):
	var state = [paused, game.simulation_time, player.resource_a, player.resource_b]
	for unit in plan_rules.owned_units(player):
		state.append([unit, unit.position, unit.action])
		if unit.manual_orders != null:
			state.append(unit.manual_orders.pending.duplicate(true))
		if "weapon_mode" in unit:
			state.append([unit.weapon_mode, unit.pending_weapon_mode, unit.weapon_switch_left])
	return state


func _native_selected(units):
	var selected = get_nodes_in_group("selected_units")
	return (
		not units.is_empty()
		and selected.size() == units.size()
		and units.all(func(unit): return unit in selected)
	)


func _wait_input(condition, label):
	var limit = Time.get_ticks_msec() + 60000
	while not condition.call() and Time.get_ticks_msec() < limit:
		await _frames(1)
	_check(condition.call(), "Native input did not finish: " + label)


func _capture(label):
	await _frames(8)
	await RenderingServer.frame_post_draw
	var frame = root.get_texture().get_image()
	_check(frame.get_size() == Vector2i(1280, 720), "Air advice capture resolution changed")
	var destination = capture_prefix + "-" + label + ".png"
	_check(not FileAccess.file_exists(destination), "Air advice capture already exists")
	if not FileAccess.file_exists(destination):
		_check(frame.save_png(destination) == OK, "Cannot retain native air advice capture")
	print("NATIVE AIR CAPTURE ", label)
