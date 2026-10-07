extends "res://tests/rendered/RegionalRecoveryPreview.gd"


func _continue_recovery(index):
	if "--single" in OS.get_cmdline_user_args() and index == 0:
		return
	await super(index)


func _review(label, tank):
	await super(label, tank)
	var menus = game.find_child("UnitMenus")
	var attack = menus._command_buttons.attack_move
	print(
		"GEOMETRY ",
		label,
		" root=",
		root.get_visible_rect(),
		" button=",
		attack.get_global_rect(),
		" transform=",
		attack.get_global_transform_with_canvas(),
		" local=",
		attack.get_rect(),
		" size=",
		attack.size,
		" minimum=",
		attack.get_minimum_size(),
		" content_transform=",
		menus._content.get_global_transform_with_canvas()
	)
	var point = attack.get_global_rect().get_center()
	for pressed in [true, false]:
		var click = InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
		await _frames(1)
	_check(game.hud.direct_orders.kind == "attack_move", "Visible attack-move hit area failed")
	game.hud.direct_orders.cancel()
	print("HIT AREA ", label, " ", game.hud.direct_orders.kind)
	for control in menus.find_children("*", "Control", true, false):
		control.queue_redraw()
	await _frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures + "-" + label + "-redrawn.png")
