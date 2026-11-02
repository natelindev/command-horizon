extends "res://tests/headless/FrontierAirContractsRegression.gd"

const OUTPUT = "res://art/frontier-market/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Black Market preview requires a renderer; omit --headless")
		quit(1)
		return
	var logger = RuntimeErrorLog.new()
	OS.add_logger(logger)
	Engine.max_fps = 60
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for language in ["en", "zh_CN"]:
		options.restore(
			{
				"screen": 1,
				"interface_scale": 1.5,
				"edge_scrolling": false,
				"day_cycle": false,
				"weather": 1,
				"health_bars": 1,
				"language": language
			}
		)
		await create_timer(1.0).timeout
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		await _skirmish("frontier", "res://source/match/maps/PlainAndSimple.tscn")
		human = game._get_human_player()
		human.resource_a = 1000
		human.resource_b = 500
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		game.repair_service.set_physics_process(false)
		var lab = _units(human, "CommandLab")[0]
		var camera = game.get_node("IsometricCamera3D")
		camera.set_size_safely(20.0)
		camera.set_position_safely(lab.global_position)
		root.get_node("MatchSignals").deselect_all_units.emit()
		lab.get_node("Selection").select()
		await _frames(10)
		var menus = game.find_child("UnitMenus")
		menus.open_page("Black Market")
		await _frames(10)
		var panels = menus.find_children("*", "VBoxContainer", true, false)
		var market = panels.filter(_is_market)[0]
		_check(
			market._aircraft.size() == 3 and market._buttons.size() == 2,
			"Market omits a direct contract or exchange"
		)
		var funds = Vector2i(human.resource_a, human.resource_b)
		market._aircraft.Fighter.grab_focus()
		for pressed in [true, false]:
			var event = InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			root.push_input(event, false)
			await _frames(2)
		_check(
			Vector2i(human.resource_a, human.resource_b) == funds - Vector2i(26, 14),
			"Market keyboard contract did not charge its visible price"
		)
		_check(
			market._contracts.cooldown_left > 0.0, "Market keyboard contract did not start cooldown"
		)
		market._contracts.set_physics_process(false)
		market._contracts.cooldown_left = 0.0
		market.refresh()
		await _frames(8)
		await _capture(menus, market, language + "-ready")
		market._contracts.cooldown_left = 12.0
		market.refresh()
		await _frames(8)
		await _capture(menus, market, language + "-cooldown")
		game.queue_free()
		await _frames(5)
	options.restore(original)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for error in errors:
		push_error(error)
	print("Frontier Black Market rendered review: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _is_market(node) -> bool:
	return node.get_script() != null and node.get_script().resource_path.ends_with("MarketPanel.gd")


func _capture(menus, market, label):
	var deck = menus.get_global_rect()
	_check(deck.size.y <= 246.0 + 1.0, "Market increased the baseline console height")
	for button in market._aircraft.values() + market._buttons.values():
		_check(deck.encloses(button.get_global_rect()), "Market card escapes the bottom deck")
		_check(
			button._materials.is_visible_in_tree() and button._electronics.is_visible_in_tree(),
			"Market hides a contract price"
		)
	await RenderingServer.frame_post_draw
	var capture = root.get_texture().get_image()
	_check(
		capture.get_size() == Vector2i(1280, 720), "Market review has incorrect viewport dimensions"
	)
	capture.save_png(OUTPUT + "frontier-720p-" + label + ".png")
