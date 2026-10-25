extends "res://tests/headless/MenuWidthRegression.gd"

var interactive = false


func _run():
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument == "--interactive":
			interactive = true
		if argument.begins_with("--captures="):
			capture_prefix = argument.trim_prefix("--captures=")
	await create_timer(2).timeout
	await super()


func _review_width(menus, label):
	await super(menus, label)
	if label == "earned" and interactive:
		await _native_controls(menus)
	if label not in ["earned", "remapped", "bastion-Worker", "helix-Tank", "frontier-RepairRobot"]:
		return
	await _frames(8)
	await RenderingServer.frame_post_draw
	if capture_prefix != "":
		var destination = capture_prefix + "-" + label + ".png"
		_check(not FileAccess.file_exists(destination), "Capture already exists")
		if not FileAccess.file_exists(destination):
			root.get_texture().get_image().save_png(destination)


func _native_controls(menus):
	var unit = menus._selection[0]
	var action = unit.action
	var before_time = game.simulation_time
	var funds = Vector2i(unit.player.resource_a, unit.player.resource_b)
	var direct = menus._direct_orders
	var deadline = Time.get_ticks_msec() + 180000
	print("NATIVE WIDTH: click Attack move")
	while direct.kind != "attack_move" and Time.get_ticks_msec() < deadline:
		await _frames(1)
	_check(direct.kind == "attack_move", "Native Attack move was inaccessible")
	print("NATIVE WIDTH: Escape to cancel Attack move")
	while direct.kind != "" and Time.get_ticks_msec() < deadline:
		await _frames(1)
	_check(direct.kind == "", "Native Escape did not cancel Attack move")
	_check(unit.action == action, "Cancelled input changed orders")
	_check(game.simulation_time == before_time, "Native review advanced paused time")
	_check(
		Vector2i(unit.player.resource_a, unit.player.resource_b) == funds,
		"Native review spent funds"
	)
	print("NATIVE WIDTH: mouse, keyboard and cancellation passed")
